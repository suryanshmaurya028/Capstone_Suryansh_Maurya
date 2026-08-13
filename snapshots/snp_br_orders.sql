{% snapshot snp_br_orders %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='_file_last_modified'
    )
}}

-- Step 1: Flatten and extract only lightweight columns to protect memory
with flattened_ids as (

    select
        _loaded_at,
        _file_last_modified,
        value:order_id::string as order_id,
        _source_file,
        _batch_id

    from {{ ref('br_orders') }},
         lateral flatten(input => raw_data:orders_data)

),

-- Step 2: Run the window function on small string/date fields instead of heavy JSON fields
deduped_ids as (

    select 
        _source_file,
        _batch_id,
        order_id,
        row_number() over (
            partition by order_id
            order by _file_last_modified desc, _loaded_at desc
        ) as rn
    from flattened_ids

),

-- Step 3: Keep only the single latest file reference per order_id
latest_ids as (

    select * 
    from deduped_ids 
    where rn = 1

)

-- Step 4: Join back to the base table to retrieve raw_data only for the matching records
select
    b.raw_data,
    b._loaded_at,
    l._source_file,
    b._file_last_modified,
    l._batch_id,
    l.order_id

from latest_ids l
join {{ ref('br_orders') }} b 
    on l._source_file = b._source_file 
   and l._batch_id = b._batch_id

{% endsnapshot %}
