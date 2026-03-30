-- Test restaurant apps
SELECT *
FROM {{ source('raw_H3', 'source_nyc_open_restaurant_apps') }}
LIMIT 10
