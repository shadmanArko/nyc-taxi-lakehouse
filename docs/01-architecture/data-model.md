# Data Model and Contracts

## Source

NYC TLC Green Taxi trip records (Parquet, monthly). URL pattern:
`https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_{YYYY-MM}.parquet`

## Bronze: `bronze.green_trips_raw`

Raw columns from source, unchanged, plus:

| Column | Type | Description |
|---|---|---|
| `_source_file` | string | Landing object key |
| `_ingested_at` | timestamp | Load time (UTC) |
| `_batch_id` | string | Airflow run id |

Grain: one row per source row. Append only.

## Silver: `silver.green_trips`

Grain: one row per valid trip.

| Column | Type | Rule |
|---|---|---|
| `trip_id` | string | Surrogate key: hash of vendor, pickup, dropoff, locations, amount |
| `vendor_id` | int | Not null |
| `pickup_ts` | timestamp | Not null, valid |
| `dropoff_ts` | timestamp | Not null, `>= pickup_ts` |
| `pu_location_id`, `do_location_id` | int | Not null |
| `passenger_count` | int | Nullable, `>= 0` |
| `trip_distance` | double | `>= 0` |
| `total_amount` | decimal(10,2) | `>= 0` |
| `service_date` | date | `date(pickup_ts)` |

Uniqueness: `trip_id` unique (duplicates removed, count reported).

### Quarantine: `silver.green_trips_rejected`

Original row plus `reject_reason` (e.g. `NULL_PICKUP`, `DROPOFF_BEFORE_PICKUP`, `NEGATIVE_AMOUNT`, `OUT_OF_RANGE_DATE`, `DUPLICATE`).

## Gold: `gold.daily_revenue`

Grain: one row per `service_date`.

| Column | Type | Definition |
|---|---|---|
| `service_date` | date | Primary key |
| `trip_count` | bigint | Count of valid trips |
| `total_revenue` | decimal(14,2) | Sum of `total_amount` |
| `avg_fare` | decimal(10,2) | `total_revenue / trip_count` |

## Reconciliation invariant

For every batch:
`bronze_row_count = silver_row_count + quarantine_row_count`
and
`gold.total_revenue = sum(silver.total_amount)` per date.

Both are implemented as dbt tests that block publication when violated.

## Contract changes

Gold column names and meanings are a contract. Changes require an ADR or a changelog entry and a version note in the dbt model YAML.
