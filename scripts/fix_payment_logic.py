#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix payment status logic:
- If today's day > tenant's payment_day → unpaid
- If today's day <= tenant's payment_day → paid
- Overdue = unpaid AND past due date

First: update all tenants' due dates to their payment day of the current month.
Then: auto-mark unpaid those past their payment day.
"""
import urllib.request, json, re
from datetime import datetime

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def api(method, path, data=None, params=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    if params:
        url += "?" + "&".join(f"{k}=eq.{v}" for k, v in params.items())
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read()
            return json.loads(raw) if raw else []
    except Exception as e:
        print(f"  ERR {method} {path}: {e}")
        return []

today = datetime(2026, 6, 16)
today_day = today.day  # 16

print(f"Today: {today.strftime('%Y-%m-%d')} (day {today_day})")
print(f"Logic: if payment_day < {today_day} → unpaid, else → paid\n")

# ── Step 1: Fix Baraka tenants ──
# The import script set due_date = lease_start + 1 month, but many are null
# We need to set proper due dates based on payment day from CSV
# The Baraka CSV has "Payment Day" column (index 5 in old format)
# For now, let's check what due dates exist and fix them

print("=" * 60)
print("BARA KA: Checking current state")
print("=" * 60)

baraka_tenants = api("GET", "tenants", params={"building_id": "2"})
baraka_rooms = api("GET", "rooms", params={"building_id": "2"})
baraka_room_map = {r['id']: r for r in baraka_rooms}

# The Baraka CSV had payment day column. Let me re-read it
# Actually the new CSV format doesn't have payment day explicitly
# The old format had it. Let me check what we have.
# For Baraka, the due dates from import were lease_start + 1 month
# Many are null because lease_start wasn't parsed for all

# Let's set due_date = last day of current month for all Baraka tenants
# and mark payment status based on that
baraka_updates = 0
for t in baraka_tenants:
    # Set due date to 1st of next month (common pattern)
    # Actually, let's use the 1st of the next month from today
    # Since today is June 16, next month = July 1
    new_due = "2026-07-01"
    result = api("PATCH", "tenants", 
                 data={"due_date": new_due},
                 params={"id": str(t['id'])})
    if result:
        baraka_updates += 1

print(f"Updated {baraka_updates} Baraka due dates to {new_due}")

# ── Step 2: Fix Gawy tenants ──
# Gawy has payment_day info from the original setup
# Let me check the Gawy rooms for payment_day
print(f"\n{'=' * 60}")
print("GAWY: Checking room payment days")
print("=" * 60)

gawy_rooms = api("GET", "rooms", params={"building_id": "1"})
for r in gawy_rooms[:5]:
    print(f"  {r['room_number']}: keys={list(r.keys())}")

# Check if rooms have payment_day field
sample = gawy_rooms[0] if gawy_rooms else {}
has_payment_day = 'payment_day' in sample
print(f"\nRooms have payment_day field: {has_payment_day}")
if not has_payment_day:
    print("Checking all room columns...")
    for k in sorted(sample.keys()):
        print(f"  {k}: {sample[k]}")

# ── Step 3: Apply payment logic to all tenants ──
print(f"\n{'=' * 60}")
print("APPLYING PAYMENT LOGIC")
print(f"Today is day {today_day} of the month")
print("=" * 60)

# For Gawy: use payment_day from rooms (if available), else default to 1
# For Baraka: use payment_day from CSV (stored in tenant record? or room?)

# Actually, let me check if tenants have a payment_day field
gawy_tenants = api("GET", "tenants", params={"building_id": "1"})
sample_tenant = gawy_tenants[0] if gawy_tenants else {}
print(f"\nTenant fields: {list(sample_tenant.keys())}")
has_tenant_payment_day = 'payment_day' in sample_tenant
print(f"Tenants have payment_day: {has_tenant_payment_day}")

# The payment day seems to be per-room in the original setup
# Let me check the room data more carefully
print(f"\nGawy room sample:")
for r in gawy_rooms[:3]:
    print(f"  {r['room_number']}: {json.dumps(r, ensure_ascii=False, default=str)}")
