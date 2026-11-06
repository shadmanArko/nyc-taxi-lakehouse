-- Valid trips only. One row per trip.

select
    trip_id,
    VendorID                                   as vendor_id,
    lpep_pickup_datetime                       as pickup_ts,
    lpep_dropoff_datetime                      as dropoff_ts,
    cast(lpep_pickup_datetime as date)         as service_date,
    PULocationID                               as pu_location_id,
    DOLocationID                               as do_location_id,
    passenger_count,
    trip_distance,
    fare_amount,
    tip_amount,
    total_amount,
    total_amount - tip_amount                  as revenue_amount,
    total_amount < 0                           as is_adjustment,
    RatecodeID is null                         as fields_missing,
    payment_type,
    _source_file
from {{ ref('stg_green_trips_classified') }}
where reject_reason is null
