#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix Baraka room rents using proper CSV parsing"""
import urllib.request, json, csv, io

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

# Get Baraka rooms
rooms = api("GET", "rooms", params={"building_id": "2"})
room_map = {r['room_number']: r for r in rooms}

# Parse CSV with proper CSV reader
with open("C:\\Users\\ahmed\\GMRental\\hostel_management\\scripts\\baraka_data_new.csv", 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    
    fixed = 0
    for row in reader:
        if len(row) < 5:
            continue
        
        name = row[0].strip()
        room_raw = row[3].strip()
        rent_str = row[4].strip()
        
        if not name or not room_raw:
            continue
        
        # Parse room number
        import re
        raw = room_raw.lower().replace(' ', '')
        if '+' in raw:
            raw = raw.split('+')[0].strip()
        m = re.match(r'(\d+)([gfstr])', raw)
        if not m:
            continue
        
        num = int(m.group(1))
        fc = m.group(2).upper()
        db_floor = 'T' if fc == 'R' else fc
        db_room = f"B{num}{db_floor}"
        
        # Parse rent
        try:
            rent = float(rent_str.replace(',', ''))
        except:
            continue
        
        if db_room in room_map:
            rid = room_map[db_room]['id']
            result = api("PATCH", "rooms", data={"monthly_rent": rent}, params={"id": str(rid)})
            if result:
                fixed += 1
                print(f"  {db_room} ({name[:20]}) → rent={rent}")
            else:
                print(f"  FAILED {db_room}")

print(f"\nFixed {fixed} room rents")
