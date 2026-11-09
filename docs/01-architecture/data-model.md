# Data Model and Contracts

This describes what is built and running (verified 2026-11-09). The first version of this document, written before the build, planned different Gold columns and a `decimal` type for money; those changes and their reasons are in the [product brief](../00-product/01-product-brief.md) section 7.

## Where the tables live

| Layer | Table | DuckDB (local) | Databricks (`workspace` catalog) |
|---|---|---|---|
| Bronze | `green_trips_raw` | `bronze.green_trips_raw` | `bronze.green_trips_raw` |
| Staging | `stg_green_trips_classified` | `main_staging.…` | `dbt_staging.…` |
| Silver | `silver_green_trips` | `main_silver.…` | `dbt_silver.…` |
| Quarantine | `silver_green_trips_rejected` | `main_silver.…` | `dbt_silver.…` |
| Gold | `gold_daily_revenue` | `main_gold.…` | `dbt_gold.…` |

The `main_` prefix is how the dbt DuckDB adapter combines the default schema with the model's schema; the `dbt_` prefix comes from the `schema: dbt` setting of the Databricks target.

## Source

NYC TLC Green Taxi trip records (Parquet, monthly). URL pattern:
`https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_{YYYY-MM}.parquet`

Loaded so far: January to March 2025 (48,326 + 46,621 + 51,539 = 146,486 rows).

## Bronze: `green_trips_raw`

Raw columns from the source, unchanged: `VendorID`, `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `store_and_fwd_flag`, `RatecodeID`, `PULocationID`, `DOLocationID`, `passenger_count`, `trip_distance`, `fare_amount`, `extra`, `mta_tax`, `tip_amount`, `tolls_amount`, `ehail_fee`, `improvement_surcharge`, `total_amount`, `payment_type`, `trip_type`, `congestion_surcharge`, `cbd_congestion_fee`. Types are whatever the Parquet files carry (times are `timestamp_ntz`, money is floating point).

Added by the loader:

| Column | Description |
|---|---|
| `_source_file` | File the row came from |
| `_ingested_at` | Load time |
| `_batch_id` | One id per load run (DuckDB only) |

On Databricks the table also has `year` and `month` (read from the `year=/month=` folders) and has no `_batch_id`.

Grain: one row per source row. Each file is loaded once: DuckDB deletes a file's old rows before inserting it, and Databricks' `COPY INTO` skips files it already loaded.

`ehail_fee` is empty in every row and is ignored downstream.

## Staging: `stg_green_trips_classified`

Grain: one row per Bronze row (nothing is removed here). Adds three columns to every Bronze column:

| Column | Description |
|---|---|
| `trip_id` | `md5` of vendor, pickup, dropoff, pickup location, dropoff location, distance and total amount (empty values count as empty text) |
| `copy_number` | 1 for the first row with a given `trip_id`, 2 for the next, and so on (ordered by load time, then file) |
| `reject_reason` | `NULL` if the row is valid, otherwise the first rule it breaks |

Reject reasons, in the order they are checked:

1. `NULL_PICKUP`
2. `NULL_DROPOFF`
3. `DROPOFF_BEFORE_PICKUP`
4. `NULL_AMOUNT`
5. `DUPLICATE` (`copy_number` above 1)

A row that breaks several rules is reported with the first. Negative amounts and trips outside their file's month are **not** rejected.

## Silver: `silver_green_trips`

Grain: one row per valid trip (`reject_reason is null`).

| Column | Rule or meaning |
|---|---|
| `trip_id` | Unique, not null |
| `vendor_id` | |
| `pickup_ts` | Not null |
| `dropoff_ts` | Never before `pickup_ts` (tested) |
| `service_date` | `cast(pickup_ts as date)` |
| `pu_location_id`, `do_location_id` | |
| `passenger_count`, `trip_distance`, `fare_amount`, `tip_amount` | As in the source |
| `total_amount` | Not null; may be negative |
| `revenue_amount` | `total_amount - tip_amount` |
| `is_adjustment` | `total_amount < 0` |
| `fields_missing` | `RatecodeID is null` (in the data this coincides with the other descriptive fields being empty) |
| `payment_type`, `_source_file` | |

Flags mark rows; they never remove them.

## Quarantine: `silver_green_trips_rejected`

Grain: one row per rejected Bronze row (`reject_reason is not null`). Columns: `trip_id`, `reject_reason`, `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `total_amount`, `_source_file`. It holds a reduced set of columns, not the whole original row; the full row stays in Bronze.

In the data loaded so far all 518 rejected rows are `DROPOFF_BEFORE_PICKUP` (210 in February, 308 in March). No duplicates were found.

## Gold: `gold_daily_revenue`

Grain: one row per `service_date`.

| Column | Definition |
|---|---|
| `service_date` | Primary key (unique, not null) |
| `trip_count` | Count of valid trips |
| `gross_revenue` | Sum of `revenue_amount` where not an adjustment |
| `adjustments` | Sum of `revenue_amount` where an adjustment (0 when there are none) |
| `net_revenue` | Sum of `revenue_amount` (not null) |

All amounts are rounded to two decimals. Trips outside the loaded months make a few partial edge days (for example 2024-12-25 has one trip). A "complete day" flag is not built yet.

## Reconciliation invariants

For the whole load:

- `bronze_row_count = silver_row_count + quarantine_row_count`
- `sum(gold.net_revenue) = sum(silver.revenue_amount)`

Both are dbt tests, and a failing test stops the models that depend on it. Current values: 146,486 = 145,968 + 518, with the same counts on DuckDB and Databricks.

## Tests (12)

| Kind | Tests |
|---|---|
| Keys and nulls | `silver_green_trips`: `trip_id` unique and not null, `pickup_ts` not null, `total_amount` not null. `gold_daily_revenue`: `service_date` unique and not null, `net_revenue` not null. |
| Allowed values | `silver_green_trips_rejected.reject_reason`: not null and one of the five reasons |
| Custom (`dbt/tests/`) | Bronze equals Silver plus rejected; Gold total equals Silver total; Silver never has a dropoff before its pickup |

## Contract changes

Gold column names and meanings are a contract. Changes need an ADR or a dated note here and in the dbt model.
