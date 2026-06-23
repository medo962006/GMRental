#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Try to add payment_day column via Supabase SQL"""
import urllib.request, json

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

# Try the SQL endpoint
sql = "ALTER TABLE tenants ADD COLUMN IF NOT EXISTS payment_day INTEGER DEFAULT 1;"

# Method 1: Try via rpc/exec_sql
headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}

# Check if there's an rpc function
data = json.dumps({"query": sql}).encode()
req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/rpc/exec_sql", data=data, headers=headers, method="POST")
try:
    with urllib.request.urlopen(req, timeout=30) as res:
        print(f"OK: {res.read().decode()}")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(f"RPC exec_sql: {e.code} → {err[:200]}")

# Method 2: Try the SQL endpoint directly
data2 = json.dumps({"sql": sql}).encode()
req2 = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/sql", data=data2, headers=headers, method="POST")
try:
    with urllib.request.urlopen(req2, timeout=30) as res:
        print(f"OK: {res.read().decode()}")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(f"SQL endpoint: {e.code} → {err[:200]}")
