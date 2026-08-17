{{ config(materialized='table', schema='SILVER') }}

with src_campaign as (

    select * from {{ ref('snp_campaign') }} where dbt_valid_to is null

)

select

    campaign_id,
    initcap(trim(campaign_name)) as campaign_name,
    initcap(trim(campaign_type)) as campaign_type,
    initcap(trim(channel)) as channel,
    trim(description) as description,
    trim(target_audience) as target_audience_raw,

    coalesce(
        regexp_substr(target_audience, '[0-9]{1,2}-[0-9]{1,2}'),
        trim(split_part(target_audience, ',', 1))
    ) as audience_age_segment,

    trim(split_part(target_audience, ',', 1)) as audience_group,

    try_to_timestamp(start_date) as start_date,
    try_to_timestamp(end_date) as end_date,

    datediff(day, try_to_date(start_date), try_to_date(end_date)) as campaign_duration_days,

    try_to_number(regexp_replace(budget, '[$,]', ''), 18, 2) as budget,
    try_to_number(regexp_replace(total_cost, '[$,]', ''), 18, 2) as total_cost,
    try_to_number(regexp_replace(total_revenue, '[$,]', ''), 18, 2) as total_revenue,
    try_to_number(roi_calculation, 18, 4) as roi_calculation_raw,

    last_modified_date,

    _loaded_at,
    _source_file

from src_campaign
