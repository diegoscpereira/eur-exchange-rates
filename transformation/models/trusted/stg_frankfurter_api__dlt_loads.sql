WITH source AS (
    SELECT * FROM {{ source('frankfurter_api', '_dlt_loads') }}
)

SELECT
    cast(load_id AS string) AS id
    , cast(inserted_at AS timestamp) AS inserted_at

FROM
    source
WHERE
    1 = 1
    AND schema_name = '{{ var("frankfurter_dlt_schema") }}'
