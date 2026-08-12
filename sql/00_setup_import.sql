-- ============================================================
-- 00_setup_import.sql
-- Purpose:
-- Import the raw Kaggle e-commerce events CSV into DuckDB.
--
-- Dataset:
-- eCommerce Events History in Electronics Store
-- Source: Kaggle / Michael Kechinov
--
-- IMPORTANT:
-- Update the CSV path below to your own local file location
-- before running this script.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Import raw CSV
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE raw_events AS

SELECT *

FROM read_csv_auto(
    'C:/PATH/TO/events.csv',
    header = true
);


-- ------------------------------------------------------------
-- 2. Validate import
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS raw_rows
FROM raw_events;


DESCRIBE raw_events;
