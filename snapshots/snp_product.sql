{% snapshot snp_product %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

with flattened as (

    select

        value:product_id::string as product_id,
        value:name::string as name,
        value:short_description::string as short_description,
        value:technical_specs::string as technical_specs,
        value:category::string as category,
        value:subcategory::string as subcategory,
        value:product_line::string as product_line,
        value:brand::string as brand,
        value:color::string as color,
        value:size::string as size,
        value:weight::string as weight,
        value:dimensions::string as dimensions,
        value:unit_price::number(18,2) as unit_price,
        value:cost_price::number(18,2) as cost_price,
        value:stock_quantity::number as stock_quantity,
        value:reorder_level::number as reorder_level,
        value:supplier_id::string as supplier_id,
        value:is_featured::boolean as is_featured,
        value:warranty_period::string as warranty_period,
        value:launch_date::string as launch_date,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_products') }},
         lateral flatten(input => raw_data:products_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by product_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
