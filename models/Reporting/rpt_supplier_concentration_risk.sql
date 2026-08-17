{{ config(materialized='view', schema='REPORTING') }}



with supplier_totals as (

    select

        s.supplier_id,
        s.supplier_name,
        s.credit_rating,
        s.is_active,

        sum(f.purchased_quantity) as total_purchased_quantity

    from {{ ref('fact_inventory') }} f
    inner join {{ ref('dim_supplier') }} s
        on f.supplier_key = s.supplier_key

    group by s.supplier_id, s.supplier_name, s.credit_rating, s.is_active

),

company_total as (

    select sum(total_purchased_quantity) as grand_total
    from supplier_totals

)

select

    st.supplier_id,
    st.supplier_name,
    st.credit_rating,
    st.is_active,
    st.total_purchased_quantity,

    round(
        case
            when ct.grand_total > 0
            then (st.total_purchased_quantity / ct.grand_total) * 100
            else null
        end,
        2
    ) as pct_of_total_supply,

    case
        when ct.grand_total > 0 and (st.total_purchased_quantity / ct.grand_total) * 100 >= 20
        then true
        else false
    end as high_concentration_risk_flag

from supplier_totals st
cross join company_total ct
