{{ config(materialized='table', schema='SILVER') }}

with src_customer as (

    select * from {{ ref('snp_customer') }} where dbt_valid_to is null

),

customers_cleaned as (

    select

        customer_id,
        first_name,
        last_name,

        coalesce(
            try_to_date(birth_date_raw,'YYYY-MM-DD'),
            try_to_date(birth_date_raw,'MM-DD-YYYY'),
            try_to_date(birth_date_raw,'DD-MM-YYYY'),
            try_to_date(birth_date_raw,'YYYY/MM/DD'),
            try_to_date(birth_date_raw,'MM/DD/YYYY'),
            try_to_date(birth_date_raw,'DD/MM/YYYY')
        ) as birth_date,

        email,
        phone,
        address_street,
        address_city,
        address_state,
        address_zip_code,
        address_country,
        income_bracket,
        occupation,
        loyalty_tier,
        marketing_opt_in,
        preferred_communication,
        preferred_payment_method,
        try_to_date(registration_date) as registration_date,
        try_to_date(last_purchase_date) as last_purchase_date,
        total_purchases,
        total_spend,
        last_modified_date,
        _loaded_at,
        _source_file

    from src_customer

)

select

    customer_id,

    initcap(trim(first_name)) as first_name,
    initcap(trim(last_name)) as last_name,

    concat(initcap(trim(first_name)), ' ', initcap(trim(last_name))) as full_name,

    birth_date,

    coalesce(datediff(year, birth_date, current_date()), 0) as customer_age,

    case
        when datediff(year, birth_date, current_date()) between 18 and 35 then 'Young'
        when datediff(year, birth_date, current_date()) between 36 and 55 then 'Middle-aged'
        when datediff(year, birth_date, current_date()) >= 56 then 'Senior'
        else 'Unknown'
    end as customer_segment,

    lower(trim(email)) as email,

    case
        when regexp_like(lower(trim(email)), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        then true else false
    end as valid_email_flag,

    regexp_replace(phone, '[^0-9]', '') as phone_number,

    case
        when length(regexp_replace(phone, '[^0-9]', '')) = 10
        then true else false
    end as valid_phone_flag,

    initcap(trim(occupation)) as occupation,
    upper(trim(loyalty_tier)) as loyalty_tier,
    upper(trim(income_bracket)) as income_bracket,
    marketing_opt_in,
    initcap(trim(preferred_communication)) as preferred_communication,
    initcap(trim(preferred_payment_method)) as preferred_payment_method,
    registration_date,
    last_purchase_date,
    last_modified_date,
    total_purchases,
    total_spend,

    initcap(trim(address_street)) as street,
    initcap(trim(address_city)) as city,
    upper(trim(address_state)) as state,
    upper(trim(address_country)) as country,
    address_zip_code as zip_code,

    _loaded_at,
    _source_file

from customers_cleaned
