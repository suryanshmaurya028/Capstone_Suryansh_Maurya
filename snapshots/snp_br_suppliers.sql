{% snapshot snp_br_suppliers %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='supplier_id',
        strategy='timestamp',
        updated_at='_file_last_modified'
    )
}}

-- Step 1: Flatten and extract only lightweight columns to avoid memory strain
with flattened_ids as (

    select
        _loaded_at,
        _file_last_modified,
        value:supplier_id::string as supplier_id,
        _source_file,
        _batch_id

    from {{ ref('br_suppliers') }},
         lateral flatten(input => raw_data:suppliers_data)

),

-- Step 2: Deduplicate using the window function on lightweight fields
deduped_ids as (

    select 
        _source_file,
        _batch_id,
        supplier_id,
        row_number() over (
            partition by supplier_id
            order by _file_last_modified desc, _loaded_at desc
        ) as rn
    from flattened_ids

),

-- Step 3: Keep only the latest record for each supplier
latest_ids as (

    select * 
    from deduped_ids 
    where rn = 1

)

-- Step 4: Join back to the base table to retrieve raw_data for winning rows only
select
    b.raw_data,
    b._loaded_at,
    l._source_file,
    b._file_last_modified,
    l._batch_id,
    l.supplier_id

from latest_ids l
join {{ ref('br_suppliers') }} b 
    on l._source_file = b._source_file 
   and l._batch_id = b._batch_id

{% endsnapshot %}
