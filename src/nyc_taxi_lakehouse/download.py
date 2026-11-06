"""Download NYC Green Taxi monthly files into data/raw/."""

import hashlib
from pathlib import Path

import requests

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
RAW_DIR = Path("data/raw")


def build_url(month: str) -> str:
    """month looks like '2025-01'."""
    return f"{BASE_URL}/green_tripdata_{month}.parquet"


def sha256_of(path: Path) -> str:
    """Fingerprint of a file. Same bytes -> same fingerprint."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download_month(month: str, raw_dir: Path = RAW_DIR) -> Path:
    """Download one month. If the file already exists, do nothing."""
    raw_dir.mkdir(parents=True, exist_ok=True)
    final_path = raw_dir / f"green_tripdata_{month}.parquet"

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

    print(f"{month}: downloaded, sha256={sha256_of(final_path)[:12]}...")
    return final_path


def download_months(months: list[str]) -> list[Path]:
    return [download_month(month) for month in months]


if __name__ == "__main__":
    download_months(["2025-01", "2025-02", "2025-03"])
