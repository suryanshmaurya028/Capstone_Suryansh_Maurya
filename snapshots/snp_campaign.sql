{% snapshot snp_campaign %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='campaign_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

with flattened as (

    select

        value:campaign_id::string as campaign_id,
        value:campaign_name::string as campaign_name,
        value:campaign_type::string as campaign_type,
        value:channel::string as channel,
        value:description::string as description,
        value:target_audience::string as target_audience,
        value:start_date::string as start_date,
        value:end_date::string as end_date,
        value:budget::string as budget,
        value:total_cost::string as total_cost,
        value:total_revenue::string as total_revenue,
        value:roi_calculation::string as roi_calculation,
        try_to_date(value:last_modified_date::string) as last_modified_date,
        _file_last_modified,
        _loaded_at,
        _source_file

    from {{ ref('br_campaigns') }},
         lateral flatten(input => raw_data:campaigns_data)

),

deduped as (

    select *
    from flattened
    qualify row_number() over (
        partition by campaign_id
        order by _file_last_modified desc, _loaded_at desc
    ) = 1

)

select * from deduped

{% endsnapshot %}
