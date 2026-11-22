"""Load the 9 Olist CSV files into a PostgreSQL database named `olist`.

Steps: unzip the Kaggle download if needed, create the database and tables
(sql/01_setup/01_create_tables.sql), bulk-load each CSV with COPY, add the
foreign keys (02_add_foreign_keys.sql), then check every table's row count
against its CSV.

Usage (from the project folder):
    python scripts/load_data.py

It asks for the password you chose for the `postgres` user when installing
PostgreSQL (or reads it from the PGPASSWORD environment variable). The password
is only used to connect and is never saved.
"""
import getpass
import os
import sys
import zipfile
from pathlib import Path

import pandas as pd
import psycopg2

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
SQL = ROOT / "sql" / "01_setup"
DB = "olist"

# table name -> CSV file name, in load order (parents before children)
FILES = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
}


def unzip_if_needed() -> None:
    if all((RAW / f).exists() for f in FILES.values()):
        return
    for z in RAW.glob("*.zip"):
        print(f"Unzipping {z.name}")
        with zipfile.ZipFile(z) as zf:
            for member in zf.namelist():
                name = Path(member).name
                if name in FILES.values():
                    (RAW / name).write_bytes(zf.read(member))
    missing = [f for f in FILES.values() if not (RAW / f).exists()]
    if missing:
        sys.exit(f"Missing in data/raw: {', '.join(missing)}\n"
                 "Download the dataset zip from Kaggle and put it in data/raw.")


def connect(dbname: str, password: str):
    return psycopg2.connect(host="localhost", port=5432, user="postgres",
                            password=password, dbname=dbname)


def main() -> int:
    unzip_if_needed()
    password = os.environ.get("PGPASSWORD") or getpass.getpass("Password for the postgres user: ")

    # Create the database if it does not exist yet
    admin = connect("postgres", password)
    admin.autocommit = True
    with admin.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB,))
        if not cur.fetchone():
            cur.execute(f"CREATE DATABASE {DB}")
            print(f"Created database {DB}")
    admin.close()

    conn = connect(DB, password)
    with conn, conn.cursor() as cur:
        cur.execute((SQL / "01_create_tables.sql").read_text(encoding="utf-8"))
        print("Created tables")
        for table, fname in FILES.items():
            # utf-8-sig drops the byte-order mark some of the files start with
            with open(RAW / fname, encoding="utf-8-sig") as f:
                cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT csv, HEADER true)", f)
            print(f"  loaded {table}")
        cur.execute((SQL / "02_add_foreign_keys.sql").read_text(encoding="utf-8"))
        print("Added foreign keys and indexes")

    # Row-count check: database vs. CSV (pandas handles comments that span lines)
    print(f"\n{'table':<22}{'csv rows':>12}{'db rows':>12}  check")
    ok = True
    with conn.cursor() as cur:
        for table, fname in FILES.items():
            csv_rows = len(pd.read_csv(RAW / fname, encoding="utf-8-sig", dtype=str))
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            db_rows = cur.fetchone()[0]
            match = csv_rows == db_rows
            ok &= match
            print(f"{table:<22}{csv_rows:>12,}{db_rows:>12,}  {'OK' if match else 'MISMATCH'}")
    conn.close()
    print("\nAll tables match." if ok else "\nSome tables do not match: check the rows above.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
