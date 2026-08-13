{% snapshot snp_products %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

select *
from {{ ref('silver_products') }}

{% endsnapshot %}
