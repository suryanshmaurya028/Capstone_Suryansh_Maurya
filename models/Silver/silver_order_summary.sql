{{ config(materialized='table') }}



with order_lines as (

    select
        order_id,
        customer_id,
        employee_id,
        store_id,
        campaign_id,
        order_status,
        order_source,
        payment_method,
        shipping_method,
        order_date,
        order_dt,
        order_week,
        order_month,
        order_quarter,
        order_year,
        order_time_bucket,
        delivery_status,
        processing_days,
        shipping_days,
        order_discount,
        shipping_cost,
        tax_amount,
        product_id,
        quantity,
        unit_price,
        cost_price,
        item_discount

    from {{ ref('silver_orders') }}

),

order_grain as (

    select

        order_id,

        -- these are the same across all lines of an order, so max() just
        -- picks the single value without needing a separate join
        max(customer_id) as customer_id,
        max(employee_id) as employee_id,
        max(store_id) as store_id,
        max(campaign_id) as campaign_id,
        max(order_status) as order_status,
        max(order_source) as order_source,
        max(payment_method) as payment_method,
        max(shipping_method) as shipping_method,
        max(order_date) as order_date,
        max(order_dt) as order_dt,
        max(order_week) as order_week,
        max(order_month) as order_month,
        max(order_quarter) as order_quarter,
        max(order_year) as order_year,
        max(order_time_bucket) as order_time_bucket,
        max(delivery_status) as delivery_status,
        max(processing_days) as processing_days,
        max(shipping_days) as shipping_days,
        max(order_discount) as order_discount,
        max(shipping_cost) as shipping_cost,
        max(tax_amount) as tax_amount,

        -- Sample Logic from doc: aggregate order items to order grain
        count(distinct product_id) as total_items,
        sum(quantity) as total_quantity,
        sum(quantity * unit_price) as total_amount,
        sum(quantity * cost_price) as total_cost,
        sum(item_discount) as total_discount,

        -- line_revenue: per-item discount applied multiplicatively (confirmed
        -- as a percentage against real data, hence /100)
        sum(quantity * unit_price * (1 - (item_discount / 100))) as line_revenue,

        sum(quantity * cost_price) as line_cost

    from order_lines
    group by order_id

)

select

    order_id,
    customer_id,
    employee_id,
    store_id,
    campaign_id,
    order_status,
    order_source,
    payment_method,
    shipping_method,
    order_date,
    order_dt,
    order_week,
    order_month,
    order_quarter,
    order_year,
    order_time_bucket,
    delivery_status,
    processing_days,
    shipping_days,

    total_items,
    total_quantity,
    total_amount,
    total_cost,
    total_discount,

    
    -- profit_amount = (line_revenue * (1 - order.discount_amount)) - line_cost - shipping_cost - tax_amount
    round(
        (line_revenue * (1 - (order_discount / 100)))
        - line_cost
        - shipping_cost
        - tax_amount,
        2
    ) as profit_amount,

    round(
        case
            when line_revenue > 0
            then
                (
                    (line_revenue * (1 - (order_discount / 100)))
                    - line_cost
                    - shipping_cost
                    - tax_amount
                )
                / line_revenue * 100
        end,
        2
    ) as profit_margin_percentage

from order_grain
