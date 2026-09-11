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
)

select
    movielens_user_id,
    corr(their_rating, my_rating) as correlation,
    count(*) as shared_movie_count
from shared_ratings
group by movielens_user_id
having count(*) >= 50
and not isnan(corr(their_rating, my_rating))
order by correlation desc

