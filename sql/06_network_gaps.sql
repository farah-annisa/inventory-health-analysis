/* =====================================================================
   06_network_gaps.sql
   ---------------------------------------------------------------------
   Business question: is a gap a store problem or a supply problem?

   A likely stockout that hits the same item in three or more stores at
   the same time points upstream, to the supplier or the distribution
   centre, rather than to one store's ordering. Two runs overlap when
   each starts before the other ends.

   Output: stockout_network   one row per likely stockout run, with the
                              number of stores out of that item at the
                              same time

   Why it matters: store-level gaps go to the store team; network gaps
   go to the buyer and the supplier, and need a different fix.
   ===================================================================== */

CREATE OR REPLACE TABLE stockout_network AS
WITH likely AS (
    SELECT item_id, store_id, run_start, run_end
    FROM stockout_runs
    WHERE likely_cause = 'Likely stockout'
)
SELECT
    r.item_id,
    r.store_id,
    r.run_start,
    r.run_end,
    1 + COUNT(DISTINCT o.store_id)      AS stores_out_together,
    1 + COUNT(DISTINCT o.store_id) >= 3 AS network_gap
FROM likely AS r
LEFT JOIN likely AS o
    ON o.item_id = r.item_id
   AND o.store_id <> r.store_id
   AND o.run_start <= r.run_end
   AND o.run_end >= r.run_start
GROUP BY r.item_id, r.store_id, r.run_start, r.run_end;
