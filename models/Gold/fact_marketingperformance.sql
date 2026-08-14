{{ config(materialized='table', schema='GOLD') }}

-- ============================================================================
-- GRAIN: one row per campaign per date, declared explicitly per doc.
--
-- ATTRIBUTION RULE (required by doc — without this, metrics aren't
-- reproducible): an order is attributed to a campaign if the order's
-- campaign_id directly matches the campaign, AND the order's date falls
-- within the campaign's start_date/end_date window. Each order carries at
-- most one campaign_id in the source data, so this is a direct-match
-- attribution rather than a last-touch model (there is nothing to break a
-- tie between multiple touches, since only one campaign_id exists per order).
--
-- "New customer" = a customer whose order falls in the campaign window AND
-- who had NO orders anywhere (any campaign or none) before the campaign's
-- start_date, per the doc's literal formula.
-- ============================================================================

with campaigns as (

    select
        campaign_key,
        campaign_id,
        start_date::date as start_date,
        end_date::date as end_date,
        total_cost
    from {{ ref('dim_marketingcampaign') }}

),

-- One row per campaign per date within its active window
campaign_date_spine as (

    select
        c.campaign_key,
        c.campaign_id,
        c.total_cost,
        d.date_key,
        d.full_date

    from campaigns c
    inner join {{ ref('dim_date') }} d
        on d.full_date between c.start_date and c.end_date

),

-- All orders, used both for attribution and for determining each
-- customer's true first-ever purchase date (needed for "new customer" logic)
all_orders as (

    select
        order_id,
        customer_id,
        campaign_id,
        order_dt,
        total_amount
    from {{ ref('silver_order_summary') }}

),

customer_first_order as (

    select
        customer_id,
        min(order_dt) as first_order_date
    from all_orders
    group by customer_id

),

-- Orders attributed to a campaign: direct campaign_id match, within window
attributed_orders as (

    select
        o.order_id,
        o.customer_id,
        o.order_dt,
        o.total_amount,
        o.campaign_id,
        cfo.first_order_date

    from all_orders o
    inner join customer_first_order cfo
        on o.customer_id = cfo.customer_id
    where o.campaign_id is not null

),

daily_metrics as (

    select

        cds.campaign_key,
        cds.campaign_id,
        cds.date_key,
        cds.full_date,
        cds.total_cost,

        -- Total Sales Influenced by Campaign
        coalesce(sum(ao.total_amount), 0) as total_sales_influenced,

        -- New Customers Acquired: order falls in window, and customer had
        -- zero orders anywhere before this campaign's start_date
        count(distinct case
            when ao.first_order_date >= cds_start.start_date
            then ao.customer_id
        end) as new_customers_acquired,

        -- Needed for Repeat Purchase Rate: customers on this date whose
        -- order IS their first-ever order vs customers whose order is NOT
        count(distinct case
            when ao.order_dt = ao.first_order_date
            then ao.customer_id
        end) as first_purchase_customers,

        count(distinct case
            when ao.order_dt > ao.first_order_date
            then ao.customer_id
        end) as repeat_purchase_customers

    from campaign_date_spine cds

    left join attributed_orders ao
        on cds.campaign_id = ao.campaign_id
       and cds.full_date = ao.order_dt

    left join campaigns cds_start
        on cds.campaign_id = cds_start.campaign_id

    group by
        cds.campaign_key,
        cds.campaign_id,
        cds.date_key,
        cds.full_date,
        cds.total_cost

)

select

    row_number() over (order by campaign_key, date_key) as marketing_performance_key,

    campaign_key,
    date_key,

    total_sales_influenced,
    new_customers_acquired,

    -- Repeat Purchase Rate, per doc's exact formula
    round(
        100.0 * repeat_purchase_customers
        / nullif(first_purchase_customers, 0),
        2
    ) as repeat_purchase_rate,

    -- ROI, per doc's exact formula. NOTE: total_cost is the campaign's
    -- overall cost (not split daily), so this reflects that day's sales
    -- influenced against the full campaign cost — read cumulative ROI
    -- across the campaign window for a stable, complete picture rather
    -- than any single day in isolation.
    round(
        case
            when total_cost > 0
            then (total_sales_influenced - total_cost) / total_cost * 100
            else null
        end,
        2
    ) as roi

from daily_metrics
