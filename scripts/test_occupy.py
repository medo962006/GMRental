#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test: does anon key allow UPDATE on rooms?"""
import urllib.request, json

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# Get a void room
rooms = json.loads(urllib.request.urlopen(
    urllib.request.Request(f"{SUPABASE_URL}/rest/v1/rooms?status=eq.void&limit=1&select=id,room_number",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"}),
).read())

if not rooms:
    print("No void rooms found")
    exit()

room = rooms[0]
print(f"Testing update on room: {room['room_number']} (id={room['id']})")

# Try to update status to occupied
data = json.dumps({"status": "occupied"}).encode()
req = urllib.request.Request(
    f"{SUPABASE_URL}/rest/v1/rooms?id=eq.{room['id']}",
    data=data, headers=HEADERS, method="PATCH"
)
try:
    with urllib.request.urlopen(req, timeout=30) as res:
        result = json.loads(res.read())
        print(f"Update OK: {result}")
        
        # Revert back to void
        data2 = json.dumps({"status": "void"}).encode()
        req2 = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/rooms?id=eq.{room['id']}",
            data=data2, headers=HEADERS, method="PATCH"
        )
        with urllib.request.urlopen(req2, timeout=30) as res2:
            print(f"Revert OK: {json.loads(res2.read())}")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(f"UPDATE FAILED: {e.code} → {err}")

# Also test: insert a tenant with room_id that references a void room
print("\nTesting tenant insert with room_id...")
tenants_before = json.loads(urllib.request.urlopen(
    urllib.request.Request(f"{SUPABASE_URL}/rest/v1/tenants?select=id&limit=1",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"}),
).read())
print(f"Sample tenant: {tenants_before[0] if tenants_before else 'none'}")

tenant_data = {
    "name": "test_auto_occupy",
    "phone": "1234567890",
    "gender": "male",
    "room_id": room['id'],
    "building_id": 2,
    "status": "active",
    "insurance_amount": 8000,
    "insurance_returned": False,
    "payment_status": "paid",
    "due_date": "2026-07-01",
    "created_at": "2026-06-16T00:00:00+00:00",
}

td = json.dumps(tenant_data).encode()
req = urllib.request.Request(
    f"{SUPABASE_URL}/rest/v1/tenants",
    data=td, headers=HEADERS, method="POST"
)
try:
    with urllib.request.urlopen(req, timeout=30) as res:
        result = json.loads(res.read())
        new_id = result[0]['id']
        print(f"Tenant created: {new_id}")
        
        # Check if room is now occupied
        rn = json.loads(urllib.request.urlopen(
            urllib.request.Request(f"{SUPABASE_URL}/rest/v1/rooms?id=eq.{room['id']}&select=id,status,room_number",
                headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"}),
        ).read())
        print(f"Room status after tenant insert: {rn[0]['status']}")
        
        # Cleanup
        urllib.request.urlopen(urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/tenants?id=eq.{new_id}",
            headers=HEADERS, method="DELETE"
        ))
        print("Tenant deleted")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(f"Tenant insert FAILED: {e.code} → {err}")
