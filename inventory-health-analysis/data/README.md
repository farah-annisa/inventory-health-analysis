# Data

- `raw/` is not in the repository. Download [M5 Forecasting – Accuracy](https://www.kaggle.com/c/m5-forecasting-accuracy/data) from Kaggle (accept the competition rules first) and put `sales_train_evaluation.csv`, `calendar.csv` and `sell_prices.csv` here.
- `inventory.duckdb` is created by `notebooks/01_data_preparation.ipynb` and is not in the repository.
- `processed/` holds the aggregated tables exported by `notebooks/03_insights.ipynb`. The Excel planner and the Power BI dashboard read these files. Column definitions: [docs/data_dictionary.md](../docs/data_dictionary.md).
