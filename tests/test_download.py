from nyc_taxi_lakehouse.download import build_url, download_month


def test_build_url():
    assert build_url("2025-01").endswith("/green_tripdata_2025-01.parquet")


def test_existing_file_is_not_downloaded_again(tmp_path):
    existing = tmp_path / "green_tripdata_2025-01.parquet"
    existing.write_bytes(b"already here")

    result = download_month("2025-01", raw_dir=tmp_path)

    assert result == existing
    assert existing.read_bytes() == b"already here"  # untouched
