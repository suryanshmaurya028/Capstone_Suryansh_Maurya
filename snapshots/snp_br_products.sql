{% snapshot snp_br_products %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='_file_last_modified'
    )
}}

-- Step 1: Flatten and extract ONLY the identifiers needed for deduplication
with flattened_ids as (

    select
        _loaded_at,
        _file_last_modified,
        value:product_id::string as product_id,
        -- Keep a reference to the parent row to pull data back later
        _source_file,
        _batch_id

    from {{ ref('br_products') }},
         lateral flatten(input => raw_data:products_data)

),

-- Step 2: Run the window function on a highly lightweight dataset (no heavy JSON column)
deduped_ids as (

    select 
        _source_file,
        _batch_id,
        product_id,
        row_number() over (
            partition by product_id
            order by _file_last_modified desc, _loaded_at desc
        ) as rn
    from flattened_ids

),

-- Step 3: Filter for the latest records first
latest_ids as (

    select * 
    from deduped_ids 
    where rn = 1

)

-- Step 4: Join back to the base table to get the full raw_data only for the records we actually need
select
    b.raw_data,
    b._loaded_at,
    l._source_file,
    b._file_last_modified,
    l._batch_id,
    l.product_id

from latest_ids l
join {{ ref('br_products') }} b 
    on l._source_file = b._source_file 
   and l._batch_id = b._batch_id

{% endsnapshot %}
