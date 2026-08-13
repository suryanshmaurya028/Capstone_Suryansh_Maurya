{{ config(materialized='table') }}

with stores_flattened as (

    select
        value as store,
        _loaded_at,
        _source_file,
        _batch_id

    from {{ ref('snp_br_stores') }},
    lateral flatten(input => raw_data:stores_data)

)

select

    store:store_id::string as store_id,

    initcap(trim(store:store_name::string))
        as store_name,

    initcap(trim(store:store_type::string))
        as store_type,

    initcap(trim(store:region::string))
        as region,

    store:is_active::boolean
        as is_active,

    store:manager_id::string
        as manager_id,

    store:employee_count::number
        as employee_count,

    store:size_sq_ft::number
        as size_sq_ft,

    case
        when store:size_sq_ft::number < 5000
            then 'Small'
        when store:size_sq_ft::number between 5000 and 10000
            then 'Medium'
        when store:size_sq_ft::number > 10000
            then 'Large'
        else 'Unknown'
    end as store_size_category,

    try_to_date(store:opening_date::string)
        as opening_date,

    datediff(
        year,
        try_to_date(store:opening_date::string),
        current_date()
    ) as store_age_years,

    store:current_sales::number(18,2)
        as current_sales,

    store:sales_target::number(18,2)
        as sales_target,

    store:monthly_rent::number(18,2)
        as monthly_rent,

    round(
        case
            when store:sales_target::number > 0
            then
                (store:current_sales::number /
                 store:sales_target::number) * 100
        end,
        2
    ) as sales_target_achievement_percentage,

    round(
        case
            when store:size_sq_ft::number > 0
            then
                store:current_sales::number /
                store:size_sq_ft::number
        end,
        2
    ) as revenue_per_sq_ft,

    round(
        case
            when store:employee_count::number > 0
            then
                store:current_sales::number /
                store:employee_count::number
        end,
        2
    ) as employee_efficiency,

    case
        when
            (
                case
                    when store:sales_target::number > 0
                    then
                        (store:current_sales::number /
                         store:sales_target::number) * 100
                end
            ) < 90
        then true
        else false
    end as performance_issue_flag,

    lower(trim(store:email::string))
        as email,

    case
        when regexp_like(
            lower(trim(store:email::string)),
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        )
        then true
        else false
    end as valid_email_flag,

    regexp_replace(
        store:phone_number::string,
        '[^0-9]',
        ''
    ) as phone_number,

    case
        when length(
            regexp_replace(
                store:phone_number::string,
                '[^0-9]',
                ''
            )
        ) >= 10
        then true
        else false
    end as valid_phone_flag,

    initcap(trim(store:address.street::string))
        as street,

    initcap(trim(store:address.city::string))
        as city,

    upper(trim(store:address.state::string))
        as state,

    upper(trim(store:address.country::string))
        as country,

    store:address.zip_code::string
        as zip_code,

    case
        when regexp_like(
            store:address.zip_code::string,
            '^[0-9]{5}$'
        )
        then true
        else false
    end as valid_zip_code_flag,

    store:operating_hours.weekdays::string
        as weekday_hours,

    store:operating_hours.weekends::string
        as weekend_hours,

    store:operating_hours.holidays::string
        as holiday_hours,

    array_to_string(
        store:services,
        ', '
    ) as services,

    try_to_date(
        store:last_modified_date::string
    ) as last_modified_date,

    _loaded_at,
    _source_file,
    _batch_id

from stores_flattened

qualify row_number() over (

    partition by store:store_id::string

    order by
        try_to_date(
            store:last_modified_date::string
        ) desc

) = 1
