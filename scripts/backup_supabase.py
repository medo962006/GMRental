#!/usr/bin/env python3
"""
Supabase Daily Backup Script
Fetches all rows from all tables and saves as JSON.
Designed to run as a daily cron job on a laptop.
Backups are saved locally only — NOT committed to any git repo.
"""

import json
import os
import sys
import requests
from datetime import datetime, timezone

# ── Configuration ──────────────────────────────────────
SUPABASE_URL = "https://bqqpfldaeeahdmccxqxv.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNicXFwZmxkYWVlYWhkbWNjeHF4diIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3ODEzNTk4NjIsImV4cCI6MjA5NjkzNTg2Mn0.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"

TABLES = [
    "rooms",
    "tenants",
    "masareef",
    "task_routines",
    "operational_costs",
    "whatsapp_logs",
    "insurance_ledger",
    "insurance_transactions",
    "admin_notifications",
    "changelog",
    "device_codes",
]

BACKUP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups")
HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# ── Helpers ─────────────────────────────────────────────

def fetch_table(table: str) -> list:
    """Fetch ALL rows from a Supabase table using the REST API."""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    params: dict = {"select": "*", "order": "id"}
    
    all_rows = []
    offset = 0
    batch_size = 1000
    
    while True:
        params["offset"] = str(offset)
        params["limit"] = str(batch_size)
        resp = requests.get(url, headers=HEADERS, params=params, timeout=30)
        resp.raise_for_status()
        rows = resp.json()
        if not rows:
            break
        all_rows.extend(rows)
        if len(rows) < batch_size:
            break
        offset += batch_size
    
    return all_rows


def save_backup(data: dict, backup_dir: str) -> str:
    """Save backup data as a timestamped JSON file."""
    os.makedirs(backup_dir, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")
    filename = f"backup_{ts}.json"
    filepath = os.path.join(backup_dir, filename)
    
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, default=str)
    
    return filepath


def main():
    print(f"🗄️  Supabase Backup — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   URL: {SUPABASE_URL}")
    print(f"   Tables: {len(TABLES)}")
    print()
    
    backup = {
        "metadata": {
            "supabase_url": SUPABASE_URL,
            "backup_at": datetime.now(timezone.utc).isoformat(),
            "tables": TABLES,
        },
        "data": {},
    }
    
    total_rows = 0
    errors = []
    
    for table in TABLES:
        try:
            rows = fetch_table(table)
            backup["data"][table] = rows
            count = len(rows)
            total_rows += count
            print(f"   ✅ {table}: {count} rows")
        except Exception as e:
            backup["data"][table] = {"error": str(e)}
            errors.append(table)
            print(f"   ❌ {table}: {e}")
    
    print()
    
    filepath = save_backup(backup, BACKUP_DIR)
    size_kb = os.path.getsize(filepath) / 1024
    print(f"   📁 Saved: {filepath} ({size_kb:.0f} KB)")
    print(f"   📊 Total: {total_rows} rows across {len(TABLES) - len(errors)} tables")
    
    if errors:
        print(f"   ⚠️  Errors: {', '.join(errors)}")
        sys.exit(1)
    
    print(f"   ✅ Backup complete!")
    return filepath


if __name__ == "__main__":
    main()
