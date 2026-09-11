with avg_movie_ratings as (
    select
        avg(rating) as avg_movie_rating,
        movielens_movie_id
    from {{ ref('stg_movielens_ratings') }}
    group by movielens_movie_id
),

my_residuals as (
    select 
        m.movielens_movie_id,
        l.rating - amr.avg_movie_rating as my_residual
    from {{ ref('stg_letterboxd_ratings') }} l
    left join {{ ref('stg_movielens_movies') }} m
    on lower(l.movie_title) = lower(m.movie_title)
    and l.movie_year = m.movie_year
    join avg_movie_ratings amr
    on m.movielens_movie_id = amr.movielens_movie_id
),

shared_residuals as (
    select 
        r.movielens_user_id,
        r.movielens_movie_id,
        r.rating - amr.avg_movie_rating as their_residual,
        mr.my_residual
    from {{ ref('stg_movielens_ratings') }} r
    join my_residuals mr
    on r.movielens_movie_id = mr.movielens_movie_id
    join avg_movie_ratings amr
    on mr.movielens_movie_id = amr.movielens_movie_id
)

select
    movielens_user_id,
    corr(their_residual, my_residual) as residual_correlation,
    count(*) as shared_movie_count
from shared_residuals
group by movielens_user_id
having count(*) >= 50
and not isnan(residual_correlation)