{% snapshot snp_employee %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='employee_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

with flattened as (

    select

        value:employee_id::string as employee_id,
        value:first_name::string as first_name,
        value:last_name::string as last_name,
        value:email::string as email,
        value:phone::string as phone,
        value:date_of_birth::string as date_of_birth,
        value:address:street::string as address_street,
        value:address:city::string as address_city,
        value:address:state::string as address_state,
        value:address:zip_code::string as address_zip_code,
        value:department::string as department,
        value:role::string as role,
        value:education::string as education,
        value:employment_status::string as employment_status,
        value:hire_date::string as hire_date,
        value:manager_id::string as manager_id,
        value:work_location::string as work_location,
        value:salary::number(18,2) as salary,
        value:current_sales::number(18,2) as current_sales,
        value:sales_target::number(18,2) as sales_target,
        value:performance_rating::number(3,1) as performance_rating,
        value:certifications::variant as certifications,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_employees') }},
         lateral flatten(input => raw_data:employees_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by employee_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}