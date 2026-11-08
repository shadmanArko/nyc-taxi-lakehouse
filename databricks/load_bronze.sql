-- Load the S3 landing files into the Bronze Delta table.
-- Run each statement on its own in the Databricks SQL Editor (select it, then Ctrl/Cmd+Enter).
-- Same job as src/nyc_taxi_lakehouse/load_bronze.py (DuckDB), but with Databricks' own loader.

-- 1. A schema (folder) for Bronze.
CREATE SCHEMA IF NOT EXISTS workspace.bronze;

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

-- 4. Check: rows per file. Expected 48326, 46621 and 51539, the same as the DuckDB Bronze.
SELECT _source_file, count(*) AS row_count
FROM workspace.bronze.green_trips_raw
GROUP BY _source_file
ORDER BY _source_file;
