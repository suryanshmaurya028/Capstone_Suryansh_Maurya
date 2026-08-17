{{ config(materialized='view', schema='REPORTING') }}

select

    p.category,
    p.subcategory,
    p.product_id,
    p.product_name,

    round(avg(f.inventory_value), 2) as avg_inventory_value,
    round(sum(f.inventory_value), 2) as total_inventory_value,
    round(avg(f.ending_stock), 2) as avg_ending_stock

from {{ ref('fact_inventory') }} f
inner join {{ ref('dim_product') }} p
    on f.product_key = p.product_key

group by p.category, p.subcategory, p.product_id, p.product_name
