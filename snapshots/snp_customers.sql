{% snapshot snp_customers %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

select *
from {{ ref('silver_customers') }}

{% endsnapshot %}
