{{ config(materialized='view', schema='REPORTING') }}



with product_turnover as (

    select

        p.product_id,
        p.product_name,
        p.category,

        avg(f.stock_turnover_ratio) as avg_turnover_ratio

    from {{ ref('fact_inventory') }} f
    inner join {{ ref('dim_product') }} p
        on f.product_key = p.product_key

    group by p.product_id, p.product_name, p.category

),

ranked as (

    select

        *,

        ntile(3) over (order by avg_turnover_ratio) as turnover_tercile

    from product_turnover
    where avg_turnover_ratio is not null

)

select

    product_id,
    product_name,
    category,
    round(avg_turnover_ratio, 4) as avg_turnover_ratio,

    case
        when turnover_tercile = 3 then 'Fast-moving'
        when turnover_tercile = 2 then 'Moderate'
        when turnover_tercile = 1 then 'Slow-moving'
    end as movement_classification

from ranked
