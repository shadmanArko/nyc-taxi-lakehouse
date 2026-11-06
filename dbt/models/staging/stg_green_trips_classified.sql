-- One row per Bronze row. Adds trip_id and a reject_reason (NULL = row is valid).

with base as (

    select
        md5(concat_ws('|',
            coalesce(cast(VendorID as varchar), ''),
            coalesce(cast(lpep_pickup_datetime as varchar), ''),
            coalesce(cast(lpep_dropoff_datetime as varchar), ''),
            coalesce(cast(PULocationID as varchar), ''),
            coalesce(cast(DOLocationID as varchar), ''),
            coalesce(cast(trip_distance as varchar), ''),
            coalesce(cast(total_amount as varchar), '')
        )) as trip_id,
        *
    from {{ source('bronze', 'green_trips_raw') }}

),

numbered as (

    select
        *,
        row_number() over (partition by trip_id order by _ingested_at, _source_file) as copy_number
    from base

)

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
