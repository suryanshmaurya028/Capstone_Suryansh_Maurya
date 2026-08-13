{{ config(materialized='table') }}

with supplier_flattened as (

    select
        value as supplier,
        _loaded_at,
        _source_file,
        _batch_id

    from {{ ref('snp_br_suppliers') }},
    lateral flatten(input => raw_data:suppliers_data)

)

select

    supplier:supplier_id::string as supplier_id,

    initcap(trim(supplier:supplier_name::string)) as supplier_name,

    initcap(trim(supplier:supplier_type::string)) as supplier_type,

    supplier:categories_supplied as categories_supplied,

    -- contact_information.address arrives as one full address string
    -- (not broken into street/city/state/zip) — confirmed against real data
    initcap(trim(supplier:contact_information:contact_person::string))
        as contact_person,

    lower(trim(supplier:contact_information:email::string))
        as contact_email,

    case
        when regexp_like(
            lower(trim(supplier:contact_information:email::string)),
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        )
        then true
        else false
    end as valid_contact_email_flag,

    regexp_replace(
        supplier:contact_information:phone::string,
        '[^0-9]',
        ''
    ) as contact_phone,

    trim(supplier:contact_information:address::string)
        as contact_address,

    supplier:contract_details:contract_id::string
        as contract_id,

    try_to_date(supplier:contract_details:start_date::string)
        as contract_start_date,

    try_to_date(supplier:contract_details:end_date::string)
        as contract_end_date,

    supplier:contract_details:exclusivity::boolean
        as contract_exclusivity,

    supplier:contract_details:renewal_option::boolean
        as contract_renewal_option,

    initcap(trim(supplier:payment_terms::string))
        as payment_terms,

    supplier:lead_time_days::number
        as lead_time_days,

    supplier:minimum_order_quantity::number
        as minimum_order_quantity,

    upper(trim(supplier:credit_rating::string))
        as credit_rating,

    supplier:is_active::boolean
        as is_active,

    try_to_date(supplier:last_order_date::string)
        as last_order_date,

    initcap(trim(supplier:preferred_carrier::string))
        as preferred_carrier,

    supplier:performance_metrics:on_time_delivery_rate::number(5,2)
        as on_time_delivery_rate,

    supplier:performance_metrics:average_delay_days::number(5,2)
        as average_delay_days,

    supplier:performance_metrics:defect_rate::number(5,2)
        as defect_rate,

    supplier:performance_metrics:returns_percentage::number(5,2)
        as returns_percentage,

    supplier:performance_metrics:response_time_hours::number
        as response_time_hours,

    initcap(trim(supplier:performance_metrics:quality_rating::string))
        as quality_rating,

    case
        when supplier:performance_metrics:on_time_delivery_rate::number(5,2) < 90
        then true
        else false
    end as performance_issue_flag,

    supplier:tax_id::string
        as tax_id,

    trim(supplier:website::string)
        as website,

    supplier:year_established::number
        as year_established,

    try_to_date(supplier:last_modified_date::string)
        as last_modified_date,

    _loaded_at,
    _source_file,
    _batch_id

from supplier_flattened

qualify row_number() over (
    partition by supplier:supplier_id::string
    order by try_to_date(supplier:last_modified_date::string) desc
) = 1
