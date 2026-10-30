/* =====================================================================
   04_abc_xyz.sql
   ---------------------------------------------------------------------
   Business question: which items drive revenue, and how predictable is
   their demand?

   ABC (value), ranked within each store over the last 52 full weeks:
     A = items that make up the first 80% of the store's revenue
     B = the next 15%
     C = the last 5% (and anything that did not sell)
   XYZ (predictability), coefficient of variation (CV) of weekly units:
     X = CV <= 0.5 (steady)   Y = 0.5 to 1.0 (variable)   Z = above 1.0 (erratic)

   Outputs: abc_xyz          one row per item-store
            abc_xyz_matrix   the 3x3 summary, with a planning rule per cell

   Why it matters: ABC-XYZ tells planners where to automate and where to
   spend their review time.
   ===================================================================== */

CREATE OR REPLACE TABLE abc_xyz AS
WITH full_weeks AS (
    SELECT
        wm_yr_wk,
        ROW_NUMBER() OVER (ORDER BY wm_yr_wk DESC) AS weeks_ago
    FROM mart_item_store_week
    GROUP BY wm_yr_wk
    HAVING MIN(days_in_week) = 7
),
last_52_weeks AS (
    SELECT wm_yr_wk
    FROM full_weeks
    WHERE weeks_ago <= 52
),
item_store AS (
    SELECT
        m.item_id,
        m.dept_id,
        m.cat_id,
        m.store_id,
        m.state_id,
        SUM(m.revenue)                              AS revenue_52w,
        SUM(m.units)                                AS units_52w,
        AVG(m.units)                                AS avg_weekly_units,
        STDDEV_SAMP(m.units)                        AS sd_weekly_units,
        COUNT(*) FILTER (WHERE m.days_listed > 0)   AS weeks_listed
    FROM mart_item_store_week AS m
    JOIN last_52_weeks AS w
        ON w.wm_yr_wk = m.wm_yr_wk
    GROUP BY m.item_id, m.dept_id, m.cat_id, m.store_id, m.state_id
),
ranked AS (
    SELECT
        *,
        -- share of the store's revenue held by items ranked above this one
        SUM(revenue_52w) OVER (
            PARTITION BY store_id
            ORDER BY revenue_52w DESC, item_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) / NULLIF(SUM(revenue_52w) OVER (PARTITION BY store_id), 0) AS revenue_share_before,
        sd_weekly_units / NULLIF(avg_weekly_units, 0)                AS cv_weekly_units
    FROM item_store
)
SELECT
    item_id,
    dept_id,
    cat_id,
    store_id,
    state_id,
    ROUND(revenue_52w, 2)      AS revenue_52w,
    units_52w,
    ROUND(avg_weekly_units, 2) AS avg_weekly_units,
    ROUND(cv_weekly_units, 2)  AS cv_weekly_units,
    weeks_listed,
    CASE
        WHEN revenue_52w > 0 AND COALESCE(revenue_share_before, 0) < 0.80 THEN 'A'
        WHEN revenue_52w > 0 AND revenue_share_before < 0.95 THEN 'B'
        ELSE 'C'
    END AS abc,
    CASE
        WHEN cv_weekly_units IS NULL THEN 'Z'   -- never sold in the window
        WHEN cv_weekly_units <= 0.5 THEN 'X'
        WHEN cv_weekly_units <= 1.0 THEN 'Y'
        ELSE 'Z'
    END AS xyz
FROM ranked;


CREATE OR REPLACE TABLE abc_xyz_matrix AS
SELECT
    abc,
    xyz,
    abc || xyz                                                         AS segment,
    COUNT(*)                                                           AS item_stores,
    ROUND(SUM(revenue_52w), 2)                                         AS revenue_52w,
    ROUND(100 * SUM(revenue_52w) / SUM(SUM(revenue_52w)) OVER (), 1)   AS pct_of_revenue,
    CASE abc || xyz
        WHEN 'AX' THEN 'Automate replenishment; tight safety stock; review weekly'
        WHEN 'AY' THEN 'Safety stock sized to variability; review weekly'
        WHEN 'AZ' THEN 'Plan with buyers; check daily for stockouts'
        WHEN 'BX' THEN 'Automate replenishment; standard safety stock'
        WHEN 'BY' THEN 'Review every two weeks'
        WHEN 'BZ' THEN 'Order against demand signals; avoid overstock'
        WHEN 'CX' THEN 'Bulk orders; review monthly'
        WHEN 'CY' THEN 'Keep minimal stock; review monthly'
        WHEN 'CZ' THEN 'Candidate for delisting or order-on-demand'
    END AS planning_rule
FROM abc_xyz
GROUP BY abc, xyz
ORDER BY abc, xyz;
