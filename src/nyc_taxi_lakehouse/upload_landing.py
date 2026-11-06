"""Upload raw Parquet files from data/raw to the S3 landing bucket, unchanged."""

from pathlib import Path

import boto3
from botocore.exceptions import ClientError

BUCKET = "arko-nyc-taxi-lakehouse-landing"
RAW_DIR = Path("data/raw")


def build_key(file_name: str) -> str:
    """green_tripdata_2025-01.parquet -> landing/green_taxi/year=2025/month=01/green_tripdata_2025-01.parquet"""
    month_part = file_name.removesuffix(".parquet").split("_")[-1]  # "2025-01"
    year, month = month_part.split("-")
    return f"landing/green_taxi/year={year}/month={month}/{file_name}"


def already_uploaded(s3, bucket: str, key: str) -> bool:
    """True if the object exists. Only 'not found' means no; any other error is raised."""
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as error:
        if error.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def upload_file(s3, file_path: Path, bucket: str = BUCKET) -> str:
    """Upload one file. Raw files are never overwritten, so an existing key is skipped."""
    key = build_key(file_path.name)
    if already_uploaded(s3, bucket, key):
        print(f"{file_path.name}: already in s3://{bucket}/{key}, skipped")
    else:
        s3.upload_file(str(file_path), bucket, key)
        print(f"{file_path.name}: uploaded to s3://{bucket}/{key}")
    return key


def upload_all(raw_dir: Path = RAW_DIR) -> None:
    s3 = boto3.client("s3")
    for file_path in sorted(raw_dir.glob("green_tripdata_*.parquet")):
        upload_file(s3, file_path)


if __name__ == "__main__":
    upload_all()
