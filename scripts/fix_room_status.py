#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix: update all Baraka rooms to occupied based on CSV data"""
import urllib.request, json, re

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

# Get all Baraka rooms
rooms = api("GET", "rooms", params={"building_id": "2"})
baraka = {r['room_number']: r for r in rooms}

# Parse CSV rooms
csv_rooms = set()
with open("C:\\Users\\ahmed\\GMRental\\hostel_management\\scripts\\baraka_data_new.csv", 'r', encoding='utf-8') as f:
    lines = f.read().strip().split('\n')

for line in lines[1:]:
    parts = line.split(',')
    if len(parts) < 4:
        continue
    raw = parts[3].strip().lower().replace(' ', '')
    if '+' in raw:
        raw = raw.split('+')[0].strip()
    m = re.match(r'(\d+)([gfstr])', raw)
    if m:
        num = int(m.group(1))
        fc = m.group(2).upper()
        db_floor = 'T' if fc == 'R' else fc
        csv_rooms.add(f"B{num}{db_floor}")

# Update rooms
updated = 0
for rn in csv_rooms:
    if rn in baraka:
        rid = baraka[rn]['id']
        result = api("PATCH", "rooms", data={"status": "occupied"}, params={"id": str(rid)})
        if result:
            updated += 1
            print(f"  Updated {rn} (id={rid}) → occupied")
        else:
            print(f"  FAILED {rn} (id={rid})")

# Also update rents from CSV
print("\nUpdating rents...")
for line in lines[1:]:
    parts = line.split(',')
    if len(parts) < 5:
        continue
    raw = parts[3].strip().lower().replace(' ', '')
    if '+' in raw:
        raw = raw.split('+')[0].strip()
    m = re.match(r'(\d+)([gfstr])', raw)
    if not m:
        continue
    num = int(m.group(1))
    fc = m.group(2).upper()
    db_floor = 'T' if fc == 'R' else fc
    db_room = f"B{num}{db_floor}"
    
    rent_str = parts[4].strip().replace(',', '')
    try:
        rent = float(rent_str)
    except:
        continue
    
    if db_room in baraka:
        rid = baraka[db_room]['id']
        result = api("PATCH", "rooms", data={"monthly_rent": rent}, params={"id": str(rid)})
        if result:
            print(f"  {db_room} → rent={rent}")

# Verify
print("\nVerification:")
rooms2 = api("GET", "rooms", params={"building_id": "2"})
occupied = [r for r in rooms2 if r['status'] == 'occupied']
void = [r for r in rooms2 if r['status'] == 'void']
print(f"  Occupied: {len(occupied)}")
print(f"  Void: {len(void)}")
print(f"  Occupied rooms: {sorted([r['room_number'] for r in occupied])}")
