WITH spine AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('rates_start_date') ~ "' as date)",
        end_date="date_add(current_date(), interval 1 day)"
    ) }}
)

, dates AS (
    SELECT cast(date_day AS date) AS calendar_date
    FROM
        spine
)

SELECT
    calendar_date
    , cast(format_date('%u', calendar_date) AS int64)
        AS iso_day_of_week
    , format_date('%A', calendar_date) AS day_name
    , cast(format_date('%u', calendar_date) AS int64) >= 6
        AS is_weekend
    , date_trunc(calendar_date, ISOWEEK) AS week_start
    , extract(ISOWEEK FROM calendar_date) AS iso_week
    , extract(ISOYEAR FROM calendar_date) AS iso_year
    , date_trunc(calendar_date, MONTH) AS month_start
    , extract(MONTH FROM calendar_date) AS month_number
    , format_date('%B', calendar_date) AS month_name
    , extract(QUARTER FROM calendar_date) AS quarter_number
    , extract(YEAR FROM calendar_date) AS year_number

FROM
    dates
