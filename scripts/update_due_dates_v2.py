#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix payment logic:
- due_date = payment_day of the NEXT month (the upcoming payment date)
- If today > due_date → unpaid (payment date has passed)
- If today <= due_date → paid (payment date hasn't come yet)

This means:
- Payment day = 15th, due = 2026-07-15, today = June 16 → PAID (July 15 hasn't come)
- Payment day = 15th, due = 2026-07-15, today = July 20 → UNPAID (July 15 passed)
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
        print(f"  ERR: {e}")
        return []

today = datetime(2026, 6, 16)

# Parse Baraka payment days from old CSV
baraka_payment_days = {}
with open("C:\\Users\\ahmed\\GMRental\\hostel_management\\scripts\\baraka_data.csv", 'r', encoding='utf-8') as f:
    lines = f.read().strip().split('\n')

for line in lines[1:]:
    parts = line.split(',')
    if len(parts) < 6:
        continue
    room_raw = parts[0].strip()
    payment_day_str = parts[5].strip()
    floor = parts[1].strip() if len(parts) > 1 else 'Ground floor'
    
    m = re.match(r'Room (\d+)', room_raw)
    if not m:
        continue
    num = int(m.group(1))
    floor_map = {'Ground floor': 'G', 'First floor': 'F', 'Second floor': 'S', 'Roof': 'T'}
    fc = floor_map.get(floor, 'G')
    db_room = f"B{num}{fc}"
    
    try:
        pd = int(payment_day_str)
        if 1 <= pd <= 31:
            baraka_payment_days[db_room] = pd
    except ValueError:
        pass

print(f"Baraka payment days: {len(baraka_payment_days)}")
print(f"Today: {today.strftime('%Y-%m-%d')} (day {today.day})")
print()

# Update all tenants
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
            pd = baraka_payment_days[rn]
        else:
            pd = 1  # default: 1st
        
        # due_date = payment_day of NEXT month
        next_month = today.month + 1
        next_year = today.year
        if next_month > 12:
            next_month = 1
            next_year += 1
        due_date_str = f"{next_year}-{next_month:02d}-{pd:02d}"
        
        # Logic: if today > due_date → unpaid, else → paid
        due_dt = datetime.strptime(due_date_str, "%Y-%m-%d")
        new_status = 'unpaid' if today > due_dt else 'paid'
        
        if new_status == 'paid':
            paid_count += 1
        else:
            unpaid_count += 1
        
        result = api("PATCH", "tenants",
                     data={"due_date": due_date_str, "payment_status": new_status},
                     params={"id": str(t['id'])})
        if result:
            updated += 1
    
    print(f"{name}: {updated} updated ({paid_count} paid, {unpaid_count} unpaid)")

# Verify
print(f"\n{'='*60}")
print("VERIFICATION")
print(f"{'='*60}")

for building_id, name in [(1, "Gawy"), (2, "Baraka")]:
    tenants = api("GET", "tenants", params={"building_id": str(building_id)})
    rooms = api("GET", "rooms", params={"building_id": str(building_id)})
    room_map = {r['id']: r for r in rooms}
    
    paid = [t for t in tenants if t['payment_status'] == 'paid']
    unpaid = [t for t in tenants if t['payment_status'] == 'unpaid']
    
    print(f"\n  {name}: {len(paid)} paid, {len(unpaid)} unpaid")
    for t in sorted(tenants, key=lambda x: (x['payment_status'], x['name'])):
        room = room_map.get(t['room_id'])
        rn = room['room_number'] if room else '?'
        print(f"    {t['payment_status']:6s} {t['name'][:22]:22s}  rn={rn:5s}  due={t.get('due_date', 'N/A')}")
