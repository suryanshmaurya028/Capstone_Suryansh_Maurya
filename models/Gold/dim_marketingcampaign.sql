{{ config(materialized='table', schema='GOLD') }}



select

    {{ dbt_utils.generate_surrogate_key(['campaign_id']) }} as campaign_key,

    campaign_id,
    campaign_name,
    campaign_type,
    channel,
    description,
    target_audience_raw,
    audience_age_segment,
    audience_group,
    start_date,
    end_date,
    campaign_duration_days as duration,
    budget,
    total_cost,
    total_revenue,
    roi_calculation_raw as roi,
    last_modified_date

from {{ ref('silver_campaigns') }}
