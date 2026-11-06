-- Rows that failed a rule, with the reason. Nothing is silently deleted.

select
    trip_id,
    reject_reason,
    lpep_pickup_datetime,
    lpep_dropoff_datetime,
    total_amount,
    _source_file
from {{ ref('stg_green_trips_classified') }}
where reject_reason is not null
