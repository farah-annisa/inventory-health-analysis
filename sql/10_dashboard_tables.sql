/* =====================================================================
   10_dashboard_tables.sql
   ---------------------------------------------------------------------
   Small, tidy tables for the Excel planner and the Power BI dashboard.
   Notebook 03 exports them to data/processed/ as CSV files.

     dash_weekly_sales        weekly units and revenue by store and department
     dash_stockouts_52w       every likely stockout of the last 52 weeks
     dash_item_store_summary  one row per item-store: segment, status,
                              stockouts, lost sales and reorder points
     dash_kpis                the headline numbers (one row)
     dash_stockout_watchlist  the 500 most expensive likely stockouts
     dash_lost_sales_by_store lost sales by store and department
     dash_slow_dead           slow, dead and delisted lines only

   "Last 52 weeks" = sales or runs after the date 364 days before the
   last day of data (22 May 2016).
   ===================================================================== */

-- Weekly sales for trend charts (full weeks only)
CREATE OR REPLACE TABLE dash_weekly_sales AS
SELECT
    week_start,
    wm_yr_wk,
    store_id,
    state_id,
    cat_id,
    dept_id,
    SUM(units)             AS units,
    ROUND(SUM(revenue), 2) AS revenue
FROM mart_item_store_week
WHERE days_in_week = 7
GROUP BY week_start, wm_yr_wk, store_id, state_id, cat_id, dept_id
ORDER BY week_start, store_id, dept_id;


-- Every likely stockout of the last 52 weeks, with its segment and network flag
CREATE OR REPLACE TABLE dash_stockouts_52w AS
SELECT
    r.store_id,
    r.state_id,
    r.cat_id,
    r.dept_id,
    r.item_id,
    a.abc,
    a.xyz,
    a.abc || a.xyz          AS segment,
    r.run_start,
    r.run_end,
    r.run_days,
    r.baseline_daily_units,
    r.est_lost_units,
    r.est_lost_revenue,
    n.stores_out_together,
    n.network_gap,
    r.ongoing_at_data_end
FROM stockout_runs AS r
JOIN stockout_network AS n
    ON n.item_id = r.item_id
   AND n.store_id = r.store_id
   AND n.run_start = r.run_start
LEFT JOIN abc_xyz AS a
    ON a.item_id = r.item_id
   AND a.store_id = r.store_id
WHERE r.likely_cause = 'Likely stockout'
  AND r.run_start > (SELECT MAX(date) - 364 FROM sales_daily)
ORDER BY r.est_lost_revenue DESC, r.store_id, r.item_id, r.run_start;


-- One row per item-store, joining every analysis together
CREATE OR REPLACE TABLE dash_item_store_summary AS
WITH stockouts AS (
    SELECT
        item_id,
        store_id,
        COUNT(*)                                AS stockouts_52w,
        SUM(run_days)                           AS stockout_days_52w,
        SUM(est_lost_units)                     AS lost_units_52w,
        SUM(est_lost_revenue)                   AS lost_revenue_52w,
        COUNT(*) FILTER (WHERE network_gap)     AS network_stockouts_52w,
        SUM(CASE WHEN network_gap THEN est_lost_revenue ELSE 0 END) AS network_lost_revenue_52w,
        BOOL_OR(ongoing_at_data_end)            AS out_of_stock_now
    FROM dash_stockouts_52w
    GROUP BY item_id, store_id
),
reorder AS (
    -- one column per lead-time scenario (conditional aggregation)
    SELECT
        item_id,
        store_id,
        MAX(avg_daily_demand)                                           AS avg_daily_demand,
        MAX(sd_daily_demand)                                            AS sd_daily_demand,
        MAX(CASE WHEN lead_time_days = 3 THEN reorder_point_units END)  AS reorder_point_3d,
        MAX(CASE WHEN lead_time_days = 7 THEN reorder_point_units END)  AS reorder_point_7d,
        MAX(CASE WHEN lead_time_days = 14 THEN reorder_point_units END) AS reorder_point_14d
    FROM reorder_points
    GROUP BY item_id, store_id
)
SELECT
    a.item_id,
    a.dept_id,
    a.cat_id,
    a.store_id,
    a.state_id,
    a.abc,
    a.xyz,
    a.abc || a.xyz                              AS segment,
    a.revenue_52w,
    a.units_52w,
    a.avg_weekly_units,
    a.cv_weekly_units,
    s.stock_status,
    s.units_13w,
    s.last_sale_date,
    s.days_since_last_sale,
    s.current_price,
    COALESCE(o.stockouts_52w, 0)                AS stockouts_52w,
    COALESCE(o.stockout_days_52w, 0)            AS stockout_days_52w,
    COALESCE(o.lost_units_52w, 0)               AS lost_units_52w,
    ROUND(COALESCE(o.lost_revenue_52w, 0), 2)   AS lost_revenue_52w,
    COALESCE(o.network_stockouts_52w, 0)        AS network_stockouts_52w,
    ROUND(COALESCE(o.network_lost_revenue_52w, 0), 2) AS network_lost_revenue_52w,
    COALESCE(o.out_of_stock_now, FALSE)         AS out_of_stock_now,
    r.avg_daily_demand,
    r.sd_daily_demand,
    r.reorder_point_3d,
    r.reorder_point_7d,
    r.reorder_point_14d
FROM abc_xyz AS a
JOIN slow_dead_stock AS s
    ON s.item_id = a.item_id
   AND s.store_id = a.store_id
LEFT JOIN stockouts AS o
    ON o.item_id = a.item_id
   AND o.store_id = a.store_id
LEFT JOIN reorder AS r
    ON r.item_id = a.item_id
   AND r.store_id = a.store_id
ORDER BY a.store_id, a.revenue_52w DESC, a.item_id;


-- Headline numbers (one row)
CREATE OR REPLACE TABLE dash_kpis AS
WITH sales AS (
    SELECT
        SUM(revenue_52w)                                       AS revenue_52w,
        SUM(units_52w)                                         AS units_52w,
        COUNT(*)                                               AS item_stores,
        SUM(CASE WHEN abc = 'A' THEN revenue_52w ELSE 0 END)
            / NULLIF(SUM(revenue_52w), 0)                      AS share_revenue_a,
        COUNT(*) FILTER (WHERE abc = 'A')                      AS a_item_stores,
        COUNT(*) FILTER (WHERE stockouts_52w > 0)              AS item_stores_with_stockouts,
        COUNT(*) FILTER (WHERE out_of_stock_now)               AS out_of_stock_now,
        COUNT(*) FILTER (WHERE stock_status LIKE 'Dead%')      AS dead_item_stores,
        COUNT(*) FILTER (WHERE stock_status LIKE 'Slow%')      AS slow_item_stores,
        COUNT(*) FILTER (WHERE stock_status = 'Delisted')      AS delisted_item_stores,
        COUNT(*) FILTER (WHERE reorder_point_7d IS NOT NULL)   AS reorder_points_set
    FROM dash_item_store_summary
),
gaps AS (
    SELECT
        COUNT(*)                                                     AS stockout_runs_52w,
        SUM(est_lost_units)                                          AS est_lost_units_52w,
        SUM(est_lost_revenue)                                        AS est_lost_revenue_52w,
        COUNT(*) FILTER (WHERE network_gap)                          AS network_gap_runs,
        SUM(CASE WHEN network_gap THEN est_lost_revenue ELSE 0 END)  AS network_lost_revenue
    FROM dash_stockouts_52w
)
SELECT
    ROUND(s.revenue_52w, 0)                                               AS revenue_52w,
    s.units_52w,
    s.item_stores,
    ROUND(100 * s.share_revenue_a, 1)                                     AS pct_revenue_from_a,
    s.a_item_stores,
    g.stockout_runs_52w,
    s.item_stores_with_stockouts,
    ROUND(g.est_lost_units_52w, 0)                                        AS est_lost_units_52w,
    ROUND(g.est_lost_revenue_52w, 0)                                      AS est_lost_revenue_52w,
    ROUND(100 * g.est_lost_revenue_52w / NULLIF(s.revenue_52w, 0), 2)     AS lost_revenue_pct_of_sales,
    g.network_gap_runs,
    ROUND(100 * g.network_lost_revenue / NULLIF(g.est_lost_revenue_52w, 0), 1) AS pct_lost_revenue_network_gaps,
    s.out_of_stock_now,
    s.dead_item_stores,
    s.slow_item_stores,
    s.delisted_item_stores,
    s.reorder_points_set
FROM sales AS s
CROSS JOIN gaps AS g;


-- The 500 most expensive likely stockouts of the last 52 weeks
CREATE OR REPLACE TABLE dash_stockout_watchlist AS
SELECT *
FROM dash_stockouts_52w
ORDER BY est_lost_revenue DESC, store_id, item_id, run_start
LIMIT 500;


-- Lost sales by store and department (last 52 weeks)
CREATE OR REPLACE TABLE dash_lost_sales_by_store AS
SELECT
    w.store_id,
    w.state_id,
    w.dept_id,
    w.revenue                                                  AS revenue_52w,
    COALESCE(g.stockout_runs, 0)                               AS stockout_runs,
    COALESCE(g.est_lost_units, 0)                              AS est_lost_units,
    COALESCE(g.est_lost_revenue, 0)                            AS est_lost_revenue,
    ROUND(100 * COALESCE(g.est_lost_revenue, 0) / w.revenue, 2) AS lost_pct_of_revenue
FROM (
    SELECT store_id, state_id, dept_id, SUM(revenue_52w) AS revenue
    FROM abc_xyz
    GROUP BY store_id, state_id, dept_id
) AS w
LEFT JOIN (
    SELECT
        store_id,
        dept_id,
        COUNT(*)                        AS stockout_runs,
        ROUND(SUM(est_lost_units), 0)   AS est_lost_units,
        ROUND(SUM(est_lost_revenue), 2) AS est_lost_revenue
    FROM dash_stockouts_52w
    GROUP BY store_id, dept_id
) AS g
    ON g.store_id = w.store_id
   AND g.dept_id = w.dept_id
ORDER BY est_lost_revenue DESC, w.store_id, w.dept_id;


-- Slow, dead and delisted lines only
CREATE OR REPLACE TABLE dash_slow_dead AS
SELECT *
FROM slow_dead_stock
WHERE stock_status <> 'Active'
ORDER BY stock_status, revenue_52w DESC, store_id, item_id;
