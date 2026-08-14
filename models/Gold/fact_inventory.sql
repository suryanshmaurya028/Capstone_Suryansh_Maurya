{{ config(materialized='table', schema='GOLD') }}

-- ============================================================================
-- GRAIN: one row per product per store per date, per doc spec.
--
-- IMPORTANT DATA LIMITATION (documented per doc's own transparency standard):
-- Source Products data has NO store-level stock breakdown — stock_quantity
-- is reported once per product, company-wide. Therefore:
--   - beginning_stock, ending_stock, purchased_quantity are COMPANY-WIDE
--     values, repeated identically across every store row for a given
--     product + date. They are NOT genuinely store-specific.
--   - sold_quantity IS genuinely store-specific, sourced directly from
--     Orders (which does carry store_id).
-- This matches the doc's own source note: "joined to sold quantity from
-- completed orders, and to DIM_Product, DIM_Store, DIM_Supplier, DIM_Date" —
-- i.e. a company-wide stock figure paired with a store-specific sales figure.
-- Stock Turnover Ratio at this grain should be read with that caveat in mind.
-- ============================================================================

with active_stores as (

    select store_key, store_id
    from {{ ref('dim_store') }}

),

company_inventory as (

    select
        product_id,
        snapshot_date,
        beginning_stock,
        ending_stock,
        purchased_quantity,
        low_stock_flag,
        stale_snapshot_flag,
        negative_balance_flag

    from {{ ref('silver_inventory') }}

),

-- Cross join: every product-date combination applies identically to every store
product_date_store as (

    select
        ci.product_id,
        ci.snapshot_date,
        ci.beginning_stock,
        ci.ending_stock,
        ci.purchased_quantity,
        ci.low_stock_flag,
        ci.stale_snapshot_flag,
        ci.negative_balance_flag,
        s.store_id,
        s.store_key

    from company_inventory ci
    cross join active_stores s

),

-- Genuinely store-specific: sold quantity per product per store per day,
-- completed orders only, per doc
sold_by_store as (

    select
        product_id,
        store_id,
        order_dt as sold_date,
        sum(quantity) as sold_quantity

    from {{ ref('silver_orders') }}
    where order_status = 'Completed'
    group by product_id, store_id, order_dt

),

joined as (

    select

        pds.product_id,
        pds.store_id,
        pds.snapshot_date,
        pds.beginning_stock,
        pds.ending_stock,
        pds.purchased_quantity,
        pds.low_stock_flag,
        pds.stale_snapshot_flag,
        pds.negative_balance_flag,
        pds.store_key,

        coalesce(sb.sold_quantity, 0) as sold_quantity,

        p.product_key,
        p.supplier_id,
        p.cost_price,
        sup.supplier_key,
        d.date_key

    from product_date_store pds

    left join sold_by_store sb
        on pds.product_id = sb.product_id
       and pds.store_id = sb.store_id
       and pds.snapshot_date = sb.sold_date

    left join {{ ref('dim_product') }} p
        on pds.product_id = p.product_id

    left join {{ ref('dim_supplier') }} sup
        on p.supplier_id = sup.supplier_id

    left join {{ ref('dim_date') }} d
        on pds.snapshot_date = d.full_date

),

-- Company-wide daily total purchased quantity, needed as the denominator
-- for Supplier Contribution Percentage
daily_total_purchased as (

    select
        snapshot_date,
        sum(purchased_quantity) as total_purchased_quantity_all_products

    from company_inventory
    group by snapshot_date

),

daily_supplier_purchased as (

    select
        ci.snapshot_date,
        p.supplier_id,
        sum(ci.purchased_quantity) as supplier_purchased_quantity

    from company_inventory ci
    left join {{ ref('dim_product') }} p
        on ci.product_id = p.product_id
    group by ci.snapshot_date, p.supplier_id

)

select

    row_number() over (
        order by j.product_key, j.store_key, j.date_key
    ) as inventory_key,

    j.product_key,
    j.store_key,
    j.supplier_key,
    j.date_key,

    j.beginning_stock,
    j.purchased_quantity,
    j.sold_quantity,
    j.ending_stock,

    round(j.ending_stock * j.cost_price, 2) as inventory_value,

    round(
        case
            when (j.beginning_stock + j.ending_stock) / 2 > 0
            then j.sold_quantity / ((j.beginning_stock + j.ending_stock) / 2.0)
            else null
        end,
        4
    ) as stock_turnover_ratio,

    round(
        case
            when dtp.total_purchased_quantity_all_products > 0
            then (dsp.supplier_purchased_quantity / dtp.total_purchased_quantity_all_products) * 100
            else null
        end,
        2
    ) as supplier_contribution_percentage,

    j.low_stock_flag,
    j.stale_snapshot_flag,
    j.negative_balance_flag

from joined j

left join daily_total_purchased dtp
    on j.snapshot_date = dtp.snapshot_date

left join daily_supplier_purchased dsp
    on j.snapshot_date = dsp.snapshot_date
   and j.supplier_id = dsp.supplier_id
