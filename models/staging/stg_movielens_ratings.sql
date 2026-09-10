select
    userId as movielens_user_id,
    movieId as movielens_movie_id,
    rating, 
    to_timestamp(timestamp) as rated_at
from {{ source('raw', 'movielens_ratings') }}