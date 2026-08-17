{% macro create_external_table(table_name, folder_path, schema_name='EXTERNAL') %}
{% set sql %}
CREATE OR REPLACE EXTERNAL TABLE
CT_SURYANSH_MAURYA_DB.{{ schema_name }}.{{ table_name }}
(
    raw_data VARIANT AS (VALUE),
    file_date TIMESTAMP AS (
        TO_TIMESTAMP_NTZ(
            REGEXP_SUBSTR(
                METADATA$FILENAME,
                '[0-9]{4}-[0-9]{2}-[0-9]{2}'
            )
        )
    )
)
WITH LOCATION = @CT_SURYANSH_MAURYA_DB.BRONZE.ADLS_STAGE/Capstone_Project_Data/{{ folder_path }}
AUTO_REFRESH = FALSE
FILE_FORMAT = (TYPE = JSON);
{% endset %}
{% do run_query(sql) %}
{% endmacro %}