{{ config(materialized='table', schema='GOLD') }}

select

    row_number() over (order by store_id) as store_key,

    store_id,
    store_name,
    store_type,
    region,
    street,
    city,
    state,
    country,
    zip_code,
    opening_date,
    store_age_years,
    size_sq_ft,
    store_size_category,
    is_active,
    manager_id,
    employee_count,
    current_sales,
    sales_target,
    monthly_rent,
    sales_target_achievement_percentage,
    revenue_per_sq_ft,
    employee_efficiency,
    performance_issue_flag,
    weekday_hours,
    weekend_hours,
    holiday_hours,
    services,
    last_modified_date

from {{ ref('silver_stores') }}
