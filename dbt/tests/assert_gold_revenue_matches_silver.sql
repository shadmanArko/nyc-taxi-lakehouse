-- Reconciliation: Gold total must equal Silver total. Returns a row only on mismatch.

select *
from (
    select
        (select round(sum(net_revenue), 2) from {{ ref('gold_daily_revenue') }})  as gold_total,
        (select round(sum(revenue_amount), 2) from {{ ref('silver_green_trips') }}) as silver_total
)
where gold_total != silver_total
