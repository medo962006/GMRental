#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Supabase -> CSV backup script.
Backs up all tables to timestamped CSV files in scripts/backups/.
Also writes a combined JSON file for full restore.

Usage (from project root):
  python scripts/backup_supabase.py
"""

import csv
import io
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ── Supabase config (matches lib/config/app_config.dart) ──────────
SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

# All tables to back up
TABLES = [
    "rooms",
    "tenants",
    "masareef",
    "task_routines",
    "operational_costs",
    "insurance_ledger",
    "insurance_transactions",
    "admin_notifications",
    "changelog",
    "device_codes",
    "whatsapp_logs",
]

# Output directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
BACKUP_DIR = os.path.join(PROJECT_DIR, "scripts", "backups")


def fetch_table(table):
    """Fetch all rows from a Supabase table via REST API."""
    url = f"{SUPABASE_URL}/rest/v1/{table}?select=*&order=id"
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []
        raise


def rows_to_csv(rows):
    """Convert a list of dicts to a CSV string."""
    if not rows:
        return ""
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def main():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    total_rows = 0
    total_files = 0
    errors = []
    all_data = {}

    for table in TABLES:
        try:
            rows = fetch_table(table)
        except Exception as e:
            errors.append(f"  [ERR] {table}: {e}")
            continue

        if not rows:
            print(f"  [--] {table}: empty (skipped)")
            continue

        # Save individual CSV
        csv_content = rows_to_csv(rows)
        filename = f"{timestamp}_{table}.csv"
        filepath = os.path.join(BACKUP_DIR, filename)

        with open(filepath, "w", encoding="utf-8-sig", newline="") as f:
            f.write(csv_content)

        total_rows += len(rows)
        total_files += 1
        all_data[table] = rows
        print(f"  [OK] {table}: {len(rows)} rows -> {filename}")

    # ── Combined JSON ──────────────────────────────────────────────
    if all_data:
        combined_file = os.path.join(BACKUP_DIR, f"{timestamp}_all_tables.json")
        with open(combined_file, "w", encoding="utf-8") as f:
            json.dump(all_data, f, ensure_ascii=False, indent=2, default=str)
        print(f"  [OK] Combined JSON: {combined_file}")

    # ── Summary ────────────────────────────────────────────────────
    print(f"\n{'='*50}")
    print(f"Backup complete: {total_files} tables, {total_rows} total rows")
    print(f"Directory: {BACKUP_DIR}")
    print(f"Timestamp: {timestamp}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(e)


if __name__ == "__main__":
    main()
