#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1. Add payment_day column to tenants table (via Supabase REST)
2. Set payment_day for Baraka tenants from old CSV data
3. Set payment_day = 1 for Gawy tenants
4. Update due_date to payment_day of current month
5. Auto-mark unpaid if today > payment_day
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
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  HTTP {e.code}: {err[:200]}")
        return []
    except Exception as e:
        print(f"  ERR: {e}")
        return []

today = datetime(2026, 6, 16)
today_day = today.day  # 16

# ── Step 1: Check if payment_day column exists ──
print("Step 1: Checking if payment_day column exists...")
sample = api("GET", "tenants", params={"limit": "1"})
if sample:
    has_col = 'payment_day' in sample[0]
    print(f"  payment_day column exists: {has_col}")
    if not has_col:
        print("  → Need to add column via Supabase dashboard or SQL")
        print("  → For now, we'll use due_date logic instead")

# ── Step 2: Parse old Baraka CSV for payment days ──
print("\nStep 2: Parsing Baraka payment days from old CSV...")
baraka_payment_days = {}  # room_number → payment_day

with open("C:\\Users\\ahmed\\GMRental\\hostel_management\\scripts\\baraka_data.csv", 'r', encoding='utf-8') as f:
    lines = f.read().strip().split('\n')

for line in lines[1:]:
    parts = line.split(',')
    if len(parts) < 6:
        continue
    room_raw = parts[0].strip()  # "Room 1"
    payment_day_str = parts[5].strip()  # "8" or "-"
    
    m = re.match(r'Room (\d+)', room_raw)
    if not m:
        continue
    num = int(m.group(1))
    
    # Determine floor from room number
    # The CSV has floor in column 1
    floor = parts[1].strip() if len(parts) > 1 else 'Ground floor'
    floor_map = {'Ground floor': 'G', 'First floor': 'F', 'Second floor': 'S', 'Roof': 'T'}
    fc = floor_map.get(floor, 'G')
    
    db_room = f"B{num}{fc}"
    
    try:
        pd = int(payment_day_str)
        if 1 <= pd <= 31:
            baraka_payment_days[db_room] = pd
    except ValueError:
        pass

print(f"  Found {len(baraka_payment_days)} Baraka payment days")
for rn, pd in sorted(baraka_payment_days.items()):
    print(f"    {rn}: day {pd}")

# ── Step 3: Update all tenants ──
print(f"\nStep 3: Updating all tenants (today is day {today_day})...")

for building_id, name in [(1, "Gawy"), (2, "Baraka")]:
    tenants = api("GET", "tenants", params={"building_id": str(building_id)})
    rooms = api("GET", "rooms", params={"building_id": str(building_id)})
    room_map = {r['room_number']: r for r in rooms}
    
    updated = 0
    paid_count = 0
    unpaid_count = 0
    
    for t in tenants:
        room = room_map.get(t['room_id'])
        rn = room['room_number'] if room else '?'
        
        # Get payment day
        if building_id == 2 and rn in baraka_payment_days:
            payment_day = baraka_payment_days[rn]
        else:
            payment_day = 1  # default: 1st of month
        
        # Logic: if today_day > payment_day → unpaid, else → paid
        if today_day > payment_day:
            new_status = 'unpaid'
            unpaid_count += 1
        else:
            new_status = 'paid'
            paid_count += 1
        
        # Set due_date to payment_day of next month
        next_month = today.month + 1
        next_year = today.year
        if next_month > 12:
            next_month = 1
            next_year += 1
        new_due = f"{next_year}-{next_month:02d}-{payment_day:02d}"
        
        result = api("PATCH", "tenants",
                     data={
                         "payment_status": new_status,
                         "due_date": new_due,
                     },
                     params={"id": str(t['id'])})
        if result:
            updated += 1
    
    print(f"  {name}: {updated} updated ({paid_count} paid, {unpaid_count} unpaid)")

# ── Step 4: Verify ──
print(f"\n{'='*60}")
print("VERIFICATION")
print(f"{'='*60}")

for building_id, name in [(1, "Gawy"), (2, "Baraka")]:
    tenants = api("GET", "tenants", params={"building_id": str(building_id)})
    rooms = api("GET", "rooms", params={"building_id": str(building_id)})
    room_map = {r['id']: r for r in rooms}
    
    paid = sum(1 for t in tenants if t['payment_status'] == 'paid')
    unpaid = sum(1 for t in tenants if t['payment_status'] == 'unpaid')
    
    print(f"\n  {name}: {paid} paid, {unpaid} unpaid")
    for t in sorted(tenants, key=lambda x: x['payment_status']):
        room = room_map.get(t['room_id'])
        rn = room['room_number'] if room else '?'
        print(f"    {t['payment_status']:6s} {t['name'][:25]:25s}  rn={rn:5s}  due={t.get('due_date', 'N/A')}")
