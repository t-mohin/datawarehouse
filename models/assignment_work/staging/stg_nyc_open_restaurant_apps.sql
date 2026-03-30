-- Clean and standardize NYC Open Restaurant Applications data
-- One row per application

WITH source AS (
    SELECT * 
    FROM {{ source('raw_H3', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        -- Keep other columns
        * EXCEPT (
            objectid,
            globalid,
            restaurant_name,
            legal_business_name,
            doing_business_as_dba,
            borough,
            zip,
            business_address,
            time_of_submission,
            latitude,
            longitude
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,
        CAST(globalid AS STRING) AS global_id,

        -- Business Info
        TRIM(CAST(restaurant_name AS STRING)) AS restaurant_name,
        TRIM(CAST(legal_business_name AS STRING)) AS legal_business_name,
        TRIM(CAST(doing_business_as_dba AS STRING)) AS dba_name,

        -- Borough standardization (same logic as 311 model)
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- ZIP cleaning (same pattern as 311)
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
            WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 9 THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 10
                AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}')
            THEN CAST(zip AS STRING)
            ELSE NULL
        END AS zip_code,

        -- Address
        TRIM(CAST(business_address AS STRING)) AS business_address,

        -- Timestamp
        CAST(time_of_submission AS TIMESTAMP) AS submitted_at,

        -- Location
        CAST(latitude AS NUMERIC) AS latitude,
        CAST(longitude AS NUMERIC) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
      AND time_of_submission IS NOT NULL

    -- Deduplicate (keep latest submission per objectid)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid 
        ORDER BY time_of_submission DESC
    ) = 1
)

SELECT * FROM cleaned
