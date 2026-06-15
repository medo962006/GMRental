#!/usr/bin/env python3
"""Setup Baraka building data in Supabase."""
import json, urllib.request, urllib.error

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
API_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

HEADERS = {
    "apikey": API_KEY,
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def api_get(table, params="?select=*"):
    url = f"{SUPABASE_URL}/rest/v1/{table}{params}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as res:
        return json.loads(res.read())

def api_post(table, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code}: {e.read().decode()}")
        raise

def api_patch(table, id_col, id_val, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{id_col}=eq.{id_val}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="PATCH")
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code}: {e.read().decode()}")

def main():
    print("═══ Baraka Building Database Setup ═══\n")

    # 1. Update all existing rooms to building_id=1
    print("Step 1: Setting building_id=1 on existing rooms...")
    rooms = api_get("rooms")
    for r in rooms:
        api_patch("rooms", "id", r["id"], {"building_id": 1})
    print(f"  Updated {len(rooms)} rooms.\n")

    # 2. Check if Baraka rooms exist
    all_rooms = api_get("rooms", "?select=id,room_number,building_id")
    baraka = [r for r in all_rooms if r.get("building_id") == 2]
    if baraka:
        print(f"Baraka already has {len(baraka)} rooms. Delete them first to re-create.\n")
        return

    # 3. Create Baraka rooms (18 rooms: 6 per floor, G/F/S)
    print("Step 2: Creating Baraka rooms...")
    baraka_rooms = [
        # Ground floor
        {"room_number": "B1G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
        {"room_number": "B2G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
        {"room_number": "B3G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
        {"room_number": "B4G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
        {"room_number": "B5G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
        {"room_number": "B6G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
        # First floor
        {"room_number": "B1F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
        {"room_number": "B2F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
        {"room_number": "B3F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
        {"room_number": "B4F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
        {"room_number": "B5F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
        {"room_number": "B6F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
        # Second floor
        {"room_number": "B1S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
        {"room_number": "B2S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
        {"room_number": "B3S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
        {"room_number": "B4S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
        {"room_number": "B5S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
        {"room_number": "B6S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
    ]
    created_rooms = api_post("rooms", baraka_rooms)
    print(f"  Created {len(created_rooms)} rooms.\n")

    # Build room number -> id map
    room_map = {r["room_number"]: r["id"] for r in created_rooms}

    # 4. Create sample Baraka tenants
    print("Step 3: Creating Baraka tenants...")
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    tenants = [
        {"name": "أحمد محمد", "phone": "010-12345678", "gender": "male",
         "room_id": room_map["B1G"], "building_id": 2, "status": "active",
         "insurance_amount": 5000, "insurance_returned": False, "payment_status": "unpaid",
         "due_date": "2026-07-01", "lease_start_date": "2026-06-15", "created_at": now},
        {"name": "محمد علي", "phone": "011-23456789", "gender": "male",
         "room_id": room_map["B2G"], "building_id": 2, "status": "active",
         "insurance_amount": 5000, "insurance_returned": False, "payment_status": "paid",
         "due_date": "2026-07-01", "lease_start_date": "2026-06-10", "created_at": now},
        {"name": "سارة أحمد", "phone": "012-34567890", "gender": "female",
         "room_id": room_map["B1F"], "building_id": 2, "status": "active",
         "insurance_amount": 6000, "insurance_returned": False, "payment_status": "unpaid",
         "due_date": "2026-07-05", "lease_start_date": "2026-06-01", "created_at": now},
        {"name": "خالد إبراهيم", "phone": "015-45678901", "gender": "male",
         "room_id": room_map["B1S"], "building_id": 2, "status": "active",
         "insurance_amount": 7000, "insurance_returned": False, "payment_status": "unpaid",
         "due_date": "2026-07-10", "lease_start_date": "2026-05-20", "created_at": now},
    ]
    created_tenants = api_post("tenants", tenants)
    print(f"  Created {len(created_tenants)} tenants.\n")

    # 5. Create insurance ledger for Baraka
    print("Step 4: Creating Baraka insurance ledger...")
    insurance = [
        {"tenant_id": created_tenants[0]["id"], "total_agreed_amount": 5000,
         "amount_paid_so_far": 2000, "due_date_for_remaining": "2026-08-01", "status": "partial"},
        {"tenant_id": created_tenants[2]["id"], "total_agreed_amount": 6000,
         "amount_paid_so_far": 0, "due_date_for_remaining": "2026-07-15", "status": "partial"},
    ]
    api_post("insurance_ledger", insurance)
    print(f"  Created {len(insurance)} insurance records.\n")

    # Summary
    print("═══ Setup Complete ═══")
    final_rooms = api_get("rooms", "?select=building_id")
    main_r = sum(1 for r in final_rooms if r.get("building_id") == 1)
    baraka_r = sum(1 for r in final_rooms if r.get("building_id") == 2)
    print(f"Main Building: {main_r} rooms")
    print(f"Baraka:        {baraka_r} rooms")
    all_tenants = api_get("tenants", "?select=building_id")
    main_t = sum(1 for t in all_tenants if t.get("building_id") == 1)
    baraka_t = sum(1 for t in all_tenants if t.get("building_id") == 2)
    print(f"Main Building: {main_t} tenants")
    print(f"Baraka:        {baraka_t} tenants")

if __name__ == "__main__":
    main()
