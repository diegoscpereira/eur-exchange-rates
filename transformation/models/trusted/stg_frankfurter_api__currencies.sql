with source as (
    select * from {{ source('frankfurter_api', 'currencies') }}
)

select
    cast(_dlt_load_id as string) as dlt_load_id
    , cast(iso_code as string) as currency_iso_code
    , cast(name as string) as currency_name
    , cast(symbol as string) as currency_symbol
    , cast(start_date as date) as first_published_date
    , cast(end_date as date) as last_published_date

from
    source