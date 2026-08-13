{{ config(materialized='table') }}

with campaign_flattened as (

    select
        value as campaign,
        _loaded_at,
        _source_file,
        _batch_id

    from {{ ref('snp_br_campaigns') }},
    lateral flatten(input => raw_data:campaigns_data)

)

select

    campaign:campaign_id::string as campaign_id,

    initcap(trim(campaign:campaign_name::string)) as campaign_name,

    initcap(trim(campaign:campaign_type::string)) as campaign_type,

    initcap(trim(campaign:channel::string)) as channel,

    trim(campaign:description::string) as description,

    trim(campaign:target_audience::string) as target_audience_raw,

    -- Derived audience segment: target_audience arrives as free text like
    -- "Students, 18-25, Campus" — split out the age-range token if present,
    -- otherwise fall back to the first comma-separated segment (role/group).
    coalesce(
        regexp_substr(campaign:target_audience::string, '[0-9]{1,2}-[0-9]{1,2}'),
        trim(split_part(campaign:target_audience::string, ',', 1))
    ) as audience_age_segment,

    trim(split_part(campaign:target_audience::string, ',', 1))
        as audience_group,

    try_to_timestamp(campaign:start_date::string) as start_date,

    try_to_timestamp(campaign:end_date::string) as end_date,

    datediff(
        day,
        try_to_date(campaign:start_date::string),
        try_to_date(campaign:end_date::string)
    ) as campaign_duration_days,

    -- Currency-string fields: strip $ and thousands separators before casting
    try_to_number(
        regexp_replace(campaign:budget::string, '[$,]', ''),
        18, 2
    ) as budget,

    try_to_number(
        regexp_replace(campaign:total_cost::string, '[$,]', ''),
        18, 2
    ) as total_cost,

    try_to_number(
        regexp_replace(campaign:total_revenue::string, '[$,]', ''),
        18, 2
    ) as total_revenue,

    -- roi_calculation arrives as a plain numeric string (no currency symbol).
    -- NOTE: per doc, this is a source-provided figure only — the validated,
    -- attribution-based ROI is calculated in Gold (FACT_MarketingPerformance).
    try_to_number(campaign:roi_calculation::string, 18, 4)
        as roi_calculation_raw,

    try_to_date(campaign:last_modified_date::string)
        as last_modified_date,

    _loaded_at,
    _source_file,
    _batch_id

from campaign_flattened

qualify row_number() over (
    partition by campaign:campaign_id::string
    order by try_to_date(campaign:last_modified_date::string) desc
) = 1
