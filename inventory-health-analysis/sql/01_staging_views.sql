/* =====================================================================
   01_staging_views.sql
   ---------------------------------------------------------------------
   Two views on top of the five raw tables loaded by notebook 01:
     v_store_days   one row per store per day, with a store_open flag
     v_sales_daily  one enriched row per item, store and day
   Every later script reads from these views, so "listed" and "store
   open" mean the same thing everywhere.

   Engine: DuckDB (PostgreSQL-style SQL). Run all scripts in order with
   notebooks/02_sql_analysis.ipynb, or in the DuckDB CLI:
     duckdb data/inventory.duckdb < sql/01_staging_views.sql

   Why it matters: a single clean staging layer stops each analysis from
   inventing its own definitions.
   ===================================================================== */

-- A store counts as closed on days it sells less than 10% of its average
-- daily units. In M5 this flags Christmas Day, when the stores are shut,
-- so those days are never mistaken for stockouts.
CREATE OR REPLACE VIEW v_store_days AS
WITH store_totals AS (
    SELECT
        store_id,
        date,
        SUM(units) AS store_units
    FROM sales_daily
    GROUP BY store_id, date
)
SELECT
    store_id,
    date,
    store_units,
    store_units >= 0.1 * AVG(store_units) OVER (PARTITION BY store_id) AS store_open
FROM store_totals;


CREATE OR REPLACE VIEW v_sales_daily AS
SELECT
    s.item_id,
    i.dept_id,
    i.cat_id,
    s.store_id,
    st.state_id,
    s.date,
    c.wm_yr_wk,
    c.weekday,
    c.event_name_1,
    c.event_type_1,
    CASE st.state_id
        WHEN 'CA' THEN c.snap_CA
        WHEN 'TX' THEN c.snap_TX
        WHEN 'WI' THEN c.snap_WI
    END AS snap_day,                          -- 1 = SNAP food benefits paid in this state that day
    sd.store_open,
    s.units,
    p.sell_price,
    p.sell_price IS NOT NULL AS on_shelf,     -- a shelf price that week = item listed in that store
    s.units * p.sell_price AS revenue
FROM sales_daily AS s
JOIN items AS i
    ON i.item_id = s.item_id
JOIN stores AS st
    ON st.store_id = s.store_id
JOIN calendar AS c
    ON c.date = s.date
JOIN v_store_days AS sd
    ON sd.store_id = s.store_id
   AND sd.date = s.date
LEFT JOIN prices AS p
    ON p.item_id = s.item_id
   AND p.store_id = s.store_id
   AND p.wm_yr_wk = c.wm_yr_wk;
