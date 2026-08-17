{% snapshot snp_customer %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}


with flattened as (

    select

        value:customer_id::string as customer_id,
        value:first_name::string as first_name,
        value:last_name::string as last_name,
        value:email::string as email,
        value:phone::string as phone,
        value:birth_date::string as birth_date_raw,
        value:address:street::string as address_street,
        value:address:city::string as address_city,
        value:address:state::string as address_state,
        value:address:zip_code::string as address_zip_code,
        value:address:country::string as address_country,
        value:income_bracket::string as income_bracket,
        value:occupation::string as occupation,
        value:loyalty_tier::string as loyalty_tier,
        value:marketing_opt_in::boolean as marketing_opt_in,
        value:preferred_communication::string as preferred_communication,
        value:preferred_payment_method::string as preferred_payment_method,
        value:registration_date::string as registration_date,
        value:last_purchase_date::string as last_purchase_date,
        value:total_purchases::number as total_purchases,
        value:total_spend::number(18,2) as total_spend,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_customers') }},
         lateral flatten(input => raw_data:customers_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by customer_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
