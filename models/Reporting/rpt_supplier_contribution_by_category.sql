{{ config(materialized='view', schema='REPORTING') }}

select

    s.supplier_id,
    s.supplier_name,
    p.category,

    round(avg(f.supplier_contribution_percentage), 2) as avg_contribution_percentage,
    sum(f.purchased_quantity) as total_purchased_quantity

from {{ ref('fact_inventory') }} f
inner join {{ ref('dim_supplier') }} s
    on f.supplier_key = s.supplier_key
inner join {{ ref('dim_product') }} p
    on f.product_key = p.product_key

group by s.supplier_id, s.supplier_name, p.category
