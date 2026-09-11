with my_rated_movies as (
    select
        m.movielens_movie_id,
        from {{ ref('stg_letterboxd_ratings') }} l
        join {{ ref('stg_movielens_movies') }} m
        on lower(l.movie_title) = lower(m.movie_title)
        and l.movie_year = m.movie_year
),

their_rated_movies as (
    select
        r.movielens_movie_id,
        r.rating,
        c.residual_correlation,
    from {{ ref('stg_movielens_ratings') }} r
    join {{ ref('int_user_residual_correlations') }} c
    on r.movielens_user_id = c.movielens_user_id
    where r.movielens_movie_id not in (select movielens_movie_id from my_rated_movies)
),

avg_movie_ratings as (
    select
        avg(rating) as avg_movie_rating,
        movielens_movie_id
    from {{ ref('stg_movielens_ratings') }}
    group by movielens_movie_id
),

weighted_residuals as (
    select
        amr.movielens_movie_id,
        sum(trm.residual_correlation * (trm.rating - amr.avg_movie_rating)) / sum(trm.residual_correlation) as weighted_residual,
        count(*) as num_predictions
    from avg_movie_ratings amr
    join their_rated_movies trm
    on amr.movielens_movie_id = trm.movielens_movie_id
    where residual_correlation > 0
    group by amr.movielens_movie_id
)

select
    m.movie_title,
    m.movie_year,
    m.genres,
    wr.weighted_residual,
    wr.weighted_residual + amr.avg_movie_rating as niche_rating,
    amr.avg_movie_rating,
    wr.num_predictions
from weighted_residuals wr
join {{ ref('stg_movielens_movies') }} m
on wr.movielens_movie_id = m.movielens_movie_id
join avg_movie_ratings amr
on m.movielens_movie_id = amr.movielens_movie_id
where wr.num_predictions >= 10
order by weighted_residual desc
limit 100