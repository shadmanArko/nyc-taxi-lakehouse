# Code tour

A guided walk through the code that matters, in the order data flows. Each stop shows the real lines, says what they do in plain words, and gives the point worth making in a design review.

How the pieces connect is drawn in the [README](../README.md#chapter-5-design-architecture-and-trade-offs). Reading order: **ingest, model, test, orchestrate, build, ship.**

---

## 1. Ingest

### Download that is safe to rerun
[`download.py` lines 27-38](../src/nyc_taxi_lakehouse/download.py)

<!-- src: src/nyc_taxi_lakehouse/download.py:27-38 -->
```python
    if final_path.exists():
        print(f"{month}: already downloaded, skipping")
        return final_path

    response = requests.get(build_url(month), timeout=60)
    response.raise_for_status()  # stop with an error if the download failed

    # Write to a temporary name first, then rename. A crash mid-download
    # then never leaves a half-written file with the final name.
    temp_path = final_path.with_suffix(".tmp")
    temp_path.write_bytes(response.content)
    temp_path.rename(final_path)
```

- If the file is already there, do nothing. A second run costs nothing.
- `raise_for_status()` turns a failed download into an error instead of saving a broken file.
- Write to `.tmp`, then rename. A file with the final name is always complete.

*Why it matters: idempotency (FR-2). Running it twice, or after a crash, gives the same result.*

### Bronze load that is safe to rerun
[`load_bronze.py` lines 26-32](../src/nyc_taxi_lakehouse/load_bronze.py)

<!-- src: src/nyc_taxi_lakehouse/load_bronze.py:26-32 -->
```python
    # Create the table (empty) the first time, copying the structure of the query.
    con.execute(f"CREATE TABLE IF NOT EXISTS {TABLE} AS {select_sql} LIMIT 0")

    # Idempotent: remove anything previously loaded from this same file...
    con.execute(f"DELETE FROM {TABLE} WHERE _source_file = ?", [file_name])
    # ...then insert it again.
    con.execute(f"INSERT INTO {TABLE} BY NAME {select_sql}")
```

- The table is created empty the first time, with the structure of the query.
- Before inserting a file, its old rows are deleted. Loading the same file twice never doubles the rows.
- `_source_file`, `_ingested_at` and `_batch_id` (added in the query above these lines) make every row traceable.

*Why it matters: Bronze keeps raw rows plus a trail back to the file they came from.*

### The same job on Databricks
[`load_bronze.sql` lines 8-26](../databricks/load_bronze.sql)

<!-- src: databricks/load_bronze.sql:8-26 -->
```sql
-- 2. An empty table with no columns yet. COPY INTO needs the table to exist first.
--    The TLC files store times as "timestamp without time zone" (timestamp_ntz).
--    Delta only accepts that type after this table feature is switched on.
CREATE TABLE IF NOT EXISTS workspace.bronze.green_trips_raw
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported');

-- 3. Load. COPY INTO remembers which files it has loaded and skips them next time,
--    so running this again does not create duplicates (idempotent).
--    mergeSchema lets it create the columns from the files on the first run.
COPY INTO workspace.bronze.green_trips_raw
FROM (
    SELECT
        *,
        _metadata.file_name  AS _source_file,
        current_timestamp()  AS _ingested_at
    FROM 's3://arko-nyc-taxi-lakehouse-landing/landing/green_taxi/'
)
FILEFORMAT = PARQUET
COPY_OPTIONS ('mergeSchema' = 'true');
```

- `COPY INTO` is Databricks' own loader. It keeps track of the files it has loaded, so I do not have to.
- The table property is a one-time switch that Delta needs for the timestamp type in these files.

*Why it matters: the same idea (idempotent, traceable Bronze), implemented with the platform's native tool instead of hand-written code.*

---

## 2. Model (dbt)

### Give every row an ID and a verdict
[`stg_green_trips_classified.sql` lines 5-14](../dbt/models/staging/stg_green_trips_classified.sql) and [lines 29-39](../dbt/models/staging/stg_green_trips_classified.sql)

<!-- src: dbt/models/staging/stg_green_trips_classified.sql:5-14 -->
```sql
    select
        md5(concat_ws('|',
            coalesce(cast(VendorID as string), ''),
            coalesce(cast(lpep_pickup_datetime as string), ''),
            coalesce(cast(lpep_dropoff_datetime as string), ''),
            coalesce(cast(PULocationID as string), ''),
            coalesce(cast(DOLocationID as string), ''),
            coalesce(cast(trip_distance as string), ''),
            coalesce(cast(total_amount as string), '')
        )) as trip_id,
```

The source has no ID, so `trip_id` is a fingerprint of the columns that identify a trip. The same trip always gets the same ID, and `coalesce` stops one empty column from making the whole hash empty.

<!-- src: dbt/models/staging/stg_green_trips_classified.sql:29-39 -->
```sql
select
    *,
    case
        when lpep_pickup_datetime is null                    then 'NULL_PICKUP'
        when lpep_dropoff_datetime is null                   then 'NULL_DROPOFF'
        when lpep_dropoff_datetime < lpep_pickup_datetime    then 'DROPOFF_BEFORE_PICKUP'
        when total_amount is null                            then 'NULL_AMOUNT'
        when copy_number > 1                                 then 'DUPLICATE'
        else null
    end as reject_reason
from numbered
```

All the business rules live **here and only here**. A `NULL` reason means the row is valid. `CASE` returns the first rule that matches, so a row that breaks two rules is reported with the first one.

*Why it matters: one place for the rules means Silver and the quarantine table can never disagree.*

### Silver: the valid rows, with the definitions
[`silver_green_trips.sql` lines 16-22](../dbt/models/silver/silver_green_trips.sql)

<!-- src: dbt/models/silver/silver_green_trips.sql:16-22 -->
```sql
    total_amount - tip_amount                  as revenue_amount,
    total_amount < 0                           as is_adjustment,
    RatecodeID is null                         as fields_missing,
    payment_type,
    _source_file
from {{ ref('stg_green_trips_classified') }}
where reject_reason is null
```

- `revenue_amount` is the agreed revenue definition: total minus tip.
- `is_adjustment` and `fields_missing` are **flags**, not deletions. Those rows are kept and marked.
- `{{ ref(...) }}` tells dbt that staging must be built first.

### The quarantine: the same rows, the opposite filter
[`silver_green_trips_rejected.sql` lines 3-11](../dbt/models/silver/silver_green_trips_rejected.sql)

<!-- src: dbt/models/silver/silver_green_trips_rejected.sql:3-11 -->
```sql
select
    trip_id,
    reject_reason,
    lpep_pickup_datetime,
    lpep_dropoff_datetime,
    total_amount,
    _source_file
from {{ ref('stg_green_trips_classified') }}
where reject_reason is not null
```

*Why it matters: same source, opposite condition. Every row lands in exactly one of the two tables, so nothing is silently deleted.*

### Gold: one row per day
[`gold_daily_revenue.sql` lines 3-11](../dbt/models/gold/gold_daily_revenue.sql)

<!-- src: dbt/models/gold/gold_daily_revenue.sql:3-11 -->
```sql
select
    service_date,
    count(*)                                                        as trip_count,
    round(sum(revenue_amount) filter (where not is_adjustment), 2)  as gross_revenue,
    round(coalesce(sum(revenue_amount) filter (where is_adjustment), 0), 2) as adjustments,
    round(sum(revenue_amount), 2)                                   as net_revenue
from {{ ref('silver_green_trips') }}
group by service_date
order by service_date
```

Gross, adjustments and net are reported separately, so negative amounts are visible instead of hidden inside one number.

---

## 3. Prove it (tests)

### No row may vanish
[`assert_bronze_equals_silver_plus_rejected.sql`](../dbt/tests/assert_bronze_equals_silver_plus_rejected.sql)

<!-- src: dbt/tests/assert_bronze_equals_silver_plus_rejected.sql:1-10 -->
```sql
-- Reconciliation: no row may vanish. Returns a row only if the counts differ (= test fails).

select *
from (
    select
        (select count(*) from {{ source('bronze', 'green_trips_raw') }})  as bronze_rows,
        (select count(*) from {{ ref('silver_green_trips') }})            as silver_rows,
        (select count(*) from {{ ref('silver_green_trips_rejected') }})   as rejected_rows
)
where bronze_rows != silver_rows + rejected_rows
```

A dbt test is a query that looks for **bad** rows. If it returns nothing, it passes. Here it returns a row only when the counts do not add up.

### The test I added after breaking the pipeline on purpose
[`assert_silver_dropoff_not_before_pickup.sql`](../dbt/tests/assert_silver_dropoff_not_before_pickup.sql)

<!-- src: dbt/tests/assert_silver_dropoff_not_before_pickup.sql:1-6 -->
```sql
-- Silver promises: every trip ends at or after it starts.
-- Returns the offending rows, so any row here means the test fails.

select trip_id, pickup_ts, dropoff_ts
from {{ ref('silver_green_trips') }}
where dropoff_ts < pickup_ts
```

When I removed the dropoff rule as an experiment, the build still passed, because the totals still reconciled. This test checks the rule itself on the output, and it fails with 518 rows if the rule disappears.

*Why it matters: tests should check the promise, not only the arithmetic.*

---

## 4. Orchestrate (Airflow)

[`green_taxi_daily.py` lines 19-33](../airflow/dags/green_taxi_daily.py) and [lines 35-50](../airflow/dags/green_taxi_daily.py)

<!-- src: airflow/dags/green_taxi_daily.py:19-33 -->
```python
default_args = {
    "retries": 2,                          # try again twice before giving up
    "retry_delay": timedelta(minutes=1),   # wait a minute between tries
    "on_failure_callback": alert_on_failure,
}

with DAG(
    dag_id="green_taxi_daily",
    schedule="0 6 * * *",                  # every day at 06:00
    start_date=datetime(2025, 1, 1),
    catchup=False,                         # don't run for every past day
    max_active_runs=1,                     # never overlap: DuckDB allows one writer at a time
    default_args=default_args,
    tags=["nyc-taxi"],
) as dag:
```

<!-- src: airflow/dags/green_taxi_daily.py:35-50 -->
```python
    download = BashOperator(
        task_id="download",
        bash_command=f"cd {PROJECT} && PYTHONPATH=src {PYTHON} -m nyc_taxi_lakehouse.download",
    )

    load_bronze = BashOperator(
        task_id="load_bronze",
        bash_command=f"cd {PROJECT} && PYTHONPATH=src {PYTHON} -m nyc_taxi_lakehouse.load_bronze",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {PROJECT}/dbt && {DBT} build --profiles-dir .",
    )

    download >> load_bronze >> dbt_build
```

- Retries and a schedule are settings. The pipeline itself is the same three commands I run by hand.
- `max_active_runs=1` is the fix for a real incident: two overlapping runs locked the DuckDB file.
- `>>` means "then". If `download` fails, the other two never run.
- The failure callback only prints a message today. Real email or Slack alerts are on the to-do list.

---

## 5. Build the platform (Terraform)

### The bucket
[`main.tf` lines 24-57](../infra/terraform/main.tf)

<!-- src: infra/terraform/main.tf:24-57 -->
```hcl
# 1. The bucket itself.
resource "aws_s3_bucket" "landing" {
  bucket = var.bucket_name
}

# 2. Nobody can ever make this bucket public, even by mistake.
resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Keep old versions of a file when it is overwritten (raw data is never lost).
resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Encrypt everything stored (free, AWS-managed key).
resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Private, versioned and encrypted, written as code instead of clicked. `aws_s3_bucket.landing.id` is a reference, and it is how Terraform learns the order, like `ref()` in dbt.

### The least-privilege role for Databricks
[`iam.tf` lines 29-71](../infra/terraform/iam.tf)

<!-- src: infra/terraform/iam.tf:29-71 -->
```hcl
# WHO may assume this role: Databricks' role, and only with the right external id.
resource "aws_iam_role" "databricks_landing_read" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        AWS = concat([local.unity_catalog_master_role], var.trust_self ? [local.role_arn] : [])
      }
      Condition = {
        StringEquals = { "sts:ExternalId" = var.databricks_external_id }
      }
    }]
  })
}

# WHAT the role may do: read this one bucket, and assume itself (a Databricks requirement).
resource "aws_iam_role_policy" "databricks_landing_read" {
  name = "read-landing-bucket"
  role = aws_iam_role.databricks_landing_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          aws_s3_bucket.landing.arn,
          "${aws_s3_bucket.landing.arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.role_arn
      },
    ]
  })
}
```

Two questions, answered separately: **who** may use the role (Databricks' own role, and only with the right external ID) and **what** it may do (read one bucket, nothing else). No AWS key is stored in Databricks.

---

## 6. Ship (CI and two engines)

### The quality gate
[`ci.yml`](../.github/workflows/ci.yml)

<!-- src: .github/workflows/ci.yml:1-34 -->
```yaml
name: CI

# Run on every push to main and on every pull request.
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      # 1. Get the code onto the machine.
      - uses: actions/checkout@v4

      # 2. Install uv (our package manager), pinned to the same version as the Dockerfile.
      - uses: astral-sh/setup-uv@v6
        with:
          version: "0.13.6"

      # 3. Install exactly the versions in uv.lock (same Python and libraries as on your laptop).
      - run: uv sync --frozen

      # 4. Unit tests for the Python code.
      - run: uv run pytest -q

      # 5. Run the pipeline for real: download -> Bronze.
      - run: uv run python -m nyc_taxi_lakehouse.download
      - run: uv run python -m nyc_taxi_lakehouse.load_bronze

      # 6. dbt builds Silver and Gold and runs all 12 data tests. Any failed test fails the CI.
      - run: uv run dbt build --profiles-dir .
        working-directory: dbt
```

A clean machine installs the exact locked versions and runs the whole chain. If a data rule breaks, the commit turns red.

### Two engines, one set of models
[`profiles.yml`](../dbt/profiles.yml)

<!-- src: dbt/profiles.yml:1-16 -->
```yaml
nyc_taxi:
  target: dev # default: local DuckDB. Use --target databricks for Databricks.
  outputs:
    dev:
      type: duckdb
      path: ../data/warehouse.duckdb

    databricks:
      type: databricks
      catalog: workspace
      schema: dbt
      # Connection details come from environment variables, never from this file.
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      threads: 1
```

The models do not change between engines. Only this file knows where to connect, and secrets come from the environment, never from the repository.

---

## If you present this live

1. The README top: the numbers and the story.
2. The architecture diagram.
3. A data screenshot (the Gold rows).
4. Stop 1 and the reject rules in stop 2.
5. The reconciliation test, then the test added after the experiment.
6. The Airflow graph and a green CI run.
7. The IAM trust policy and `terraform plan` showing no changes.
8. The incident: the lock error, the retry, and `max_active_runs=1`.
