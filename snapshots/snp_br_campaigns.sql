{% snapshot snp_br_campaigns %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='campaign_id',
        strategy='timestamp',
        updated_at='_file_last_modified'
    )
}}

-- Step 1: Flatten and extract only lightweight columns to avoid memory strain
with flattened_ids as (

    select
        _loaded_at,
        _file_last_modified,
        value:campaign_id::string as campaign_id,
        _source_file,
        _batch_id

    from {{ ref('br_campaigns') }},
         lateral flatten(input => raw_data:campaigns_data)

),

-- Step 2: Deduplicate using the window function on lightweight fields
deduped_ids as (

    select 
        _source_file,
        _batch_id,
        campaign_id,
        row_number() over (
            partition by campaign_id
            order by _file_last_modified desc, _loaded_at desc
        ) as rn
    from flattened_ids

),

-- Step 3: Keep only the latest record for each campaign
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
    l.campaign_id

from latest_ids l
join {{ ref('br_campaigns') }} b 
    on l._source_file = b._source_file 
   and l._batch_id = b._batch_id

{% endsnapshot %}
