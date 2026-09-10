select
    "Date"::date as rated_at,
    "Name" as movie_title,
    "Year"::int as movie_year,
    "Letterboxd URI" as letterboxd_url,
    "Rating"::decimal(2,1) as rating
from {{ source('raw', 'letterboxd_ratings') }}