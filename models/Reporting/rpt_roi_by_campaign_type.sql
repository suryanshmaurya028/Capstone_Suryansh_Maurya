{{ config(materialized='view', schema='REPORTING') }}


with sales_per_campaign as (

    select
        campaign_key,
        sum(total_sales_influenced) as total_sales_influenced
    from {{ ref('fact_marketingperformance') }}
    group by campaign_key

)

select

    c.campaign_type,

    sum(spc.total_sales_influenced) as total_sales_influenced,
    sum(c.total_cost) as total_campaign_cost,

    round(
        case
            when sum(c.total_cost) > 0
            then (sum(spc.total_sales_influenced) - sum(c.total_cost)) / sum(c.total_cost) * 100
            else null
        end,
        2
    ) as roi_percentage

from sales_per_campaign spc
inner join {{ ref('dim_marketingcampaign') }} c
    on spc.campaign_key = c.campaign_key

group by c.campaign_type
