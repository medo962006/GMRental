#!/usr/bin/env python3
"""Create Baraka tenants and insurance records using service role key."""
import json, urllib.request, urllib.error
from datetime import datetime, timezone

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma3ltb2ltdGpnYWZ2YmNsbnF5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM1OTg2MiwiZXhwIjoyMDk2OTM1ODYyfQ.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def api_get(table, params="?select=*"):
    url = f"{SUPABASE_URL}/rest/v1/{table}{params}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  GET {table} ERROR {e.code}: {err}")
        raise

def api_post(table, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"  POST {table} ERROR {e.code}: {e.read().decode()}")
        raise

def main():
    print("═══ Baraka Data Setup ═══\n")

    # 1. Get all rooms (select * to avoid schema cache issue)
    print("Step 1: Fetching rooms...")
    all_rooms = api_get("rooms")
    print(f"  Total rooms: {len(all_rooms)}")
    print(f"  Sample room keys: {list(all_rooms[0].keys())}")
    
    # Check if building_id exists in the data
    has_building_id = "building_id" in all_rooms[0]
    print(f"  building_id column visible: {has_building_id}")
    
    if has_building_id:
        baraka_rooms = [r for r in all_rooms if r.get("building_id") == 2]
    else:
        # Column not visible via API yet — check by room_number prefix
        baraka_rooms = [r for r in all_rooms if str(r.get("room_number", "")).startswith("B")]
    
    print(f"  Baraka rooms found: {len(baraka_rooms)}")
    if not baraka_rooms:
        print("\n⚠ No Baraka rooms found. Make sure you ran the full SQL including:")
        print("  ALTER TABLE rooms ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1;")
        print("  INSERT INTO rooms (room_number, status, monthly_rent, building_id, floor) VALUES ...")
        return
    
    room_map = {r["room_number"]: r["id"] for r in baraka_rooms}
    print(f"  Room numbers: {list(room_map.keys())}\n")

    # 2. Create Baraka tenants
    print("Step 2: Creating Baraka tenants...")
    all_tenants = api_get("tenants")
    
    if "building_id" in all_tenants[0]:
        baraka_tenants = [t for t in all_tenants if t.get("building_id") == 2]
    else:
        baraka_tenants = []  # no tenants for baraka yet
    
    if baraka_tenants:
        print(f"  Baraka already has {len(baraka_tenants)} tenants. Skipping.\n")
        created_tenants = baraka_tenants
    else:
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
        print(f"  Created {len(created_tenants)} Baraka tenants.\n")

    # 3. Create insurance ledger
    print("Step 3: Creating Baraka insurance ledger...")
    existing_insurance = api_get("insurance_ledger")
    baraka_tenant_ids = {t["id"] for t in (baraka_tenants if baraka_tenants else created_tenants)}
    baraka_insurance = [i for i in existing_insurance if i.get("tenant_id") in baraka_tenant_ids]
    
    if baraka_insurance:
        print(f"  Baraka already has {len(baraka_insurance)} insurance records. Skipping.\n")
    else:
        insurance = [
            {"tenant_id": created_tenants[0]["id"], "total_agreed_amount": 5000,
             "amount_paid_so_far": 2000, "due_date_for_remaining": "2026-08-01", "status": "partial"},
            {"tenant_id": created_tenants[2]["id"], "total_agreed_amount": 6000,
             "amount_paid_so_far": 0, "due_date_for_remaining": "2026-07-15", "status": "partial"},
        ]
        api_post("insurance_ledger", insurance)
        print(f"  Created {len(insurance)} insurance records.\n")

    # Summary
    print("═══ Summary ═══")
    if has_building_id:
        main_r = sum(1 for r in all_rooms if r.get("building_id") == 1)
        baraka_r = sum(1 for r in all_rooms if r.get("building_id") == 2)
    else:
        main_r = sum(1 for r in all_rooms if not str(r.get("room_number","")).startswith("B"))
        baraka_r = len(baraka_rooms)
    print(f"Main Building: {main_r} rooms")
    print(f"Baraka:        {baraka_r} rooms")
    
    if "building_id" in all_tenants[0]:
        main_t = sum(1 for t in all_tenants if t.get("building_id") == 1)
        baraka_t = sum(1 for t in all_tenants if t.get("building_id") == 2)
    else:
        main_t = len(all_tenants)
        baraka_t = len(baraka_tenants) if baraka_tenants else len(created_tenants)
    print(f"Main Building: {main_t} tenants")
    print(f"Baraka:        {baraka_t} tenants")

if __name__ == "__main__":
    main()
