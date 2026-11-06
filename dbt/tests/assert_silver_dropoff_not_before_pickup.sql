-- Silver promises: every trip ends at or after it starts.
-- Returns the offending rows, so any row here means the test fails.

select trip_id, pickup_ts, dropoff_ts
from {{ ref('silver_green_trips') }}
where dropoff_ts < pickup_ts
