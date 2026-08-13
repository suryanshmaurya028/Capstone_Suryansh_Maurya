{% snapshot snp_stores %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='store_id',
        strategy='timestamp',
        updated_at='last_modified_date'
    )
}}

select *
from {{ ref('silver_stores') }}

{% endsnapshot %}
