{{ config(materialized='table', schema='GOLD') }}




with company_inventory as (

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


base_with_sales as (

    select

        ci.product_id,
        ci.snapshot_date,
        ci.beginning_stock,
        ci.ending_stock,
        ci.purchased_quantity,
        ci.low_stock_flag,
        ci.stale_snapshot_flag,
        ci.negative_balance_flag,

        sbs.store_id,
        coalesce(sbs.sold_quantity, 0) as sold_quantity

    from company_inventory ci

    left join sold_by_store sbs
        on ci.product_id = sbs.product_id
       and ci.snapshot_date = sbs.sold_date

),


with_product as (

    select

        b.*,

        p.product_key,
        p.supplier_id,
        p.cost_price

    from base_with_sales b

    inner join {{ ref('dim_product') }} p
        on b.product_id = p.product_id

),


with_supplier as (

    select

        wp.*,

        sup.supplier_key

    from with_product wp

    left join {{ ref('dim_supplier') }} sup
        on wp.supplier_id = sup.supplier_id

),


with_store as (

    select

        ws.*,

        st.store_key

    from with_supplier ws

    left join {{ ref('dim_store') }} st
        on ws.store_id = st.store_id

),


with_date as (

    select

        wst.*,

        d.date_key

    from with_store wst

    inner join {{ ref('dim_date') }} d
        on wst.snapshot_date = d.full_date

),


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
    inner join {{ ref('dim_product') }} p
        on ci.product_id = p.product_id
    group by ci.snapshot_date, p.supplier_id

)

select

    row_number() over (
        order by wd.product_key, wd.store_key, wd.date_key
    ) as inventory_key,

    wd.product_key,
    wd.store_key,
    wd.supplier_key,
    wd.date_key,

    wd.beginning_stock,
    wd.purchased_quantity,
    wd.sold_quantity,
    wd.ending_stock,

    round(wd.ending_stock * wd.cost_price, 2) as inventory_value,

    round(
        case
            when (wd.beginning_stock + wd.ending_stock) / 2 > 0
            then wd.sold_quantity / ((wd.beginning_stock + wd.ending_stock) / 2.0)
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

    wd.low_stock_flag,
    wd.stale_snapshot_flag,
    wd.negative_balance_flag

from with_date wd

left join daily_total_purchased dtp
    on wd.snapshot_date = dtp.snapshot_date

left join daily_supplier_purchased dsp
    on wd.snapshot_date = dsp.snapshot_date
   and wd.supplier_id = dsp.supplier_id
