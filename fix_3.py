#!/usr/bin/env python3
"""Fix remaining 3 issues."""

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

tenants = supabase_get("tenants", "id,name,payment_status,due_date")

# 1. Fix ايمن جمال الدين فرغلي → mark paid, due 2026-01-26
for t in tenants:
    if "ايمن" in t["name"] and "فرغلي" in t["name"]:
        status = supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": "2026-01-26", "payment_status": "paid"})
        print(f"✓ {t['name']} → due: 2026-01-26, paid (HTTP {status})")

# 2. Fix وليد عبد المجيد الماحى / ابنته سلمى → mark paid, due 2026-01-06 (same as سلمي)
for t in tenants:
    if "وليد" in t["name"] and "الماحى" in t["name"]:
        status = supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": "2026-01-06", "payment_status": "paid"})
        print(f"✓ {t['name']} → due: 2026-01-06, paid (HTTP {status})")

# 3. Fix Ibrahim → set due date
for t in tenants:
    if t["name"] == "Ibrahim":
        status = supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": "2026-06-15"})
        print(f"✓ {t['name']} → due: 2026-06-15 (HTTP {status})")
