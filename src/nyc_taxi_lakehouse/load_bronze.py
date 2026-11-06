"""Load raw Parquet files into the Bronze table, unchanged, plus 3 metadata columns."""

import uuid
from pathlib import Path

import duckdb

RAW_DIR = Path("data/raw")
DB_PATH = Path("data/warehouse.duckdb")
TABLE = "bronze.green_trips_raw"


def load_file(con: duckdb.DuckDBPyConnection, file_path: Path, batch_id: str) -> int:
    """Load one file into Bronze. Safe to run again: old rows of this file are replaced."""
    file_name = file_path.name

    select_sql = f"""
        SELECT
            *,
            '{file_name}'        AS _source_file,
            current_timestamp    AS _ingested_at,
            '{batch_id}'         AS _batch_id
        FROM read_parquet('{file_path}')
    """

    # Create the table (empty) the first time, copying the structure of the query.
    con.execute(f"CREATE TABLE IF NOT EXISTS {TABLE} AS {select_sql} LIMIT 0")

    # Idempotent: remove anything previously loaded from this same file...
    con.execute(f"DELETE FROM {TABLE} WHERE _source_file = ?", [file_name])
    # ...then insert it again.
    con.execute(f"INSERT INTO {TABLE} BY NAME {select_sql}")

    return con.execute(
        f"SELECT count(*) FROM {TABLE} WHERE _source_file = ?", [file_name]
    ).fetchone()[0]


def load_all(raw_dir: Path = RAW_DIR, db_path: Path = DB_PATH) -> None:
    batch_id = str(uuid.uuid4())
    con = duckdb.connect(str(db_path))
    con.execute("CREATE SCHEMA IF NOT EXISTS bronze")

    for file_path in sorted(raw_dir.glob("green_tripdata_*.parquet")):
        rows = load_file(con, file_path, batch_id)
        print(f"{file_path.name}: {rows} rows in bronze")

    con.close()


if __name__ == "__main__":
    load_all()
