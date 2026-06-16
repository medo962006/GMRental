#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Final verification of Baraka data"""
import urllib.request, json, re

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

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
        return []

# Get all Baraka data
rooms = api("GET", "rooms", params={"building_id": "2"})
tenants = api("GET", "tenants", params={"building_id": "2"})

print(f"═══ Baraka Building Summary ═══")
print(f"Rooms: {len(rooms)}")
print(f"Tenants: {len(tenants)}")

occupied = [r for r in rooms if r['status'] == 'occupied']
void = [r for r in rooms if r['status'] == 'void']
print(f"Occupied rooms: {len(occupied)}")
print(f"Void rooms: {len(void)}")

# Show void room numbers (display format)
void_nums = sorted([r['room_number'].replace('B', '') for r in void])
print(f"\nVoid rooms ({len(void_nums)}): {', '.join(void_nums)}")

# Show all tenants with room numbers
print(f"\nAll tenants ({len(tenants)}):")
room_map = {r['id']: r for r in rooms}
for t in sorted(tenants, key=lambda x: x['name']):
    room = room_map.get(t['room_id'])
    rn = room['room_number'].replace('B', '') if room else '?'
    rent = room.get('monthly_rent', '?') if room else '?'
    print(f"  {t['name'][:30]:30s} → {rn:5s} (rent={rent}, {t['payment_status']}, gender={t.get('gender', '?')})")

# Check Gawy is untouched
gawy_rooms = api("GET", "rooms", params={"building_id": "1"})
gawy_tenants = api("GET", "tenants", params={"building_id": "1"})
print(f"\nGawy (untouched): {len(gawy_rooms)} rooms, {len(gawy_tenants)} tenants")
