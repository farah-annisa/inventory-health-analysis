/* =====================================================================
   08_demand_drivers.sql
   ---------------------------------------------------------------------
   Business question: when does demand spike, so stock can be built ahead?

   Each department-state-day is compared with a normal day for the same
   weekday (no event, no SNAP payment, all stores open):
     uplift = units on the day / normal units for that weekday - 1
   +0.25 means 25% above a normal day; -1.00 means no sales (stores shut).

   Output: demand_drivers   average uplift by event and on SNAP days

   Why it matters: the same method sizes the pre-build for Malaysian
   peaks such as Hari Raya, 11.11 and year-end sales.
   ===================================================================== */

CREATE OR REPLACE TABLE demand_drivers AS
WITH dept_state_day AS (
    SELECT
        dept_id,
        state_id,
        date,
        ANY_VALUE(weekday)      AS weekday,
        ANY_VALUE(event_name_1) AS event_name,
        ANY_VALUE(event_type_1) AS event_type,
        ANY_VALUE(snap_day)     AS snap_day,
        BOOL_AND(store_open)    AS all_stores_open,
        SUM(units)              AS units
    FROM v_sales_daily
    GROUP BY dept_id, state_id, date
),
normal_by_weekday AS (
    SELECT
        dept_id,
        state_id,
        weekday,
        AVG(units) AS normal_units
    FROM dept_state_day
    WHERE event_name IS NULL
      AND snap_day = 0
      AND all_stores_open
    GROUP BY dept_id, state_id, weekday
),
scored AS (
    SELECT
        d.dept_id,
        d.state_id,
        d.date,
        d.event_name,
        d.event_type,
        d.snap_day,
        d.all_stores_open,
        d.units / NULLIF(n.normal_units, 0) - 1 AS uplift
    FROM dept_state_day AS d
    JOIN normal_by_weekday AS n
        ON n.dept_id = d.dept_id
       AND n.state_id = d.state_id
       AND n.weekday = d.weekday
)
SELECT
    'Event'           AS driver_type,
    event_name        AS driver,
    event_type        AS driver_group,
    dept_id,
    COUNT(*)          AS days,
    ROUND(AVG(uplift), 3) AS avg_uplift
FROM scored
WHERE event_name IS NOT NULL
GROUP BY event_name, event_type, dept_id

UNION ALL

SELECT
    'SNAP payment day' AS driver_type,
    'SNAP day'         AS driver,
    'Benefit payment'  AS driver_group,
    dept_id,
    COUNT(*)           AS days,
    ROUND(AVG(uplift), 3) AS avg_uplift
FROM scored
WHERE snap_day = 1
  AND event_name IS NULL
  AND all_stores_open
GROUP BY dept_id;
