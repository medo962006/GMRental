#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Clean up partial import and re-run"""
import urllib.request, json, time

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# Delete ALL Baraka tenants (clean slate)
req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/tenants?building_id=eq.2", headers=HEADERS, method="GET")
with urllib.request.urlopen(req, timeout=30) as res:
    tenants = json.loads(res.read())
    print(f"Found {len(tenants)} Baraka tenants to delete")

for t in tenants:
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/tenants?id=eq.{t['id']}", headers=HEADERS, method="DELETE")
    try:
        urllib.request.urlopen(req, timeout=30)
    except: pass

print("Deleted all Baraka tenants")

# Also reset room statuses to void for rooms that should be void
req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/rooms?building_id=eq.2&status=eq.occupied&select=id,room_number", headers=HEADERS, method="GET")
with urllib.request.urlopen(req, timeout=30) as res:
    occupied = json.loads(res.read())
    print(f"Resetting {len(occupied)} occupied rooms to void...")

for r in occupied:
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/rooms?id=eq.{r['id']}", 
        data=json.dumps({"status": "void"}).encode(),
        headers=HEADERS, method="PATCH")
    try:
        urllib.request.urlopen(req, timeout=30)
    except: pass

print("Done - all Baraka data cleaned")
