with clean as (
    select
        movieId as movielens_movie_id,
        title,
        genres,
        case
            when regexp_extract(trim(title), '\((\d{4})\)$', 1) != ''
            then regexp_extract(trim(title), '\((\d{4})\)$', 1)::int
        else null
        end as movie_year,
        trim(regexp_replace(trim(title), '\(\d{4}\)$', '')) as title_no_year
    from {{ source('raw', 'movielens_movies') }}
)
select
    movielens_movie_id,
    movie_year,
    genres,
    case 
        when title_no_year ilike '%, the' then 'The ' || trim(regexp_replace(title_no_year, ', [Tt]he$', ''))
        when title_no_year ilike '%, a' then 'A ' || trim(regexp_replace(title_no_year, ', [Aa]$', ''))
        when title_no_year ilike '%, an' then 'An ' || trim(regexp_replace(title_no_year, ', [Aa]n$', ''))
        else title_no_year
    end as movie_title
from clean