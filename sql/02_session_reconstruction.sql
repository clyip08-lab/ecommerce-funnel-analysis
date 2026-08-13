-- ============================================================
-- 02_session_reconstruction.sql
--
-- Purpose:
-- Reconstruct analytical browsing sessions from the raw
-- user_session field.
--
-- Primary definition:
-- Within each user_id + raw user_session pair, events remain
-- in the same analytical session when inactivity is 30 minutes
-- or less. A new analytical session begins only when inactivity
-- exceeds 30 minutes.
--
-- Crossing midnight alone does not force a new session.
--
-- A 60-minute inactivity threshold is also reconstructed as a
-- sensitivity check.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Clean analytical event base
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE events_clean AS

SELECT
    rowid AS source_event_id,

    TRY_CAST(event_time AS TIMESTAMP) AS event_time_utc,

    event_type,

    CAST(product_id AS VARCHAR) AS product_id,
    CAST(category_id AS VARCHAR) AS category_id,

    NULLIF(TRIM(category_code), '') AS category_code,
    NULLIF(TRIM(brand), '') AS brand,

    TRY_CAST(price AS DOUBLE) AS price,

    CAST(user_id AS VARCHAR) AS user_id,
    CAST(user_session AS VARCHAR) AS user_session

FROM raw_events

WHERE user_id IS NOT NULL
  AND user_session IS NOT NULL
  AND TRY_CAST(event_time AS TIMESTAMP) IS NOT NULL;


-- ------------------------------------------------------------
-- 2. Compare each event with the previous event
--    inside the same raw user session
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE event_gaps AS

SELECT
    *,

    LAG(event_time_utc) OVER (
        PARTITION BY user_id, user_session
        ORDER BY event_time_utc, source_event_id
    ) AS previous_event_time

FROM events_clean;


-- ------------------------------------------------------------
-- 3. Flag where a new analytical session begins
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE event_session_flags AS

SELECT
    *,

    CASE
    WHEN previous_event_time IS NULL
        THEN 1

    WHEN event_time_utc - previous_event_time
         > INTERVAL '30 minutes'
        THEN 1

    ELSE 0
END AS new_session_flag

FROM event_gaps;


-- ------------------------------------------------------------
-- 4. Convert session-start flags into session numbers
--
-- Example:
--
-- event    flag    cumulative session number
-- A        1       1
-- B        0       1
-- C        0       1
-- D        1       2
-- E        0       2
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE event_session_numbers AS

SELECT
    *,

    SUM(new_session_flag) OVER (
        PARTITION BY user_id, user_session
        ORDER BY event_time_utc, source_event_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS analytical_session_number

FROM event_session_flags;


-- ------------------------------------------------------------
-- 5. Create the final 30-minute analytical event table
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE analysis_events_30 AS

SELECT
    source_event_id,
    event_time_utc,
    event_type,
    product_id,
    category_id,
    category_code,
    brand,
    price,
    user_id,
    user_session,

    analytical_session_number,

    CONCAT(
        user_id,
        '|',
        user_session,
        '|',
        CAST(analytical_session_number AS VARCHAR)
    ) AS analytical_session_id

FROM event_session_numbers;

-- ============================================================
-- 60-MINUTE SENSITIVITY CHECK
-- ============================================================
--
-- Purpose:
-- Test whether the main session count is highly sensitive to
-- the 30-minute inactivity assumption.
--
-- The same session logic is applied, changing only the
-- inactivity threshold from 30 to 60 minutes.
-- ============================================================

CREATE OR REPLACE TABLE analysis_events_60 AS

WITH session_flags_60 AS (

    SELECT
        *,

        CASE
            WHEN previous_event_time IS NULL
                THEN 1

            WHEN event_time_utc - previous_event_time
                 > INTERVAL '60 minutes'
                THEN 1

            ELSE 0

        END AS new_session_flag_60

    FROM event_gaps
),

session_numbers_60 AS (

    SELECT
        *,

        SUM(new_session_flag_60) OVER (
            PARTITION BY user_id, user_session
            ORDER BY event_time_utc, source_event_id
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS analytical_session_number_60

    FROM session_flags_60
)

SELECT
    source_event_id,
    event_time_utc,
    event_type,
    product_id,
    category_id,
    category_code,
    brand,
    price,
    user_id,
    user_session,

    analytical_session_number_60,

    CONCAT(
        user_id,
        '|',
        user_session,
        '|',
        CAST(analytical_session_number_60 AS VARCHAR)
    ) AS analytical_session_id

FROM session_numbers_60;


-- Validate sensitivity result

SELECT
    COUNT(DISTINCT analytical_session_id)
        AS analytical_sessions_60min
FROM analysis_events_60;

-- Expected:
-- 531,421

-- ============================================================
-- VALIDATION
-- ============================================================


-- ------------------------------------------------------------
-- 6. Row count retained for session analysis
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS analysis_event_rows
FROM analysis_events_30;

-- Expected result:
-- 884,964


-- ------------------------------------------------------------
-- 7. Final analytical session count
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT analytical_session_id)
        AS analytical_sessions_30min
FROM analysis_events_30;

-- Expected result:
-- 539,812


-- ------------------------------------------------------------
-- 8. Validate that no analytical session contains
--    an internal inactivity gap greater than 30 minutes
--
-- Exactly 30 minutes is valid under the primary rule and
-- remains within the same analytical session.
-- ------------------------------------------------------------

WITH internal_gaps AS (

    SELECT
        analytical_session_id,
        event_time_utc,

        LAG(event_time_utc) OVER (
            PARTITION BY analytical_session_id
            ORDER BY event_time_utc, source_event_id
        ) AS previous_event_time

    FROM analysis_events_30
)

SELECT
    COUNT(*) FILTER (
        WHERE previous_event_time IS NOT NULL
          AND event_time_utc - previous_event_time
              > INTERVAL '30 minutes'
    ) AS invalid_internal_gaps

FROM internal_gaps;

-- Expected result:
-- 0
-- ============================================================
-- Validation checks
-- ============================================================


-- Primary 30-minute session definition
SELECT
    COUNT(*) AS analysis_event_rows,
    COUNT(DISTINCT analytical_session_id)
        AS analytical_sessions_30min
FROM analysis_events_30;


-- 60-minute sensitivity definition
SELECT
    COUNT(*) AS analysis_event_rows,
    COUNT(DISTINCT analytical_session_id)
        AS analytical_sessions_60min
FROM analysis_events_60;
