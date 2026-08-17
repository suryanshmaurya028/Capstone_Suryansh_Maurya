{% snapshot snp_supplier %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='supplier_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

with flattened as (

    select

        value:supplier_id::string as supplier_id,
        value:supplier_name::string as supplier_name,
        value:supplier_type::string as supplier_type,
        value:categories_supplied::variant as categories_supplied,
        value:contact_information:contact_person::string as contact_person,
        value:contact_information:email::string as contact_email,
        value:contact_information:phone::string as contact_phone,
        value:contact_information:address::string as contact_address,
        value:contract_details:contract_id::string as contract_id,
        value:contract_details:start_date::string as contract_start_date,
        value:contract_details:end_date::string as contract_end_date,
        value:contract_details:exclusivity::boolean as contract_exclusivity,
        value:contract_details:renewal_option::boolean as contract_renewal_option,
        value:payment_terms::string as payment_terms,
        value:lead_time_days::number as lead_time_days,
        value:minimum_order_quantity::number as minimum_order_quantity,
        value:credit_rating::string as credit_rating,
        value:is_active::boolean as is_active,
        value:last_order_date::string as last_order_date,
        value:preferred_carrier::string as preferred_carrier,
        value:performance_metrics:on_time_delivery_rate::number(5,2) as on_time_delivery_rate,
        value:performance_metrics:average_delay_days::number(5,2) as average_delay_days,
        value:performance_metrics:defect_rate::number(5,2) as defect_rate,
        value:performance_metrics:returns_percentage::number(5,2) as returns_percentage,
        value:performance_metrics:response_time_hours::number as response_time_hours,
        value:performance_metrics:quality_rating::string as quality_rating,
        value:tax_id::string as tax_id,
        value:website::string as website,
        value:year_established::number as year_established,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_suppliers') }},
         lateral flatten(input => raw_data:suppliers_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by supplier_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
