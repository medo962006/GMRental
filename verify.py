#!/usr/bin/env python3
"""Verify all tenants are paid with correct due dates."""

import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

def supabase_get(table, select="*"):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select={select}&order=name"
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

tenants = supabase_get("tenants", "id,name,payment_status,due_date")

paid = sum(1 for t in tenants if t["payment_status"] == "paid")
unpaid = sum(1 for t in tenants if t["payment_status"] == "unpaid")
no_date = sum(1 for t in tenants if not t["due_date"])

print(f"Total tenants: {len(tenants)}")
print(f"Paid: {paid}")
print(f"Unpaid: {unpaid}")
print(f"No due_date: {no_date}")

if unpaid > 0:
    print("\n── Unpaid tenants ──")
    for t in tenants:
        if t["payment_status"] == "unpaid":
            print(f"  {t['name']} | due: {t['due_date']}")

if no_date > 0:
    print("\n── Missing due_date ──")
    for t in tenants:
        if not t["due_date"]:
            print(f"  {t['name']} | status: {t['payment_status']}")
