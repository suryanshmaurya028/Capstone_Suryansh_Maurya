{{ config(materialized='table') }}

-- Per doc: "Derive a daily stock position per product from consecutive
-- product snapshots." This is built entirely from data you already have:
-- snp_products (SCD2 history of stock_quantity over time) + silver_orders
-- (completed orders, for sold_quantity). No separate inventory source exists.

with stock_history as (

    select
        product_id,
        stock_quantity,
        reorder_level,
        dbt_valid_from::date as snapshot_date,
        dbt_valid_to::date as valid_to_date

    from {{ ref('snp_products') }}

),

stock_with_lag as (

    select

        product_id,
        snapshot_date,
        reorder_level,

        lag(stock_quantity) over (
            partition by product_id
            order by snapshot_date
        ) as beginning_stock,

        stock_quantity as ending_stock,

        -- Gap detection: per doc, "handle the 12-day product snapshot gap
        -- explicitly (carry-forward or mark stale)". This flags gaps rather
        -- than silently forward-filling, so downstream consumers know when
        -- a reading is not based on a fresh daily snapshot.
        datediff(
            day,
            lag(snapshot_date) over (
                partition by product_id
                order by snapshot_date
            ),
            snapshot_date
        ) as days_since_last_snapshot

    from stock_history

),

sold_quantities as (

    -- Only orders with status 'Completed' count as sold, per doc
    select
        product_id,
        order_dt as sold_date,
        sum(quantity) as sold_quantity

    from {{ ref('silver_orders') }}
    where order_status = 'Completed'
    group by product_id, order_dt

),

joined as (

    select

        s.product_id,
        s.snapshot_date,
        s.beginning_stock,
        s.ending_stock,
        s.reorder_level,
        s.days_since_last_snapshot,

        coalesce(sq.sold_quantity, 0) as sold_quantity

    from stock_with_lag s
    left join sold_quantities sq
        on s.product_id = sq.product_id
       and s.snapshot_date = sq.sold_date

)

select

    product_id,
    snapshot_date,
    beginning_stock,
    ending_stock,
    sold_quantity,

    -- Inferred delta, per doc: no receiving events are recorded, so this
    -- is inferred, not observed
    (ending_stock - coalesce(beginning_stock, ending_stock) + sold_quantity)
        as purchased_quantity,

    case
        when ending_stock < reorder_level then true
        else false
    end as low_stock_flag,

    case
        when days_since_last_snapshot > 1 then true
        else false
    end as stale_snapshot_flag,

    days_since_last_snapshot,

    -- Validate/reject negative balances per doc, rather than silently
    -- allowing them through
    case
        when ending_stock < 0 or beginning_stock < 0
        then true
        else false
    end as negative_balance_flag

from joined

where beginning_stock is not null  -- first snapshot per product has no prior day to compare
