-- Reconciliation: no row may vanish. Returns a row only if the counts differ (= test fails).

select *
from (
    select
        (select count(*) from {{ source('bronze', 'green_trips_raw') }})  as bronze_rows,
        (select count(*) from {{ ref('silver_green_trips') }})            as silver_rows,
        (select count(*) from {{ ref('silver_green_trips_rejected') }})   as rejected_rows
)
where bronze_rows != silver_rows + rejected_rows
