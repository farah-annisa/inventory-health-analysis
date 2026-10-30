/* =====================================================================
   02_quality_checks.sql
   ---------------------------------------------------------------------
   Read-only checks, run before any analysis. Each query returns one
   small result; notebook 02 prints them all.

   Why it matters: these checks found the store-closed days (Christmas)
   that would otherwise have looked like hundreds of stockouts.
   ===================================================================== */

-- Q1. Size and date range
SELECT
    COUNT(*)                 AS row_count,
    COUNT(DISTINCT item_id)  AS items,
    COUNT(DISTINCT store_id) AS stores,
    MIN(date)                AS first_date,
    MAX(date)                AS last_date
FROM sales_daily;

-- Q2. Duplicate item-store-day keys (expect 0)
SELECT COUNT(*) AS duplicate_keys
FROM (
    SELECT item_id, store_id, date
    FROM sales_daily
    GROUP BY item_id, store_id, date
    HAVING COUNT(*) > 1
) AS dupes;

-- Q3. Nulls and negative units (expect all 0)
SELECT
    COUNT(*) FILTER (WHERE units IS NULL) AS null_units,
    COUNT(*) FILTER (WHERE units < 0)     AS negative_units,
    COUNT(*) FILTER (WHERE date IS NULL)  AS null_dates
FROM sales_daily;

-- Q4. Item-store pairs missing any day (expect 0)
SELECT COUNT(*) AS item_stores_missing_days
FROM (
    SELECT item_id, store_id, COUNT(*) AS days_present
    FROM sales_daily
    GROUP BY item_id, store_id
) AS per_pair
WHERE days_present <> (SELECT MAX(date) - MIN(date) + 1 FROM sales_daily);

-- Q5. Shelf coverage and zero-sale share
SELECT
    COUNT(*) AS item_store_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT on_shelf) / COUNT(*), 1) AS pct_days_not_listed,
    COUNT(*) FILTER (WHERE units > 0 AND NOT on_shelf)                AS sales_without_price,
    ROUND(100.0 * COUNT(*) FILTER (WHERE units = 0 AND on_shelf)
                / COUNT(*) FILTER (WHERE on_shelf), 1)                AS pct_listed_days_zero_sales
FROM v_sales_daily;

-- Q6. Store-closed days detected (expect Christmas Day for every store)
SELECT
    store_id,
    date,
    store_units
FROM v_store_days
WHERE NOT store_open
ORDER BY date, store_id;

-- Q7. Price sanity
SELECT
    ROUND(MIN(sell_price), 2) AS min_price,
    ROUND(AVG(sell_price), 2) AS avg_price,
    ROUND(MAX(sell_price), 2) AS max_price
FROM prices;
