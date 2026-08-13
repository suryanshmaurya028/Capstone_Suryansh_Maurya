{{ config(materialized='table') }}

with orders_flattened as (

    select

        value as order_record,

        _loaded_at,

        _source_file,

        _batch_id

    from {{ ref('snp_br_orders') }},
         lateral flatten(input => raw_data:orders_data)

),

order_items as (

    select

        o.order_record,

        item.value as item,

        o._loaded_at,

        o._source_file,

        o._batch_id

    from orders_flattened o,

    lateral flatten(
        input => o.order_record:order_items
    ) item

),

base_orders as (

    select

        order_record:order_id::string as order_id,

        order_record:customer_id::string as customer_id,

        order_record:employee_id::string as employee_id,

        order_record:store_id::string as store_id,

        item:product_id::string as product_id,

        item:quantity::number as quantity,

        item:unit_price::number(18,2) as unit_price,

        item:cost_price::number(18,2) as cost_price,

        -- NOTE: confirmed against real data that discount_amount is a
        -- PERCENTAGE (e.g. 7.2 = 7.2%), not a fraction. Division by 100
        -- below is correct.
        item:discount_amount::number(18,2) as item_discount,

        order_record:discount_amount::number(18,2)
            as order_discount,

        order_record:shipping_cost::number(18,2)
            as shipping_cost,

        order_record:tax_amount::number(18,2)
            as tax_amount,

        order_record:total_amount::number(18,2)
            as total_amount,

        order_record:campaign_id::string
            as campaign_id,

        order_record:payment_method::string
            as payment_method,

        order_record:shipping_method::string
            as shipping_method,

        order_record:order_status::string
            as order_status,

        order_record:order_source::string
            as order_source,

        order_record:created_at::string
            as created_at,

        order_record:order_date::string
            as order_date,

        order_record:shipping_date::string
            as shipping_date,

        order_record:delivery_date::string
            as delivery_date,

        order_record:estimated_delivery_date::string
            as estimated_delivery_date,

        order_record:billing_address
            as billing_address,

        order_record:shipping_address
            as shipping_address,

        order_record:last_modified_date::string
            as last_modified_date,

        _loaded_at,

        _source_file,

        _batch_id

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

        upper(trim(campaign_id))
            as campaign_id,

        lower(trim(order_source))
            as order_source,

        initcap(trim(payment_method))
            as payment_method,

        initcap(trim(shipping_method))
            as shipping_method,

        initcap(trim(order_status))
            as order_status,

        to_timestamp_ntz(created_at)
            as created_at,

        to_timestamp_ntz(order_date)
            as order_date,

        to_timestamp_ntz(shipping_date)
            as shipping_date,

        to_timestamp_ntz(delivery_date)
            as delivery_date,

        to_timestamp_ntz(estimated_delivery_date)
            as estimated_delivery_date,

        to_date(order_date)
            as order_dt,

        date_part(
            hour,
            to_timestamp_ntz(order_date)
        ) as order_hour,

        case

            when date_part(hour,to_timestamp_ntz(order_date))
                between 5 and 11
            then 'Morning'

            when date_part(hour,to_timestamp_ntz(order_date))
                between 12 and 16
            then 'Afternoon'

            when date_part(hour,to_timestamp_ntz(order_date))
                between 17 and 21
            then 'Evening'

            else 'Night'

        end as order_time_bucket,

        week(to_date(order_date))
            as order_week,

        month(to_date(order_date))
            as order_month,

        quarter(to_date(order_date))
            as order_quarter,

        year(to_date(order_date))
            as order_year,

        quantity * unit_price
            as line_revenue,

        quantity * cost_price
            as line_cost,

        round(
            (quantity * unit_price) * (1 - (item_discount / 100)),
            2
        ) as net_line_revenue,

        round(
            (
                (quantity * unit_price) * (1 - (item_discount / 100))
            )
            - (quantity * cost_price),
            2
        ) as gross_profit,

        round(
            case
                when quantity * unit_price > 0
                then
                    (
                        (
                            (quantity * unit_price) * (1 - (item_discount / 100))
                        )
                        - (quantity * cost_price)
                    )
                    / (quantity * unit_price) * 100
            end,
            2
        ) as profit_margin_percentage,

        datediff(
            day,
            to_date(order_date),
            to_date(shipping_date)
        ) as processing_days,

        datediff(
            day,
            to_date(shipping_date),
            to_date(delivery_date)
        ) as shipping_days,

        case

            when delivery_date is not null
             and to_date(delivery_date)
                 <= to_date(estimated_delivery_date)
            then 'On Time'

            when delivery_date is not null
             and to_date(delivery_date)
                 > to_date(estimated_delivery_date)
            then 'Delayed'

            when delivery_date is null
             and current_date()
                 > to_date(estimated_delivery_date)
            then 'Potentially Delayed'

            else 'In Transit'

        end as delivery_status,

        initcap(trim(billing_address:street::string))
            as billing_street,

        initcap(trim(billing_address:city::string))
            as billing_city,

        upper(trim(billing_address:state::string))
            as billing_state,

        billing_address:zip_code::string
            as billing_zip_code,

        initcap(trim(shipping_address:street::string))
            as shipping_street,

        initcap(trim(shipping_address:city::string))
            as shipping_city,

        upper(trim(shipping_address:state::string))
            as shipping_state,

        shipping_address:zip_code::string
            as shipping_zip_code,

        try_to_date(last_modified_date)
            as last_modified_date,

        _loaded_at,

        _source_file,

        _batch_id

    from base_orders

)

select *

from final_orders

qualify row_number() over (

    partition by
        order_id,
        product_id

    order by
        last_modified_date desc,
        _loaded_at desc

) = 1
