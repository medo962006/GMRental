#!/usr/bin/env python3
"""Full database setup for Baraka building using Supabase service role key."""
import json, urllib.request, urllib.error

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma3ltb2ltdGpnYWZ2YmNsbnF5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM1OTg2MiwiZXhwIjoyMDk2OTM1ODYyfQ.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"
ANON_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

SVC_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

ANON_HEADERS = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def api_get(table, params="?select=*", headers=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}{params}"
    req = urllib.request.Request(url, headers=headers or ANON_HEADERS)
    with urllib.request.urlopen(req) as res:
        return json.loads(res.read())

def api_post(table, data, headers=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    body = json.dumps(data).encode()
    h = headers or ANON_HEADERS
    req = urllib.request.Request(url, data=body, headers=h, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code}: {e.read().decode()}")
        raise

def api_patch(table, id_col, id_val, data, headers=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{id_col}=eq.{id_val}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=headers or ANON_HEADERS, method="PATCH")
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code}: {e.read().decode()}")

def run_sql(query):
    """Execute SQL via pg-meta endpoint with service role key."""
    url = f"{SUPABASE_URL}/pg/query"
    body = json.dumps({"query": query}).encode()
    req = urllib.request.Request(url, data=body, headers=SVC_HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            result = json.loads(res.read())
            print(f"  SQL OK: {query[:60]}...")
            return result
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  SQL ERROR {e.code}: {err}")
        # Try alternative: /rest/v1/rpc
        return None

def main():
    print("═══ Baraka Building Full Database Setup ═══\n")

    # ════════════════════════════════════════════
    # STEP 1: Add building_id column via SQL
    # ════════════════════════════════════════════
    print("Step 1: Adding building_id columns...")
    
    # Try pg/query first
    result = run_sql("ALTER TABLE IF NOT EXISTS rooms ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1")
    if result is None:
        # Fallback: try the SQL editor endpoint
        print("  Trying alternative SQL endpoint...")
        url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
        body = json.dumps({"query": "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1"}).encode()
        req = urllib.request.Request(url, data=body, headers=SVC_HEADERS, method="POST")
        try:
            with urllib.request.urlopen(req) as res:
                print(f"  exec_sql OK")
        except urllib.error.HTTPError as e:
            print(f"  exec_sql ERROR: {e.read().decode()}")
            print("\n⚠ Cannot run DDL via API. Please run this SQL manually in Supabase SQL Editor:")
            print("""
  ALTER TABLE rooms ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1;
  ALTER TABLE tenants ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1;
  UPDATE rooms SET building_id = 1 WHERE building_id IS NULL;
  UPDATE tenants SET building_id = 1 WHERE building_id IS NULL;
""")
            return

    run_sql("ALTER TABLE IF NOT EXISTS tenants ADD COLUMN IF NOT EXISTS building_id INTEGER DEFAULT 1")
    run_sql("UPDATE rooms SET building_id = 1 WHERE building_id IS NULL")
    run_sql("UPDATE tenants SET building_id = 1 WHERE building_id IS NULL")
    print()

    # ════════════════════════════════════════════
    # STEP 2: Create Baraka rooms
    # ════════════════════════════════════════════
    print("Step 2: Creating Baraka rooms...")
    
    # Check if Baraka rooms already exist
    all_rooms = api_get("rooms", "?select=id,room_number,building_id")
    baraka_exists = [r for r in all_rooms if r.get("building_id") == 2]
    if baraka_exists:
        print(f"  Baraka already has {len(baraka_exists)} rooms. Skipping.\n")
        created_rooms = baraka_exists
    else:
        baraka_rooms = [
            {"room_number": "B1G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
            {"room_number": "B2G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
            {"room_number": "B3G", "status": "void", "monthly_rent": 8000, "building_id": 2, "floor": "G"},
            {"room_number": "B4G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
            {"room_number": "B5G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
            {"room_number": "B6G", "status": "void", "monthly_rent": 8500, "building_id": 2, "floor": "G"},
            {"room_number": "B1F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
            {"room_number": "B2F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
            {"room_number": "B3F", "status": "void", "monthly_rent": 9000, "building_id": 2, "floor": "F"},
            {"room_number": "B4F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
            {"room_number": "B5F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
            {"room_number": "B6F", "status": "void", "monthly_rent": 9500, "building_id": 2, "floor": "F"},
            {"room_number": "B1S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
            {"room_number": "B2S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
            {"room_number": "B3S", "status": "void", "monthly_rent": 10000, "building_id": 2, "floor": "S"},
            {"room_number": "B4S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
            {"room_number": "B5S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
            {"room_number": "B6S", "status": "void", "monthly_rent": 10500, "building_id": 2, "floor": "S"},
        ]
        created_rooms = api_post("rooms", baraka_rooms)
        print(f"  Created {len(created_rooms)} Baraka rooms.\n")

    # Build room number -> id map
    room_map = {r["room_number"]: r["id"] for r in created_rooms}

    # ════════════════════════════════════════════
    # STEP 3: Create Baraka tenants
    # ════════════════════════════════════════════
    print("Step 3: Creating Baraka tenants...")
    
    existing_tenants = api_get("tenants", "?select=id,building_id")
    baraka_tenants_exist = [t for t in existing_tenants if t.get("building_id") == 2]
    if baraka_tenants_exist:
        print(f"  Baraka already has {len(baraka_tenants_exist)} tenants. Skipping.\n")
        created_tenants = baraka_tenants_exist
    else:
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
        print(f"  Created {len(created_tenants)} Baraka tenants.\n")

    # ════════════════════════════════════════════
    # STEP 4: Create insurance ledger
    # ════════════════════════════════════════════
    print("Step 4: Creating Baraka insurance ledger...")
    existing_insurance = api_get("insurance_ledger", "?select=id")
    if len(existing_insurance) > 1:  # already has the main one + baraka ones
        print("  Insurance records already exist. Skipping.\n")
    else:
        insurance = [
            {"tenant_id": created_tenants[0]["id"], "total_agreed_amount": 5000,
             "amount_paid_so_far": 2000, "due_date_for_remaining": "2026-08-01", "status": "partial"},
            {"tenant_id": created_tenants[2]["id"], "total_agreed_amount": 6000,
             "amount_paid_so_far": 0, "due_date_for_remaining": "2026-07-15", "status": "partial"},
        ]
        api_post("insurance_ledger", insurance)
        print(f"  Created {len(insurance)} insurance records.\n")

    # ════════════════════════════════════════════
    # SUMMARY
    # ════════════════════════════════════════════
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
