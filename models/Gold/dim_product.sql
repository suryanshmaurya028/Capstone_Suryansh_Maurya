{{ config(materialized='table', schema='GOLD') }}

select

    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,

    product_id,
    product_name,
    category,
    subcategory,
    product_line,
    category_hierarchy,
    brand,
    color,
    size,
    dimensions,
    weight,
    unit_price,
    cost_price,
    profit_margin_percentage,
    stock_quantity,
    reorder_level,
    low_stock_flag,
    warranty_period,
    is_featured,
    launch_date,
    supplier_id,
    last_modified_date

from {{ ref('silver_products') }}