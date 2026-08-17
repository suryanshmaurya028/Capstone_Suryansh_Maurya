{{ config(materialized='table', schema='SILVER') }}

with src_store as (

    select * from {{ ref('snp_store') }} where dbt_valid_to is null

)

select

    store_id,
    initcap(trim(store_name)) as store_name,
    initcap(trim(store_type)) as store_type,
    initcap(trim(region)) as region,
    is_active,
    manager_id,
    employee_count,
    size_sq_ft,

    case
        when size_sq_ft < 5000 then 'Small'
        when size_sq_ft between 5000 and 10000 then 'Medium'
        when size_sq_ft > 10000 then 'Large'
        else 'Unknown'
    end as store_size_category,

    try_to_date(opening_date) as opening_date,

    datediff(year, try_to_date(opening_date), current_date()) as store_age_years,

    current_sales,
    sales_target,
    monthly_rent,

    round(
        case when sales_target > 0 then (current_sales / sales_target) * 100 end,
        2
    ) as sales_target_achievement_percentage,

    round(
        case when size_sq_ft > 0 then current_sales / size_sq_ft end,
        2
    ) as revenue_per_sq_ft,

    round(
        case when employee_count > 0 then current_sales / employee_count end,
        2
    ) as employee_efficiency,

    case
        when (case when sales_target > 0 then (current_sales / sales_target) * 100 end) < 90
        then true else false
    end as performance_issue_flag,

    lower(trim(email)) as email,

    case
        when regexp_like(lower(trim(email)), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        then true else false
    end as valid_email_flag,

    regexp_replace(phone_number, '[^0-9]', '') as phone_number,

    case
        when length(regexp_replace(phone_number, '[^0-9]', '')) >= 10
        then true else false
    end as valid_phone_flag,

    initcap(trim(address_street)) as street,
    initcap(trim(address_city)) as city,
    upper(trim(address_state)) as state,
    upper(trim(address_country)) as country,
    address_zip_code as zip_code,

    case
        when regexp_like(address_zip_code, '^[0-9]{5}$') then true else false
    end as valid_zip_code_flag,

    operating_hours_weekdays as weekday_hours,
    operating_hours_weekends as weekend_hours,
    operating_hours_holidays as holiday_hours,

    array_to_string(services, ', ') as services,

    last_modified_date,

    _loaded_at,
    _source_file

from src_store
