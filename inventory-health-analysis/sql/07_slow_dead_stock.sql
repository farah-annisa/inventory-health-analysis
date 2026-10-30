/* =====================================================================
   07_slow_dead_stock.sql
   ---------------------------------------------------------------------
   Business question: which lines are dead weight on the shelf?

   For every item-store, measured back from the last day of data:
     Delisted  no shelf price in the last 4 weeks
     Dead      still listed, but no sales in the last 26 weeks
     Slow      still listed, 2 or fewer units in the last 13 weeks
     Active    everything else

   Output: slow_dead_stock   one row per item-store

   Why it matters: dead and slow lines tie up shelf space and cash; this
   list starts the markdown and delisting review.
   ===================================================================== */

CREATE OR REPLACE TABLE slow_dead_stock AS
WITH params AS (
    SELECT 2 AS slow_max_units_13w
),
last_day AS (
    SELECT MAX(date) AS max_date
    FROM sales_daily
),
stats AS (
    SELECT
        v.item_id,
        v.dept_id,
        v.cat_id,
        v.store_id,
        v.state_id,
        SUM(CASE WHEN v.date > l.max_date - 91 THEN v.units ELSE 0 END)                AS units_13w,
        SUM(CASE WHEN v.date > l.max_date - 182 THEN v.units ELSE 0 END)               AS units_26w,
        ROUND(SUM(CASE WHEN v.date > l.max_date - 364 THEN COALESCE(v.revenue, 0) ELSE 0 END), 2)
                                                                                       AS revenue_52w,
        MAX(CASE WHEN v.units > 0 THEN v.date END)                                     AS last_sale_date,
        BOOL_OR(v.on_shelf AND v.date > l.max_date - 28)                               AS listed_last_4w,
        ROUND(AVG(CASE WHEN v.on_shelf AND v.date > l.max_date - 28 THEN v.sell_price END), 2)
                                                                                       AS current_price
    FROM v_sales_daily AS v
    CROSS JOIN last_day AS l
    GROUP BY v.item_id, v.dept_id, v.cat_id, v.store_id, v.state_id
)
SELECT
    s.item_id,
    s.dept_id,
    s.cat_id,
    s.store_id,
    s.state_id,
    s.units_13w,
    s.units_26w,
    s.revenue_52w,
    s.last_sale_date,
    l.max_date - s.last_sale_date AS days_since_last_sale,
    s.current_price,
    CASE
        WHEN NOT s.listed_last_4w THEN 'Delisted'
        WHEN s.units_26w = 0 THEN 'Dead: no sales in 26 weeks'
        WHEN s.units_13w <= p.slow_max_units_13w THEN 'Slow: 2 or fewer units in 13 weeks'
        ELSE 'Active'
    END AS stock_status
FROM stats AS s
CROSS JOIN last_day AS l
CROSS JOIN params AS p;
