/* =====================================================================
   05_stockout_runs.sql
   ---------------------------------------------------------------------
   Business question: where are we likely losing sales to empty shelves?

   M5 has no stock-on-hand column, so stockouts are inferred:
     1. Keep only "active" days: item listed (has a price), store open,
        and the item has already made its first sale in that store.
     2. Find runs of consecutive zero-sale days (gaps-and-islands).
     3. For each run, take the item's average daily sales in the 8 weeks
        before the run as its normal demand (lambda).
     4. If sales follow a Poisson pattern, the chance of L zero days in a
        row while in stock is exp(-lambda * L). Flag the run when that
        chance is under 1 in 100,000.
        Why so strict: every gap in two years is tested, so a 1% bar would
        flag thousands of gaps by luck alone (the multiple-testing problem).
     5. Estimated lost units = lambda * L; lost revenue = units * shelf price.
     6. Gaps longer than 28 days are labelled "Long gap": more likely a
        range change than a stockout, so they stay out of the totals.

   Output: stockout_runs   one row per flagged run

   Assumptions (logged in docs/ba_pack.md): Poisson demand, 8-week
   baseline, 1-in-100,000 bar, 28-day cap, no promotion data. Tune them
   in the params block below.

   Why it matters: without stock data, stockouts can still be found and
   valued, so planners fix the most expensive gaps first.
   ===================================================================== */

CREATE OR REPLACE TABLE stockout_runs AS
WITH params AS (
    SELECT
        0.00001 AS max_chance,         -- flag gaps with under a 1-in-100,000 chance while in stock
        0.2     AS min_daily_units,    -- skip very slow sellers (under one sale every five days)
        56      AS baseline_days,      -- compare with the 8 weeks before the gap
        28      AS min_baseline_days,  -- need at least 4 weeks of active history before the gap
        28      AS max_stockout_days   -- longer gaps are labelled as possible range changes
),
first_sales AS (
    SELECT
        item_id,
        store_id,
        MIN(date) AS first_sale_date
    FROM sales_daily
    WHERE units > 0
    GROUP BY item_id, store_id
),
active_days AS (
    SELECT
        v.item_id,
        v.dept_id,
        v.cat_id,
        v.store_id,
        v.state_id,
        v.date,
        v.units,
        v.sell_price
    FROM v_sales_daily AS v
    JOIN first_sales AS f
        ON f.item_id = v.item_id
       AND f.store_id = v.store_id
    WHERE v.on_shelf
      AND v.store_open
      AND v.date >= f.first_sale_date
),
zero_days AS (
    -- gaps-and-islands: consecutive dates in a run share the same grp value
    SELECT
        *,
        (date - DATE '2000-01-01')
            - ROW_NUMBER() OVER (PARTITION BY item_id, store_id ORDER BY date) AS grp
    FROM active_days
    WHERE units = 0
),
runs AS (
    SELECT
        item_id,
        dept_id,
        cat_id,
        store_id,
        state_id,
        MIN(date)       AS run_start,
        MAX(date)       AS run_end,
        COUNT(*)        AS run_days,
        AVG(sell_price) AS price_during_run
    FROM zero_days
    GROUP BY item_id, dept_id, cat_id, store_id, state_id, grp
    HAVING COUNT(*) >= 2
),
baselines AS (
    SELECT
        r.item_id,
        r.store_id,
        r.run_start,
        AVG(a.units) AS baseline_daily_units,
        COUNT(*)     AS baseline_days_used
    FROM runs AS r
    CROSS JOIN params AS p
    JOIN active_days AS a
        ON a.item_id = r.item_id
       AND a.store_id = r.store_id
       AND a.date BETWEEN r.run_start - p.baseline_days AND r.run_start - 1
    GROUP BY r.item_id, r.store_id, r.run_start
)
SELECT
    r.item_id,
    r.dept_id,
    r.cat_id,
    r.store_id,
    r.state_id,
    r.run_start,
    r.run_end,
    r.run_days,
    ROUND(b.baseline_daily_units, 3)                                  AS baseline_daily_units,
    EXP(-b.baseline_daily_units * r.run_days)                         AS chance_if_in_stock,
    ROUND(b.baseline_daily_units * r.run_days, 1)                     AS est_lost_units,
    ROUND(b.baseline_daily_units * r.run_days * r.price_during_run, 2) AS est_lost_revenue,
    CASE
        WHEN r.run_days > p.max_stockout_days THEN 'Long gap: check for range change'
        ELSE 'Likely stockout'
    END                                                               AS likely_cause,
    r.run_end = (SELECT MAX(date) FROM sales_daily)                   AS ongoing_at_data_end
FROM runs AS r
JOIN baselines AS b
    ON b.item_id = r.item_id
   AND b.store_id = r.store_id
   AND b.run_start = r.run_start
CROSS JOIN params AS p
WHERE b.baseline_days_used >= p.min_baseline_days
  AND b.baseline_daily_units >= p.min_daily_units
  AND EXP(-b.baseline_daily_units * r.run_days) < p.max_chance;
