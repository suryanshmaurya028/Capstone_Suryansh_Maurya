{% snapshot snp_store %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='store_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

with flattened as (

    select

        value:store_id::string as store_id,
        value:store_name::string as store_name,
        value:store_type::string as store_type,
        value:region::string as region,
        value:address:street::string as address_street,
        value:address:city::string as address_city,
        value:address:state::string as address_state,
        value:address:zip_code::string as address_zip_code,
        value:address:country::string as address_country,
        value:email::string as email,
        value:phone_number::string as phone_number,
        value:manager_id::string as manager_id,
        value:employee_count::number as employee_count,
        value:size_sq_ft::number as size_sq_ft,
        value:opening_date::string as opening_date,
        value:is_active::boolean as is_active,
        value:monthly_rent::number(18,2) as monthly_rent,
        value:sales_target::number(18,2) as sales_target,
        value:current_sales::number(18,2) as current_sales,
        value:operating_hours:weekdays::string as operating_hours_weekdays,
        value:operating_hours:weekends::string as operating_hours_weekends,
        value:operating_hours:holidays::string as operating_hours_holidays,
        value:services::variant as services,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_stores') }},
         lateral flatten(input => raw_data:stores_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by store_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
