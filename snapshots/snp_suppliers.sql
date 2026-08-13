{% snapshot snp_suppliers %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='supplier_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

select *
from {{ ref('silver_suppliers') }}

{% endsnapshot %}
