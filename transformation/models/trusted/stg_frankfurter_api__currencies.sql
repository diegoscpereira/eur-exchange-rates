WITH source AS (
    SELECT * FROM {{ source('frankfurter_api', 'currencies') }}
)

SELECT
    cast(_dlt_load_id AS string) AS dlt_load_id
    , cast(iso_code AS string) AS currency_iso_code
    , cast(name AS string) AS currency_name
    , cast(symbol AS string) AS currency_symbol
    , cast(start_date AS date) AS first_published_date
    , cast(end_date AS date) AS last_published_date

FROM
    source
