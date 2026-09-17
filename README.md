# Movie Taste Recomender

A movie recommendation system built with dbt and DuckDB that uses collaborative filtering to combine my personal Letterboxd ratings with the MovieLens dataset. It produces two outputs:
 
1. **Popular picks** — movies my closest taste matches rated highly that I haven't seen
2. **Niche picks** — movies my closest taste matches rated higher than the general population that I haven't seen

## Why this project

Some of my favorite movies are not as beloved by the general population as they are by me. I wanted to create something to help me find movies I might love that I may not have heard of since they aren't universally loved.


## Data sources

- **My own ratings** — exported from Letterboxd's official data export (`letterboxd.com/settings/data`). ~770 rated movies.
- **[MovieLens ml-32m](https://grouplens.org/datasets/movielens/32m/)** — public dataset from GroupLens. ~32M ratings, ~87.5k movies, ~200k users, frozen as of October 2023.


I didn't use Letterboxd's real API (invite-only access) and didn't scrape other users' Letterboxd data (their ToS bans scraping as of Dec 2025). MovieLens is the standard public dataset for this kind of collaborative filtering project.

## Architecture

Runs entirely locally, no cloud warehouse:
 
- **dbt-core** (1.x) + **dbt-duckdb** adapter
- **DuckDB** reads the raw CSVs directly as external sources, no separate load step
- Standard staging → intermediate → marts layering

```
models/
├── staging/
│   ├── sources.yml
│   ├── stg_letterboxd_ratings.sql
│   ├── stg_movielens_movies.sql      # parses year out of title, fixes "Title, The" ordering
│   └── stg_movielens_ratings.sql
├── intermediate/
│   ├── int_user_correlations.sql             # correlation on raw ratings
│   └── int_user_residual_correlations.sql    # correlation on residuals vs. population average
└── marts/
    ├── movie_recommendations_popular.sql
    └── movie_recommendations_niche.sql
```

## Methodology
 
### Matching my ratings to MovieLens
 
Letterboxd and MovieLens don't share an ID, so movies are matched on title + year. This ended up being the most annoying part of the project — see Known Limitations.

### movie_recommendations_popular
 
For every MovieLens user with at least 50 movies rated in common with me (picked this number by checking the overlap distribution — at 50+, there are still 46k+ candidate users, so it's not too strict), get their Pearson correlation with my ratings on the shared movies.
 
Predictions use a mean-centered weighted average (the standard memory-based collaborative filtering formula from Resnick et al., 1994) instead of just averaging raw ratings:

```
predicted_rating = my_avg_rating + [ Σ correlation × (their_rating − their_avg_rating) ] / Σ correlation
```

Centering matters because people rate on different personal scales — someone who rates almost everything 4-5 stars and someone who rates almost everything 1-2 stars can both "love" the same movie relative to their own average, but averaging raw numbers would just let the generous rater dominate. Subtracting each person's own average first, then adding mine back at the end, fixes that.
 
Only positive correlations count (negative correlation means someone's taste runs opposite to mine, which shouldn't push a prediction up). Each recommended movie needs at least 10 people contributing to its score, so nothing is based on 1-2 opinions.
 
One thing worth noting: correlation is undefined for anyone who rated every shared movie identically — no variance to correlate against. These get filtered out.
 
### movie_recommendations_niche
 
Different technique, not just a filtered version of the popular list. Instead of correlating raw ratings, this correlates each person's **residual against the population average**:
 
1. Get the population average rating for every movie
2. For every movie I've rated, compute `my_rating − population_avg` — this is how much I differ from consensus
3. Do the same for every candidate user on the same shared movies
4. Correlate the residuals, not the raw ratings — this finds people whose pattern of disagreeing with the crowd matches mine, which is different from just "rates things similarly to me" overall
5. For movies I haven't seen, take a correlation-weighted average of these residual-matched users' residuals, then add it back to the population average to get an actual score
Sorted by the size of the gap (`weighted_residual`) between that reconstructed score and the population average, not by the reconstructed score alone — a movie could reconstruct to a high score just by being broadly good, without actually being a hidden gem relative to consensus.
 
Same rules as the popular list: positive correlation only, minimum 10 contributors per movie.

## Known limitations
 
- **Title+year matching gets ~81% coverage** (623/770 ratings matched). Checked the misses individually — they're mostly one of two things: movies released after MovieLens's October 2023 cutoff, or MovieLens having the wrong year for a movie (e.g. it lists *Black Panther* under 2017, a year off its actual 2018 release).
- **Title+year isn't always a unique key.** A handful of genuinely different movies share both a title and release year (e.g. 4 different films are all titled "Alone" from 2020 in this dataset). Rather than risk matching to the wrong specific film, any title+year with more than one match is dropped entirely — those movies just won't match, which is part of why the coverage above isn't higher.
- **617 of 87,178 MovieLens movies (~0.7%) don't have a year in the source title at all** and can't be matched on year. Left in staging with a null year rather than dropped, in case a future version matches them differently.
- **No genre-based re-ranking.** Original plan was to weight recommendations by my own per-genre averages, so a taste-twin match wouldn't push things like musicals up just because they correlate well overall on everything else. Didn't get to it — see Future Work.
- **No accuracy testing.** This doesn't check its own predictions against anything — no held-out ratings, no way to measure if the predicted scores are actually close to real. Right now it's just "does the output look reasonable."

## Build notes
 
Started building this with dbt Fusion (dbt's newer engine) since it's the more current option, but DuckDB isn't in Fusion's adapter list yet and I hit a few beta specific issues trying to get it working with local CSV sources. Switched to dbt-core 1.x + dbt-duckdb partway through and that worked without issues.

## Setup
 
```bash
python -m venv venv
source venv/bin/activate
pip install "dbt-core<2.0" dbt-duckdb
 
# add your own data (not included in this repo):
#   data/raw/letterboxd/ratings.csv   — your own Letterboxd export
#   data/raw/movielens/*.csv          — ml-32m from grouplens.org
 
dbt run
dbt test
```

## Future work
 
- Genre-based re-ranking using my own per-genre rating averages
- Some way to actually check prediction accuracy — e.g. hide a chunk of my real ratings, see how close the model's predictions land, instead of just eyeballing whether the output looks reasonable