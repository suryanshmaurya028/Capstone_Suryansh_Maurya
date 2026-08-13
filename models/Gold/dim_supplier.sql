{{ config(materialized='table', schema='GOLD') }}

select

    row_number() over (order by supplier_id) as supplier_key,

    supplier_id,
    supplier_name,
    supplier_type,
    categories_supplied,
    contact_person,
    contact_email,
    contact_phone,
    contact_address,
    contract_id,
    contract_start_date,
    contract_end_date,
    contract_exclusivity,
    contract_renewal_option,
    payment_terms,
    lead_time_days,
    minimum_order_quantity,
    credit_rating,
    is_active,
    last_order_date,
    preferred_carrier,
    on_time_delivery_rate,
    average_delay_days,
    defect_rate,
    returns_percentage,
    response_time_hours,
    quality_rating,
    performance_issue_flag,
    tax_id,
    website,
    year_established,
    last_modified_date

from {{ ref('silver_suppliers') }}
