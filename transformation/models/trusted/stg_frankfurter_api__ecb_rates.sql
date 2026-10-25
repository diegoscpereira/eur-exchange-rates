WITH source AS (
    SELECT * FROM {{ source('frankfurter_api', 'ecb_rates') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['date', 'quote']) }} AS id
    , cast(_dlt_load_id AS string) AS dlt_load_id
    , cast(date AS date) AS rate_date
    , cast(base AS string) AS base_currency
    , cast(quote AS string) AS quote_currency
    , cast(rate AS numeric) AS exchange_rate

FROM
    source
