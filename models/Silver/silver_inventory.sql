{{ config(materialized='table') }}

-- CORRECTED APPROACH: the original design tried to get day-over-day stock
-- history via snp_products (a dbt snapshot on top of silver_products).
-- That doesn't work: silver_products collapses all 168 daily product files
-- down to one row per product (latest only) before a snapshot ever sees it,
-- and dbt snapshots can't retroactively backfill pre-existing history in a
-- single run anyway (they only accept one current row per key, per run).
--
-- Since the real daily history already physically exists in Bronze
-- (168 distinct product files, one per day), we compute beginning/ending
-- stock DIRECTLY from that flattened data using lag(), ordered by each
-- file's actual date extracted from the filename. No snapshot needed here.

with products_flattened as (

    select

        value:product_id::string as product_id,
        value:stock_quantity::number as stock_quantity,
        value:reorder_level::number as reorder_level,

        -- Extract the actual as-of date from the filename itself
        -- (e.g. products_2024-04-05.json -> 2024-04-05), since this is the
        -- true daily snapshot date, independent of last_modified_date
        -- (which only changes when a record's content actually changes).
        try_to_date(
            regexp_substr(_source_file, '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        ) as snapshot_date

    from {{ ref('br_products') }},
         lateral flatten(input => raw_data:products_data)

),

deduped as (

    -- Guard against any duplicate product+date combinations (e.g. if a
    -- file was ever loaded twice), keeping one row per product per date
    select *
    from products_flattened
    qualify row_number() over (
        partition by product_id, snapshot_date
        order by snapshot_date
    ) = 1

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

        -- Gap detection per doc: handle the 12-day product snapshot gap
        -- explicitly, rather than silently forward-filling
        datediff(
            day,
            lag(snapshot_date) over (
                partition by product_id
                order by snapshot_date
            ),
            snapshot_date
        ) as days_since_last_snapshot

    from deduped

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

    case
        when ending_stock < 0 or beginning_stock < 0
        then true
        else false
    end as negative_balance_flag

from joined

where beginning_stock is not null  -- each product's very first snapshot has no prior day to compare
