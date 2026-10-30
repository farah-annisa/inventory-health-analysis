/* =====================================================================
   09_reorder_points.sql
   ---------------------------------------------------------------------
   Business question: when should each top item be reordered?

   For A-items (from 04_abc_xyz.sql), using the last 13 weeks of days
   when the item was listed and the store open:
     safety stock  = z * sd_daily_demand * sqrt(lead time)
     reorder point = avg_daily_demand * lead time + safety stock
   Days inside a likely stockout are left out: an empty shelf records
   zero sales, which would understate real demand (censored demand).
   z = 1.65 targets a 95% service level (stock covers demand in 95% of
   replenishment cycles). M5 has no supplier lead times, so three
   scenarios are produced: 3, 7 and 14 days. The Excel planner lets the
   user try any lead time and service level.

   Output: reorder_points   one row per A item-store per lead time

   Why it matters: lead time is an assumption, so it is shown as a
   scenario instead of being hidden inside one number.
   ===================================================================== */

CREATE OR REPLACE TABLE reorder_points AS
WITH params AS (
    SELECT
        1.65 AS z,                  -- 95% service level
        91   AS lookback_days,      -- last 13 weeks
        28   AS min_days_observed
),
last_day AS (
    SELECT MAX(date) AS max_date
    FROM sales_daily
),
recent AS (
    SELECT
        v.item_id,
        v.store_id,
        v.units
    FROM v_sales_daily AS v
    CROSS JOIN last_day AS l
    CROSS JOIN params AS p
    WHERE v.on_shelf
      AND v.store_open
      AND v.date > l.max_date - p.lookback_days
      AND NOT EXISTS (                       -- skip days the shelf was likely empty
          SELECT 1
          FROM stockout_runs AS r
          WHERE r.item_id = v.item_id
            AND r.store_id = v.store_id
            AND r.likely_cause = 'Likely stockout'
            AND v.date BETWEEN r.run_start AND r.run_end
      )
),
demand AS (
    SELECT
        item_id,
        store_id,
        AVG(units)         AS avg_daily_demand,
        STDDEV_SAMP(units) AS sd_daily_demand,
        COUNT(*)           AS days_observed
    FROM recent
    GROUP BY item_id, store_id
),
lead_times AS (
    SELECT lead_time_days
    FROM (VALUES (3), (7), (14)) AS lt(lead_time_days)
)
SELECT
    a.item_id,
    a.dept_id,
    a.cat_id,
    a.store_id,
    a.state_id,
    a.abc,
    a.xyz,
    lt.lead_time_days,
    ROUND(d.avg_daily_demand, 3)                                       AS avg_daily_demand,
    ROUND(d.sd_daily_demand, 3)                                        AS sd_daily_demand,
    ROUND(p.z * d.sd_daily_demand * SQRT(lt.lead_time_days), 1)        AS safety_stock_units,
    CEIL(d.avg_daily_demand * lt.lead_time_days
         + p.z * d.sd_daily_demand * SQRT(lt.lead_time_days))          AS reorder_point_units
FROM abc_xyz AS a
JOIN demand AS d
    ON d.item_id = a.item_id
   AND d.store_id = a.store_id
CROSS JOIN lead_times AS lt
CROSS JOIN params AS p
WHERE a.abc = 'A'
  AND d.days_observed >= p.min_days_observed;
