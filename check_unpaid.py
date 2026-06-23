#!/usr/bin/env python3
import json, urllib.request

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
for t in tenants:
    if t["payment_status"] == "unpaid":
        print(f"UNPAID: {t['name']:40s} | due: {t['due_date']}")
