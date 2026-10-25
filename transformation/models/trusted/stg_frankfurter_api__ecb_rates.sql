with source as (
    select * from {{ source('frankfurter_api', 'ecb_rates') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['date', 'quote']) }} as id
    , cast(_dlt_load_id as string) as dlt_load_id
    , cast(date as date) as rate_date
    , cast(base as string) as base_currency
    , cast(quote as string) as quote_currency
    , cast(rate as numeric) as exchange_rate

from
    source