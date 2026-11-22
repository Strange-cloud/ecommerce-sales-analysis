# E-Commerce Sales & Customer Analysis (SQL + Tableau)

*Work in progress.* An analysis of about 100,000 orders from Olist, a Brazilian online marketplace (2016–2018), answering 12 business questions on sales, repeat customers, delivery and payments with PostgreSQL, and presenting the results in a Tableau Public dashboard.

## Status

- [x] Project structure and setup scripts
- [ ] Data loaded and checked
- [ ] Cleaning
- [ ] Analysis queries
- [ ] Dashboard
- [ ] Findings and recommendations

## Repo layout

| Folder | Contents |
| --- | --- |
| `sql/01_setup/` | Create tables, add keys, row-count check |
| `sql/02_cleaning/` | Cleaning views |
| `sql/03_analysis/` | One file per theme: sales, customers, delivery, sellers, payments |
| `scripts/` | `load_data.py`: loads the CSVs into PostgreSQL |
| `exports/` | Query results exported for Tableau |

## Reproduce it

1. Install PostgreSQL and Python 3 (`pip install pandas psycopg2-binary`).
2. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and put the zip in `data/raw/`.
3. Run `python scripts/load_data.py`.

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licensed CC BY-NC-SA 4.0. Thanks to Olist for releasing it.
