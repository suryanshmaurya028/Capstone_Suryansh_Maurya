{{ config(materialized='table', schema='SILVER') }}

with src_supplier as (

    select * from {{ ref('snp_supplier') }} where dbt_valid_to is null

)

select

    supplier_id,
    initcap(trim(supplier_name)) as supplier_name,
    initcap(trim(supplier_type)) as supplier_type,
    categories_supplied,

    initcap(trim(contact_person)) as contact_person,
    lower(trim(contact_email)) as contact_email,

    case
        when regexp_like(lower(trim(contact_email)), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        then true else false
    end as valid_contact_email_flag,

    regexp_replace(contact_phone, '[^0-9]', '') as contact_phone,
    trim(contact_address) as contact_address,

    contract_id,
    try_to_date(contract_start_date) as contract_start_date,
    try_to_date(contract_end_date) as contract_end_date,
    contract_exclusivity,
    contract_renewal_option,

    initcap(trim(payment_terms)) as payment_terms,
    lead_time_days,
    minimum_order_quantity,
    upper(trim(credit_rating)) as credit_rating,
    is_active,
    try_to_date(last_order_date) as last_order_date,
    initcap(trim(preferred_carrier)) as preferred_carrier,

    on_time_delivery_rate,
    average_delay_days,
    defect_rate,
    returns_percentage,
    response_time_hours,
    initcap(trim(quality_rating)) as quality_rating,

    case when on_time_delivery_rate < 90 then true else false end as performance_issue_flag,

    tax_id,
    trim(website) as website,
    year_established,
    last_modified_date,

    _loaded_at,
    _source_file

from src_supplier
