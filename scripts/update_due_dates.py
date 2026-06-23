#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Update tenant due_dates to payment_day of current month.
For Baraka: use payment_day from old CSV
For Gawy: use payment_day = 1 (all due on 1st)

Then the Flutter app will auto-check: if today > due_date → unpaid
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

# Update all tenants
for building_id, name in [(1, "Gawy"), (2, "Baraka")]:
    tenants = api("GET", "tenants", params={"building_id": str(building_id)})
    rooms = api("GET", "rooms", params={"building_id": str(building_id)})
    room_map = {r['room_number']: r for r in rooms}
    
    updated = 0
    for t in tenants:
        room = room_map.get(t['room_id'])
        rn = room['room_number'] if room else '?'
        
        # Get payment day
        if building_id == 2 and rn in baraka_payment_days:
            pd = baraka_payment_days[rn]
        else:
            pd = 1  # default: 1st
        
        # Set due_date to payment_day of CURRENT month
        new_due = f"2026-06-{pd:02d}"
        
        # Set payment_status: if today > payment_day → unpaid
        new_status = 'unpaid' if today.day > pd else 'paid'
        
        result = api("PATCH", "tenants",
                     data={"due_date": new_due, "payment_status": new_status},
                     params={"id": str(t['id'])})
        if result:
            updated += 1
            status_icon = 'PAID' if new_status == 'paid' else 'UNPAID'
            print(f"  {status_icon} {t['name'][:20]:20s}  rn={rn:5s}  due={new_due}  (payment_day={pd})")
    
    print(f"\n{name}: {updated} tenants updated")
