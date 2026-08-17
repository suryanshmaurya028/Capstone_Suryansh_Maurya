{{ config(materialized='view', schema='REPORTING') }}

select

    supplier_id,
    supplier_name,
    supplier_type,

    on_time_delivery_rate,
    average_delay_days,

    case
        when on_time_delivery_rate >= 95 then 'Excellent'
        when on_time_delivery_rate >= 90 then 'Good'
        when on_time_delivery_rate >= 80 then 'Needs Improvement'
        else 'Poor'
    end as delivery_performance_tier,

    performance_issue_flag

from {{ ref('dim_supplier') }}
