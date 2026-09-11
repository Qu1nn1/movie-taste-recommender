with my_rated_movies as (
    select
        m.movielens_movie_id,
        from {{ ref('stg_letterboxd_ratings') }} l
        join {{ ref('stg_movielens_movies') }} m
        on lower(l.movie_title) = lower(m.movie_title)
        and l.movie_year = m.movie_year
),

my_avg as (
    select
    avg(rating) as my_avg_rating
    from {{ ref('stg_letterboxd_ratings') }}
),

their_rated_movies as (
    select
        r.movielens_movie_id,
        r.rating,
        c.correlation,
        c.their_avg_rating
    from {{ ref('stg_movielens_ratings') }} r
    join {{ ref('int_user_correlations') }} c
    on r.movielens_user_id = c.movielens_user_id
    where r.movielens_movie_id not in (select movielens_movie_id from my_rated_movies)
),

offset_predictions as (
    select
        movielens_movie_id,
        sum(correlation * (rating - their_avg_rating)) / sum(correlation) as centered_offset,
        count(*) as num_predictions
    from their_rated_movies
    where correlation > 0
    group by movielens_movie_id
)

select
    m.movie_title,
    m.movie_year,
    m.genres,
    ma.my_avg_rating + op.centered_offset as predicted_rating,
    op.num_predictions
from offset_predictions op
cross join my_avg ma
join {{ ref('stg_movielens_movies') }} m
on op.movielens_movie_id = m.movielens_movie_id
where op.num_predictions >= 10
order by predicted_rating desc
limit 100