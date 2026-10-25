with source as (
    select * from {{ source('frankfurter_api', '_dlt_loads') }}
)

select
    cast(load_id as string) AS id
    , cast(inserted_at as timestamp) as inserted_at

from
    source
where
    1=1
    and schema_name = '{{ var("frankfurter_dlt_schema") }}'