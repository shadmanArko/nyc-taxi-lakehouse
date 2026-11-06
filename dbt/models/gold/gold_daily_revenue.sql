-- One row per day.

select
    service_date,
    count(*)                                                        as trip_count,
    round(sum(revenue_amount) filter (where not is_adjustment), 2)  as gross_revenue,
    round(coalesce(sum(revenue_amount) filter (where is_adjustment), 0), 2) as adjustments,
    round(sum(revenue_amount), 2)                                   as net_revenue
from {{ ref('silver_green_trips') }}
group by service_date
order by service_date
