{{ config(materialized='view', schema='REPORTING') }}

select

    c.campaign_id,
    c.campaign_name,
    c.campaign_type,

    sum(f.new_customers_acquired) as total_new_customers_acquired,

    round(avg(f.repeat_purchase_rate), 2) as avg_repeat_purchase_rate

from {{ ref('fact_marketingperformance') }} f
inner join {{ ref('dim_marketingcampaign') }} c
    on f.campaign_key = c.campaign_key

group by c.campaign_id, c.campaign_name, c.campaign_type
