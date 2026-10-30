/* =====================================================================
   03_mart_item_store_week.sql
   ---------------------------------------------------------------------
   One row per item, store and Walmart week (weeks start on Saturday).
   Later scripts and the dashboards read this small table instead of
   re-scanning the 11.8-million-row daily table.

   Output: mart_item_store_week  (about 1.7 million rows)

   Why it matters: aggregate once, reuse everywhere; queries stay fast
   and every weekly number comes from one definition.
   ===================================================================== */

CREATE OR REPLACE TABLE mart_item_store_week AS
SELECT
    item_id,
    dept_id,
    cat_id,
    store_id,
    state_id,
    wm_yr_wk,
    MIN(date)                                                    AS week_start,
    COUNT(*)                                                     AS days_in_week,  -- 7 except at the edges
    SUM(units)                                                   AS units,
    ROUND(SUM(COALESCE(revenue, 0)), 2)                          AS revenue,
    COUNT(*) FILTER (WHERE on_shelf)                             AS days_listed,
    COUNT(*) FILTER (WHERE on_shelf AND store_open AND units = 0) AS zero_sale_days_listed,
    ROUND(AVG(sell_price), 2)                                    AS avg_price
FROM v_sales_daily
GROUP BY item_id, dept_id, cat_id, store_id, state_id, wm_yr_wk;
