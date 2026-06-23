#!/usr/bin/env python3
"""Update the 7 remaining tenants with correct DB names and CSV due dates."""

import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

def supabase_get(table, select="*", params=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select={select}"
    if params:
        url += "&" + "&".join(f"{k}={v}" for k, v in params.items())
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
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.read().decode()}")
        return e.status

tenants = supabase_get("tenants", "id,name,room_id,payment_status,due_date")

# CSV name → (DB name, due_date) mapping
# From the CSV:
# انس نبيل عبالجواد → 1 يناير → DB: انس نبيل عبدالجواد
# عبدالرحمن احمد عبدالرسول → 30 يناير → DB: عبدالرحمن احمد عبدالسيد
# اشرف جمال عجوه/محمذ جمال عجوه → 31 يناير → DB: اشرف جمال عجوه/محمد جمال عجوه
# يارا أحمد عبدالحليم → 16 مايو → not found in DB
# منال عبّد الحميد ابراهيم → 18 مايو → DB: منال عبدالحميد ابراهيم شرقاوي
# سلوى خيمتونج → 2 يونيه → not found in DB
# مجد نبيل عثمان جوده → 9 يونيه → DB: مجد نبيل عثمان واخوه

updates = [
    ("انس نبيل عبدالجواد", "2026-01-01"),
    ("عبدالرحمن احمد عبدالسيد", "2026-01-30"),
    ("اشرف جمال عجوه/محمد جمال عجوه", "2026-01-31"),
    ("منال عبدالحميد ابراهيم شرقاوي", "2026-05-18"),
    ("مجد نبيل عثمان واخوه", "2026-06-09"),
]

# Also need to handle the 2 not in DB: يارا and سلوى
# Let me check if they exist with different names
all_names = [t["name"] for t in tenants]
for name in all_names:
    if "يارا" in name or "سلوى" in name or "خيمتونج" in name:
        print(f"Found: {name}")

print("── Updating 5 matched tenants ──")
for db_name, due in updates:
    match = None
    for t in tenants:
        if t["name"] == db_name:
            match = t
            break
    if match:
        status = supabase_patch("tenants", f"id=eq.{match['id']}", {"due_date": due, "payment_status": "paid"})
        print(f"{'✓' if status in (200,204) else '✗'} {db_name} → due: {due}, paid (HTTP {status})")
    else:
        print(f"✗ {db_name} → NOT FOUND")

print("\n── 2 tenants not in DB (يارا, سلوى) ──")
print("These need to be added manually or rooms need to be created.")
print("يارا أحمد عبدالحليم → Baraka B11F, due 2026-05-16")
print("سلوى خيمتونج → Baraka B2S, due 2026-06-02")
