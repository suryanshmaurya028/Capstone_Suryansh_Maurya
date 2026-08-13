{{ config(materialized='table') }}

with customer_flattened as (

    select
        value as customer,
        _loaded_at,
        _source_file,
        _batch_id

    from {{ ref('snp_br_customers') }},
    lateral flatten(input => raw_data:customers_data)

),

customers_cleaned as (

    select

        customer,

        coalesce(
            try_to_date(customer:birth_date::string,'YYYY-MM-DD'),
            try_to_date(customer:birth_date::string,'MM-DD-YYYY'),
            try_to_date(customer:birth_date::string,'DD-MM-YYYY'),
            try_to_date(customer:birth_date::string,'YYYY/MM/DD'),
            try_to_date(customer:birth_date::string,'MM/DD/YYYY'),
            try_to_date(customer:birth_date::string,'DD/MM/YYYY')
        ) as birth_date,

        _loaded_at,
        _source_file,
        _batch_id

    from customer_flattened

)

select

    customer:customer_id::string as customer_id,

    initcap(trim(customer:first_name::string)) as first_name,

    initcap(trim(customer:last_name::string)) as last_name,

    concat(
        initcap(trim(customer:first_name::string)),
        ' ',
        initcap(trim(customer:last_name::string))
    ) as full_name,

    birth_date,

    coalesce(
        datediff(
            year,
            birth_date,
            current_date()
        ),
        0
    ) as customer_age,

    -- Uses the same datediff(year, ...) method as customer_age above,
    -- so age and segment never disagree at birthday edge cases.
    case
        when datediff(year, birth_date, current_date()) between 18 and 35
            then 'Young'

        when datediff(year, birth_date, current_date()) between 36 and 55
            then 'Middle-aged'

        when datediff(year, birth_date, current_date()) >= 56
            then 'Senior'

        else 'Unknown'
    end as customer_segment,

    lower(trim(customer:email::string)) as email,

    case
        when regexp_like(
            lower(trim(customer:email::string)),
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        )
        then true
        else false
    end as valid_email_flag,

    regexp_replace(
        customer:phone::string,
        '[^0-9]',
        ''
    ) as phone_number,

    case
        when length(
            regexp_replace(customer:phone::string,'[^0-9]','')
        ) = 10
        then true
        else false
    end as valid_phone_flag,

    initcap(trim(customer:occupation::string)) as occupation,

    upper(trim(customer:loyalty_tier::string)) as loyalty_tier,

    upper(trim(customer:income_bracket::string)) as income_bracket,

    customer:marketing_opt_in::boolean as marketing_opt_in,

    initcap(trim(customer:preferred_communication::string))
        as preferred_communication,

    initcap(trim(customer:preferred_payment_method::string))
        as preferred_payment_method,

    try_to_date(customer:registration_date::string)
        as registration_date,

    try_to_date(customer:last_purchase_date::string)
        as last_purchase_date,

    try_to_date(customer:last_modified_date::string)
        as last_modified_date,

    customer:total_purchases::number as total_purchases,

    customer:total_spend::number(18,2) as total_spend,

    initcap(trim(customer:address.street::string))
        as street,

    initcap(trim(customer:address.city::string))
        as city,

    upper(trim(customer:address.state::string))
        as state,

    upper(trim(customer:address.country::string))
        as country,

    customer:address.zip_code::string
        as zip_code,

    _loaded_at,
    _source_file,
    _batch_id

from customers_cleaned

qualify row_number() over (
    partition by customer:customer_id::string
    order by try_to_date(customer:last_modified_date::string) desc
) = 1
