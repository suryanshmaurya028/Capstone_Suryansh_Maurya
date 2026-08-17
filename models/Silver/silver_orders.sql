{{ config(materialized='table', schema='SILVER') }}

with src_order as (

    select * from {{ ref('snp_order') }} where dbt_valid_to is null

),

order_items as (

    select
        o.*,
        item.value as item

    from src_order o,
    lateral flatten(input => o.order_items) item

),

base_orders as (

    select

        order_id,
        customer_id,
        employee_id,
        store_id,
        item:product_id::string as product_id,
        item:quantity::number as quantity,
        item:unit_price::number(18,2) as unit_price,
        item:cost_price::number(18,2) as cost_price,
        item:discount_amount::number(18,2) as item_discount,
        discount_amount as order_discount,
        shipping_cost,
        tax_amount,
        total_amount,
        campaign_id,
        payment_method,
        shipping_method,
        order_status,
        order_source,
        created_at,
        order_date,
        shipping_date,
        delivery_date,
        estimated_delivery_date,
        billing_address,
        shipping_address,
        last_modified_date,
        _loaded_at,
        _source_file

    from order_items

),

final_orders as (

    select

        order_id,
        customer_id,
        employee_id,
        store_id,
        product_id,
        quantity,
        unit_price,
        cost_price,
        item_discount,
        order_discount,
        shipping_cost,
        tax_amount,
        total_amount,

        upper(trim(campaign_id)) as campaign_id,
        lower(trim(order_source)) as order_source,
        initcap(trim(payment_method)) as payment_method,
        initcap(trim(shipping_method)) as shipping_method,
        initcap(trim(order_status)) as order_status,

        to_timestamp_ntz(created_at) as created_at,
        to_timestamp_ntz(order_date) as order_date,
        to_timestamp_ntz(shipping_date) as shipping_date,
        to_timestamp_ntz(delivery_date) as delivery_date,
        to_timestamp_ntz(estimated_delivery_date) as estimated_delivery_date,
        to_date(order_date) as order_dt,

        date_part(hour, to_timestamp_ntz(order_date)) as order_hour,

        case
            when date_part(hour, to_timestamp_ntz(order_date)) between 5 and 11 then 'Morning'
            when date_part(hour, to_timestamp_ntz(order_date)) between 12 and 16 then 'Afternoon'
            when date_part(hour, to_timestamp_ntz(order_date)) between 17 and 21 then 'Evening'
            else 'Night'
        end as order_time_bucket,

        week(to_date(order_date)) as order_week,
        month(to_date(order_date)) as order_month,
        quarter(to_date(order_date)) as order_quarter,
        year(to_date(order_date)) as order_year,

        quantity * unit_price as line_revenue,
        quantity * cost_price as line_cost,

        round((quantity * unit_price) * (1 - (item_discount / 100)), 2) as net_line_revenue,

        round(
            ((quantity * unit_price) * (1 - (item_discount / 100))) - (quantity * cost_price),
            2
        ) as gross_profit,

        round(
            case
                when quantity * unit_price > 0
                then
                    (((quantity * unit_price) * (1 - (item_discount / 100))) - (quantity * cost_price))
                    / (quantity * unit_price) * 100
            end,
            2
        ) as profit_margin_percentage,

        datediff(day, to_date(order_date), to_date(shipping_date)) as processing_days,
        datediff(day, to_date(shipping_date), to_date(delivery_date)) as shipping_days,

        case
            when delivery_date is not null and to_date(delivery_date) <= to_date(estimated_delivery_date) then 'On Time'
            when delivery_date is not null and to_date(delivery_date) > to_date(estimated_delivery_date) then 'Delayed'
            when delivery_date is null and current_date() > to_date(estimated_delivery_date) then 'Potentially Delayed'
            else 'In Transit'
        end as delivery_status,

        initcap(trim(billing_address:street::string)) as billing_street,
        initcap(trim(billing_address:city::string)) as billing_city,
        upper(trim(billing_address:state::string)) as billing_state,
        billing_address:zip_code::string as billing_zip_code,

        initcap(trim(shipping_address:street::string)) as shipping_street,
        initcap(trim(shipping_address:city::string)) as shipping_city,
        upper(trim(shipping_address:state::string)) as shipping_state,
        shipping_address:zip_code::string as shipping_zip_code,

        last_modified_date,

        _loaded_at,
        _source_file

    from base_orders

)

select *
from final_orders

qualify row_number() over (
    partition by order_id, product_id
    order by last_modified_date desc, _loaded_at desc
) = 1
