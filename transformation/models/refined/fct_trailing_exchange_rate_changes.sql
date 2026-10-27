WITH daily AS (
    SELECT
        calendar_date
        , quote_currency
        , quote_currency_name
        , exchange_rate
        , published_rate_date
        , last_refreshed_at
    FROM {{ ref('fct_daily_exchange_rates') }}
)

, anchor AS (
    SELECT
        max(published_rate_date) AS anchor_date
        , max(last_refreshed_at) AS last_refreshed_at
    FROM daily
)

-- one row per window; YTD = first date of the anchor year in data
, windows AS (
    SELECT
        '1D' AS window_name
        , 1 AS window_order
        , date_sub(anchor_date, INTERVAL 1 DAY) AS baseline_date
    FROM anchor
    UNION ALL
    SELECT
        '7D' AS window_name
        , 2 AS window_order
        , date_sub(anchor_date, INTERVAL 7 DAY) AS baseline_date
    FROM anchor
    UNION ALL
    SELECT
        '1M' AS window_name
        , 3 AS window_order
        , date_sub(anchor_date, INTERVAL 1 MONTH) AS baseline_date
    FROM anchor
    UNION ALL
    SELECT
        '3M' AS window_name
        , 4 AS window_order
        , date_sub(anchor_date, INTERVAL 3 MONTH) AS baseline_date
    FROM anchor
    UNION ALL
    SELECT
        'YTD' AS window_name
        , 5 AS window_order
        , min(daily.calendar_date) AS baseline_date
    FROM daily
    CROSS JOIN anchor
    WHERE
        extract(YEAR FROM daily.calendar_date)
        = extract(YEAR FROM anchor.anchor_date)
)

, anchor_rates AS (
    SELECT
        daily.quote_currency
        , daily.quote_currency_name
        , daily.exchange_rate AS anchor_rate
    FROM daily
    INNER JOIN anchor
        ON daily.calendar_date = anchor.anchor_date
)

-- grid: every currency x every window, baseline may be missing
, combined AS (
    SELECT
        windows.window_name
        , windows.window_order
        , windows.baseline_date
        , anchor_rates.quote_currency
        , anchor_rates.quote_currency_name
        , anchor_rates.anchor_rate
        , daily.exchange_rate AS baseline_rate
    FROM anchor_rates
    CROSS JOIN windows
    LEFT JOIN daily
        ON
            windows.baseline_date = daily.calendar_date
            AND anchor_rates.quote_currency = daily.quote_currency
)

SELECT
    {{ dbt_utils.generate_surrogate_key(
        ['combined.window_name', 'combined.quote_currency']
    ) }} AS id
    , combined.window_name
    , combined.window_order
    , anchor.anchor_date
    , combined.baseline_date
    , combined.quote_currency
    , combined.quote_currency_name
    , combined.baseline_rate
    , combined.anchor_rate
    , safe_divide(combined.anchor_rate, combined.baseline_rate) - 1
        AS rate_change_pct
    , safe_divide(combined.baseline_rate, combined.anchor_rate) - 1
        AS quote_value_change_pct
    , anchor.last_refreshed_at

FROM combined
CROSS JOIN anchor
