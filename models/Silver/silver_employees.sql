{{ config(materialized='table', schema='SILVER') }}

with src_employee as (

    select * from {{ ref('snp_employee') }} where dbt_valid_to is null

)

select

    employee_id,

    initcap(trim(first_name)) as first_name,
    initcap(trim(last_name)) as last_name,

    concat(initcap(trim(first_name)), ' ', initcap(trim(last_name))) as full_name,

    lower(trim(email)) as email,

    case
        when regexp_like(lower(trim(email)), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        then true else false
    end as valid_email_flag,

    regexp_replace(phone, '[^0-9]', '') as phone_number,

    try_to_date(date_of_birth) as date_of_birth,

    datediff(year, try_to_date(date_of_birth), current_date()) as age,

    try_to_date(hire_date) as hire_date,

    datediff(year, try_to_date(hire_date), current_date()) as tenure_years,

    initcap(trim(department)) as department,

    -- Standardize role naming to consistent title case
    initcap(trim(role)) as role,

    initcap(trim(education)) as education,
    upper(trim(employment_status)) as employment_status,

    salary,
    current_sales,
    sales_target,

    round(
        case
            when sales_target > 0
            then (current_sales / sales_target) * 100
        end,
        2
    ) as sales_target_achievement_percentage,

    performance_rating,

    case
        when performance_rating < 2.5 then true
        else false
    end as low_performance_flag,

    manager_id,

    -- Ties employee to a store, per doc's data (work_location holds a store_id)
    work_location as store_id,

    initcap(trim(address_street)) as street,
    initcap(trim(address_city)) as city,
    upper(trim(address_state)) as state,
    address_zip_code as zip_code,

    certifications,

    last_modified_date,

    _loaded_at,
    _source_file

from src_employee
