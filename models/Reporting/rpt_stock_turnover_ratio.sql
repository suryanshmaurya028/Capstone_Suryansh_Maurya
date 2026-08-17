{{ config(materialized='view', schema='REPORTING') }}

select

    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,

    round(avg(f.stock_turnover_ratio), 4) as avg_stock_turnover_ratio,
    sum(f.sold_quantity) as total_sold_quantity,
    round(avg((f.beginning_stock + f.ending_stock) / 2.0), 2) as avg_inventory_level

from {{ ref('fact_inventory') }} f
inner join {{ ref('dim_product') }} p
    on f.product_key = p.product_key

group by p.product_id, p.product_name, p.category, p.subcategory
