WITH calendar AS (
    SELECT calendar_date
    FROM {{ ref('dim_calendar') }}
)

, rates AS (
    SELECT
        rate_date
        , base_currency
        , quote_currency
        , exchange_rate
    FROM {{ ref('stg_frankfurter_api__ecb_rates') }}
    WHERE quote_currency != 'EUR'
)

, currencies AS (
    SELECT DISTINCT quote_currency
    FROM rates
)

-- 1. grid: one row per day per currency
, grid AS (
    SELECT
        calendar.calendar_date
        , currencies.quote_currency
    FROM calendar
    CROSS JOIN currencies
)

-- 2. published rates on business days, null otherwise
, joined AS (
    SELECT
        grid.calendar_date
        , grid.quote_currency
        , rates.rate_date
        , rates.base_currency
        , rates.exchange_rate
    FROM grid
    LEFT JOIN rates
        ON
            grid.calendar_date = rates.rate_date
            AND grid.quote_currency = rates.quote_currency
)

-- 3. carry the last published rate forward
, filled AS (
    SELECT
        calendar_date
        , quote_currency
        , last_value(rate_date IGNORE NULLS) OVER w AS rate_date
        , last_value(base_currency IGNORE NULLS) OVER w
            AS base_currency
        , last_value(exchange_rate IGNORE NULLS) OVER w
            AS exchange_rate
    FROM joined
    WINDOW w AS (
        PARTITION BY quote_currency
        ORDER BY calendar_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
)

, last_refresh AS (
    SELECT max(inserted_at) AS last_refreshed_at
    FROM {{ ref('stg_frankfurter_api__dlt_loads') }}
)

-- 4. flags + pipeline metadata
SELECT
    {{ dbt_utils.generate_surrogate_key(
        ['filled.calendar_date', 'filled.quote_currency']
    ) }} AS id
    , filled.calendar_date
    , filled.base_currency
    , filled.quote_currency
    , currency_lookup.currency_name AS quote_currency_name
    , filled.exchange_rate
    , filled.rate_date AS published_rate_date
    , filled.calendar_date != filled.rate_date AS is_carried_forward
    , date_diff(filled.calendar_date, filled.rate_date, DAY)
        AS days_since_published
    , last_refresh.last_refreshed_at

FROM filled
CROSS JOIN last_refresh
LEFT JOIN {{ ref('stg_frankfurter_api__currencies') }} AS currency_lookup
    ON filled.quote_currency = currency_lookup.currency_iso_code
WHERE
    1 = 1
    AND filled.rate_date IS NOT null
