"""Export the cleaned data to CSV files for Tableau Public.

Runs every query in sql/04_exports/ and saves its result to exports/ under the
same name without the number (01_orders.sql -> exports/orders.csv). Then prints
row counts and a few totals to check against the SQL analysis.

Usage (from the project folder):
    python scripts/export_for_tableau.py

Asks for the postgres password (or reads PGPASSWORD); it is never saved.
"""
import getpass
import os
import sys
from pathlib import Path

import pandas as pd
import psycopg2

ROOT = Path(__file__).resolve().parent.parent
QUERIES = ROOT / "sql" / "04_exports"
OUT = ROOT / "exports"


def main() -> int:
    password = os.environ.get("PGPASSWORD") or getpass.getpass("Password for the postgres user: ")
    conn = psycopg2.connect(host="localhost", port=5432, user="postgres",
                            password=password, dbname="olist")
    OUT.mkdir(exist_ok=True)

    print(f"{'file':<24}{'rows':>10}")
    with conn.cursor() as cur:
        for sql_file in sorted(QUERIES.glob("*.sql")):
            name = sql_file.stem.split("_", 1)[1] + ".csv"   # 01_orders -> orders.csv
            query = sql_file.read_text(encoding="utf-8").strip().rstrip(";")
            with open(OUT / name, "w", encoding="utf-8", newline="") as f:
                cur.copy_expert(f"COPY (\n{query}\n) TO STDOUT WITH (FORMAT csv, HEADER true)", f)
            rows = sum(1 for _ in open(OUT / name, encoding="utf-8")) - 1
            print(f"{name:<24}{rows:>10,}")
    conn.close()

    # Checks against the analysis (Q1, Q4, Q7, Q8)
    orders = pd.read_csv(OUT / "orders.csv")
    items = pd.read_csv(OUT / "order_items.csv")
    print("\nChecks (should match the SQL findings):")
    print(f"  orders                {len(orders):>12,}   (Q1: 96,211)")
    print(f"  revenue, orders file  {orders['order_value'].sum():>12,.2f}   (Q1: 13,181,027.13)")
    print(f"  revenue, items file   {items['price'].sum():>12,.2f}   (same)")
    print(f"  customers             {orders['customer_unique_id'].nunique():>12,}   (Q4: 93,104)")
    print(f"  late rate             {100 * orders['late_flag'].mean():>11.1f}%   (Q7: 6.8%)")
    print(f"  avg review            {orders['review_score'].mean():>12.2f}   (Q8: about 4.16)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
