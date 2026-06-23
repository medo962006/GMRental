#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Backfill Baraka tenant insurance_amount = room monthly_rent"""
import urllib.request, json

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

# Get all Baraka tenants
tenants = api("GET", "tenants", params={"building_id": "2"})
rooms = api("GET", "rooms", params={"building_id": "2"})
room_map = {r['id']: r for r in rooms}

print(f"Baraka: {len(tenants)} tenants, {len(rooms)} rooms\n")

updated = 0
for t in tenants:
    room = room_map.get(t['room_id'])
    if not room:
        continue
    
    room_rent = room.get('monthly_rent', 0)
    current_insurance = t.get('insurance_amount', 0)
    
    if current_insurance != room_rent:
        result = api("PATCH", "tenants",
                     data={"insurance_amount": room_rent},
                     params={"id": str(t['id'])})
        if result:
            updated += 1
            rn = room['room_number']
            print(f"  {t['name'][:25]:25s}  rn={rn:5s}  insurance: {current_insurance} → {room_rent}")

print(f"\nUpdated {updated} Baraka tenants' insurance amounts")
