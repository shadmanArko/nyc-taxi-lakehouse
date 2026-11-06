from botocore.exceptions import ClientError

from nyc_taxi_lakehouse.upload_landing import build_key, upload_file


class FakeS3:
    """Pretends to be S3: remembers uploads in a dict, no network needed."""

    def __init__(self, existing_keys=()):
        self.keys = set(existing_keys)
        self.uploaded = []

    def head_object(self, Bucket, Key):
        if Key not in self.keys:
            raise ClientError({"Error": {"Code": "404"}}, "HeadObject")

    def upload_file(self, filename, bucket, key):
        self.keys.add(key)
        self.uploaded.append(key)


def test_build_key():
    key = build_key("green_tripdata_2025-01.parquet")
    assert key == "landing/green_taxi/year=2025/month=01/green_tripdata_2025-01.parquet"


def test_new_file_is_uploaded(tmp_path):
    file_path = tmp_path / "green_tripdata_2025-02.parquet"
    file_path.write_bytes(b"data")
    s3 = FakeS3()

    key = upload_file(s3, file_path, bucket="test-bucket")

    assert s3.uploaded == [key]


def test_existing_file_is_not_uploaded_again(tmp_path):
    file_path = tmp_path / "green_tripdata_2025-02.parquet"
    file_path.write_bytes(b"data")
    s3 = FakeS3(existing_keys=[build_key(file_path.name)])

    upload_file(s3, file_path, bucket="test-bucket")

    assert s3.uploaded == []
