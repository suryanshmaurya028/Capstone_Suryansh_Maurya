{% snapshot snp_br_stores %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='store_id',
        strategy='timestamp',
        updated_at='_file_last_modified'
    )
}}

with stores as (

    select
        raw_data,
        _loaded_at,
        _source_file,
        _file_last_modified,
        _batch_id,
        value,

        row_number() over (
            partition by value:store_id::string
            order by _file_last_modified desc,
                     _loaded_at desc
        ) as rn

    from {{ ref('br_stores') }},
         lateral flatten(input => raw_data:stores_data)

)

select
    raw_data,
    _loaded_at,
    _source_file,
    _file_last_modified,
    _batch_id,
    value:store_id::string as store_id

from stores

where rn = 1

{% endsnapshot %}
