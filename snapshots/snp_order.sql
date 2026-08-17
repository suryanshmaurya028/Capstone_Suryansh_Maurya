{% snapshot snp_order %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}


with flattened as (

    select

        value:order_id::string as order_id,
        value:customer_id::string as customer_id,
        value:employee_id::string as employee_id,
        value:store_id::string as store_id,
        value:campaign_id::string as campaign_id,
        value:order_items::variant as order_items,
        value:discount_amount::number(18,2) as discount_amount,
        value:shipping_cost::number(18,2) as shipping_cost,
        value:tax_amount::number(18,2) as tax_amount,
        value:total_amount::number(18,2) as total_amount,
        value:payment_method::string as payment_method,
        value:shipping_method::string as shipping_method,
        value:order_status::string as order_status,
        value:order_source::string as order_source,
        value:created_at::string as created_at,
        value:order_date::string as order_date,
        value:shipping_date::string as shipping_date,
        value:delivery_date::string as delivery_date,
        value:estimated_delivery_date::string as estimated_delivery_date,
        value:billing_address::variant as billing_address,
        value:shipping_address::variant as shipping_address,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_orders') }},
         lateral flatten(input => raw_data:orders_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by order_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
