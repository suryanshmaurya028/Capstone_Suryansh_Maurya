{{ config(materialized='table', schema='SILVER') }}

with src_product as (

    select * from {{ ref('snp_product') }} where dbt_valid_to is null

)

select

    product_id,

    initcap(trim(name)) as product_name,
    initcap(trim(brand)) as brand,
    initcap(trim(category)) as category,
    initcap(trim(subcategory)) as subcategory,
    initcap(trim(product_line)) as product_line,

    concat(
        initcap(trim(category)), ' > ', initcap(trim(subcategory)), ' > ', initcap(trim(product_line))
    ) as category_hierarchy,

    trim(short_description) as short_description,
    trim(technical_specs) as technical_specs,

    concat(
        initcap(trim(name)), ' | ', trim(short_description), ' | ', trim(technical_specs)
    ) as full_product_description,

    unit_price,
    cost_price,

    round(
        case when unit_price > 0
        then ((unit_price - cost_price) / unit_price) * 100 end,
        2
    ) as profit_margin_percentage,

    stock_quantity,
    reorder_level,

    case when stock_quantity < reorder_level then true else false end as low_stock_flag,

    supplier_id,
    initcap(trim(color)) as color,
    initcap(trim(size)) as size,
    trim(dimensions) as dimensions,
    trim(weight) as weight,
    trim(warranty_period) as warranty_period,
    is_featured,
    try_to_date(launch_date) as launch_date,
    last_modified_date,

    _loaded_at,
    _source_file

from src_product
