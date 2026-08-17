{{ config(materialized='view', schema='REPORTING') }}

select

    c.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.channel,
    c.start_date,
    c.end_date,
    c.budget,
    c.total_cost,

    sum(f.total_sales_influenced) as total_sales_influenced,

    round(
        case
            when c.total_cost > 0
            then (sum(f.total_sales_influenced) - c.total_cost) / c.total_cost * 100
            else null
        end,
        2
    ) as roi_percentage

from {{ ref('fact_marketingperformance') }} f
inner join {{ ref('dim_marketingcampaign') }} c
    on f.campaign_key = c.campaign_key

group by
    c.campaign_id, c.campaign_name, c.campaign_type, c.channel,
    c.start_date, c.end_date, c.budget, c.total_cost
