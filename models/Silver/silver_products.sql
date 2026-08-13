{{ config(materialized='table') }}

with products_flattened as (

    select
        value as product,
        _loaded_at,
        _source_file,
        _batch_id

    from {{ ref('snp_br_products') }},
    lateral flatten(input => raw_data:products_data)

)

select

    product:product_id::string as product_id,

    initcap(trim(product:name::string)) as product_name,

    initcap(trim(product:brand::string)) as brand,

    initcap(trim(product:category::string)) as category,

    initcap(trim(product:subcategory::string)) as subcategory,

    initcap(trim(product:product_line::string)) as product_line,

    concat(
        initcap(trim(product:category::string)),
        ' > ',
        initcap(trim(product:subcategory::string)),
        ' > ',
        initcap(trim(product:product_line::string))
    ) as category_hierarchy,

    trim(product:short_description::string)
        as short_description,

    trim(product:technical_specs::string)
        as technical_specs,

    concat(
        initcap(trim(product:name::string)),
        ' | ',
        trim(product:short_description::string),
        ' | ',
        trim(product:technical_specs::string)
    ) as full_product_description,

    product:unit_price::number(18,2)
        as unit_price,

    product:cost_price::number(18,2)
        as cost_price,

    round(
        case
            when product:unit_price::number > 0
            then
            (
                (
                    product:unit_price::number
                    -
                    product:cost_price::number
                )
                /
                product:unit_price::number
            ) * 100
        end,
        2
    ) as profit_margin_percentage,

    product:stock_quantity::number
        as stock_quantity,

    product:reorder_level::number
        as reorder_level,

    case
        when product:stock_quantity::number
             <
             product:reorder_level::number
        then true
        else false
    end as low_stock_flag,

    product:supplier_id::string
        as supplier_id,

    initcap(trim(product:color::string))
        as color,

    initcap(trim(product:size::string))
        as size,

    trim(product:dimensions::string)
        as dimensions,

    trim(product:weight::string)
        as weight,

    trim(product:warranty_period::string)
        as warranty_period,

    product:is_featured::boolean
        as is_featured,

    try_to_date(product:launch_date::string)
        as launch_date,

    try_to_date(product:last_modified_date::string)
        as last_modified_date,

    _loaded_at,
    _source_file,
    _batch_id

from products_flattened

qualify row_number() over (

    partition by product:product_id::string

    order by
        try_to_date(
            product:last_modified_date::string
        ) desc

) = 1
