"""Test the SQL logic on synthetic M5-format data where the right answers are known.

Run from the repository root:  python tests/test_sql_logic.py

The synthetic data has four stores and twelve items with Poisson daily sales, plus
problems planted on purpose:
  1. HOUSEHOLD_1_001 sells nothing at CA_1 for 10 days     -> one likely stockout, about 60 units lost
  2. HOUSEHOLD_1_002 sells nothing at 3 stores at once     -> a network gap (3 stores out together)
  3. Every store is shut on Christmas Day                  -> closed day, never part of a stockout
  4. HOBBIES_1_004 sells about once every 20 days          -> a slow seller, never flagged
  5. HOUSEHOLD_1_008 stops selling at WI_1 on day 200      -> dead stock (still priced, no sales)
"""
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(7)

# ----------------------------------------------------------------- synthetic data
DAYS = 420
dates = pd.date_range("2014-01-04", periods=DAYS, freq="D")          # starts on a Saturday, like M5
stores = pd.DataFrame({"store_id": ["CA_1", "CA_2", "TX_1", "WI_1"], "state_id": ["CA", "CA", "TX", "WI"]})
items = pd.DataFrame({
    "item_id": [f"HOUSEHOLD_1_{i:03d}" for i in range(1, 9)] + [f"HOBBIES_1_{i:03d}" for i in range(1, 5)],
})
items["dept_id"] = items["item_id"].str[:-4]
items["cat_id"] = items["item_id"].str.split("_").str[0]
rate = dict(zip(items["item_id"], [6, 5, 4, 8, 3, 2.5, 7, 4, 5, 3, 2, 0.05]))

calendar = pd.DataFrame({"date": dates})
calendar["wm_yr_wk"] = 11400 + (np.arange(DAYS) // 7)
calendar["weekday"] = calendar["date"].dt.day_name()
calendar["wday"] = np.arange(DAYS) % 7 + 1
calendar["month"] = calendar["date"].dt.month
calendar["year"] = calendar["date"].dt.year
christmas = pd.Timestamp("2014-12-25")
calendar["event_name_1"] = np.where(calendar["date"] == christmas, "Christmas", None)
calendar["event_type_1"] = np.where(calendar["date"] == christmas, "National", None)
calendar["event_name_2"] = None
calendar["event_type_2"] = None
for col in ["snap_CA", "snap_TX", "snap_WI"]:
    calendar[col] = 0

rows = []
for store in stores["store_id"]:
    for item in items["item_id"]:
        units = rng.poisson(rate[item], DAYS)
        rows.append(pd.DataFrame({"item_id": item, "store_id": store, "date": dates, "units": units}))
sales = pd.concat(rows, ignore_index=True)
day = (sales["date"] - dates[0]).dt.days

sales.loc[sales["date"] == christmas, "units"] = 0                                         # 3. stores shut
sales.loc[(sales.item_id == "HOUSEHOLD_1_001") & (sales.store_id == "CA_1") & day.between(300, 309), "units"] = 0
sales.loc[(sales.item_id == "HOUSEHOLD_1_002") & sales.store_id.isin(["CA_1", "CA_2", "TX_1"]) & day.between(320, 327), "units"] = 0
sales.loc[(sales.item_id == "HOUSEHOLD_1_008") & (sales.store_id == "WI_1") & (day >= 200), "units"] = 0

prices = (sales[["item_id", "store_id"]].drop_duplicates()
          .merge(calendar[["wm_yr_wk"]].drop_duplicates(), how="cross")
          .assign(sell_price=5.0))

con = duckdb.connect()
for name, df in {"sales_daily": sales, "items": items, "stores": stores, "calendar": calendar, "prices": prices}.items():
    con.register("df_view", df)
    con.execute(f"CREATE TABLE {name} AS SELECT * FROM df_view")
    con.unregister("df_view")
con.execute("ALTER TABLE sales_daily ALTER date TYPE DATE")
con.execute("ALTER TABLE calendar ALTER date TYPE DATE")

for script in sorted((ROOT / "sql").glob("*.sql")):
    for statement in con.extract_statements(script.read_text()):
        con.execute(statement)

q = lambda sql: con.sql(sql).df()
results = []


def check(name, passed, detail=""):
    results.append(passed)
    print(f"{'PASS' if passed else 'FAIL'}  {name}{'  (' + detail + ')' if detail else ''}")


# ----------------------------------------------------------------- checks
closed = q("SELECT store_id FROM v_store_days WHERE NOT store_open AND date = DATE '2014-12-25'")
check("Christmas is detected as a closed day in every store", len(closed) == 4, f"{len(closed)} of 4")

gap_1 = (dates[300] - pd.Timedelta(days=2)).date(), (dates[300] + pd.Timedelta(days=2)).date()
gap_2 = (dates[320] - pd.Timedelta(days=2)).date(), (dates[320] + pd.Timedelta(days=2)).date()
planted = q(f"""SELECT run_days, est_lost_units FROM stockout_runs
               WHERE item_id = 'HOUSEHOLD_1_001' AND store_id = 'CA_1' AND likely_cause = 'Likely stockout'
                 AND run_start BETWEEN DATE '{gap_1[0]}' AND DATE '{gap_1[1]}'""")
check("Planted 10-day gap is flagged", len(planted) == 1 and int(planted["run_days"].iloc[0]) == 10)
if len(planted):
    lost = float(planted["est_lost_units"].iloc[0])
    check("Lost units are close to the truth (10 days x 6 a day = 60)", 40 <= lost <= 80, f"{lost:.1f}")

network = q(f"""SELECT store_id, stores_out_together, network_gap FROM stockout_network
               WHERE item_id = 'HOUSEHOLD_1_002' AND run_start BETWEEN DATE '{gap_2[0]}' AND DATE '{gap_2[1]}'""")
check("Gap planted in 3 stores is a network gap", len(network) == 3 and network["network_gap"].all()
      and (network["stores_out_together"] == 3).all(), f"{len(network)} runs")

xmas_runs = q("""SELECT COUNT(*) AS n FROM stockout_runs
                 WHERE DATE '2014-12-25' BETWEEN run_start AND run_end""")["n"].iloc[0]
check("No stockout run includes the closed day", xmas_runs == 0, f"{xmas_runs} runs")

slow = q("SELECT COUNT(*) AS n FROM stockout_runs WHERE item_id = 'HOBBIES_1_004'")["n"].iloc[0]
check("Slow seller is never flagged as a stockout", slow == 0, f"{slow} runs")

dead = q("SELECT stock_status FROM slow_dead_stock WHERE item_id = 'HOUSEHOLD_1_008' AND store_id = 'WI_1'")
check("Line that stopped selling is classed as dead", dead["stock_status"].iloc[0].startswith("Dead"))

false_alarms = q("""SELECT COUNT(*) AS n FROM stockout_runs
                    WHERE likely_cause = 'Likely stockout'
                      AND NOT (item_id = 'HOUSEHOLD_1_001' AND store_id = 'CA_1')
                      AND NOT (item_id = 'HOUSEHOLD_1_002' AND store_id IN ('CA_1', 'CA_2', 'TX_1'))
                      AND NOT (item_id = 'HOUSEHOLD_1_008' AND store_id = 'WI_1')""")["n"].iloc[0]
check("No false alarms on clean Poisson series", false_alarms == 0, f"{false_alarms} runs")

rop = q("""SELECT item_id, store_id, lead_time_days, reorder_point_units FROM reorder_points
           ORDER BY item_id, store_id, lead_time_days""")
rising = rop.groupby(["item_id", "store_id"])["reorder_point_units"].apply(lambda s: s.is_monotonic_increasing).all()
check("Reorder points rise with lead time", len(rop) > 0 and rising, f"{len(rop) // 3} A item-stores")

abc = q("SELECT SUM(pct_of_revenue) AS total FROM abc_xyz_matrix")["total"].iloc[0]
check("ABC-XYZ shares add up to 100%", abs(abc - 100) < 0.5, f"{abc:.1f}%")

kpis = q("SELECT * FROM dash_kpis")
total = q("SELECT SUM(est_lost_revenue) AS t FROM dash_stockouts_52w")["t"].iloc[0]
check("KPI table has one row that matches the stockout detail", len(kpis) == 1
      and abs(kpis["est_lost_revenue_52w"].iloc[0] - total) < 1)

print(f"\n{sum(results)} of {len(results)} checks passed")
raise SystemExit(0 if all(results) else 1)
