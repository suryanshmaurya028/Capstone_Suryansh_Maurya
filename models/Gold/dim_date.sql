{{ config(materialized='table', schema='GOLD') }}



with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-04-01' as date)",
        end_date="cast('2024-09-28' as date)"
    ) }}

),

us_holidays_2024 as (

    select column1::date as holiday_date, column2 as holiday_name
    from values
        ('2024-01-01', 'New Years Day'),
        ('2024-01-15', 'Martin Luther King Jr Day'),
        ('2024-02-19', 'Presidents Day'),
        ('2024-05-27', 'Memorial Day'),
        ('2024-06-19', 'Juneteenth'),
        ('2024-07-04', 'Independence Day'),
        ('2024-09-02', 'Labor Day'),
        ('2024-10-14', 'Columbus Day'),
        ('2024-11-11', 'Veterans Day'),
        ('2024-11-28', 'Thanksgiving Day'),
        ('2024-12-25', 'Christmas Day')

)

select

    to_number(to_char(d.date_day, 'YYYYMMDD')) as date_key,

    d.date_day as full_date,

    year(d.date_day) as year,

    quarter(d.date_day) as quarter,

    month(d.date_day) as month,

    monthname(d.date_day) as month_name,

    week(d.date_day) as week,

    dayofweek(d.date_day) as day_of_week_number,

    dayname(d.date_day) as day_of_week,

    case
        when dayofweek(d.date_day) in (0, 6) then true
        else false
    end as is_weekend,

    case
        when h.holiday_date is not null then true
        else false
    end as is_holiday,

    h.holiday_name,

    case
        when month(d.date_day) in (12, 1, 2) then 'Winter'
        when month(d.date_day) in (3, 4, 5) then 'Spring'
        when month(d.date_day) in (6, 7, 8) then 'Summer'
        when month(d.date_day) in (9, 10, 11) then 'Fall'
    end as season

from date_spine d
left join us_holidays_2024 h
    on d.date_day = h.holiday_date
