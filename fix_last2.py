#!/usr/bin/env python3
"""Update the last 2 tenants with slightly different names."""

import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

def supabase_get(table, select="*"):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select={select}"
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

def supabase_patch(table, filters, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{filters}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, method="PATCH", headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status

tenants = supabase_get("tenants", "id,name,room_id")

# يارا أحمد عبدالحليم → DB: يارا احمد عبدالحليم (due: 16 مايو = 2026-05-16)
# سلوى خيمتونج → DB: سلوي خيمتونج (due: 2 يونيه = 2026-06-02)

updates = [
    ("يارا احمد عبدالحليم", "2026-05-16"),
    ("سلوي خيمتونج", "2026-06-02"),
]

for db_name, due in updates:
    for t in tenants:
        if t["name"] == db_name:
            status = supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": due, "payment_status": "paid"})
            print(f"{'✓' if status in (200,204) else '✗'} {db_name} → due: {due}, paid (HTTP {status})")
            break
