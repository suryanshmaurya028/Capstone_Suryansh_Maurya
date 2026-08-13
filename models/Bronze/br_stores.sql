{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='_source_file',
    schema='BRONZE'
  )
}}

select
    raw_data,
    file_date,
    current_timestamp()           as _loaded_at,
    metadata$filename              as _source_file,
    metadata$file_last_modified    as _file_last_modified,
    '{{ invocation_id }}'          as _batch_id
from {{ source('bronze', 'ext_stores') }}

{% if is_incremental() %}
where metadata$file_last_modified > (select max(_file_last_modified) from {{ this }})
{% endif %}
