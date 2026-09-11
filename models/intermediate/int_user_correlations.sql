with my_ratings as (
    select 
        m.movielens_movie_id,
        l.rating as my_rating
    from {{ ref('stg_letterboxd_ratings') }} l
    left join {{ ref('stg_movielens_movies') }} m
    on lower(l.movie_title) = lower(m.movie_title)
    and l.movie_year = m.movie_year
),

shared_ratings as (
    select 
        r.movielens_user_id,
        r.movielens_movie_id,
        r.rating as their_rating,
        mr.my_rating
    from {{ ref('stg_movielens_ratings') }} r
    join my_ratings mr
    on r.movielens_movie_id = mr.movielens_movie_id
),

average_ratings as (
    select
        movielens_user_id,
        avg(rating) as their_avg_rating
    from {{ ref('stg_movielens_ratings') }}
    group by movielens_user_id
)

select
    sr.movielens_user_id,
    corr(sr.their_rating, sr.my_rating) as correlation,
    count(*) as shared_movie_count,
    ar.their_avg_rating
from shared_ratings sr
join average_ratings ar
on sr.movielens_user_id = ar.movielens_user_id
group by sr.movielens_user_id, ar.their_avg_rating
having count(*) >= 50
and not isnan(corr(their_rating, my_rating))
order by correlation desc

