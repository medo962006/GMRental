#!/usr/bin/env python3
"""Import Baraka CSV - final version with batching and retries."""
import json, urllib.request, urllib.error, re, time
from datetime import datetime, timezone

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma3ltb2ltdGpnYWZ2YmNsbnF5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM1OTg2MiwiZXhwIjoyMDk2OTM1ODYyfQ.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def api(method, path, data=None, params=None, retries=3):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    if params:
        url += "?" + "&".join(f"{k}=eq.{v}" for k, v in params.items())
    body = json.dumps(data).encode() if data else None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
            with urllib.request.urlopen(req, timeout=30) as res:
                raw = res.read()
                return json.loads(raw) if raw else []
        except (urllib.error.URLError, ConnectionResetError, TimeoutError) as e:
            if attempt < retries - 1:
                wait = (attempt + 1) * 2
                print(f"  retry {attempt+1}/{retries} after {wait}s: {e}")
                time.sleep(wait)
            else:
                print(f"  FAILED {method} {path}: {e}")
                return []
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print(f"  ERR {e.code} {path}: {err[:80]}")
            return []

def main():
    print("═══ Baraka CSV Import (Final) ═══\n")

    # 1. Fetch rooms
    print("Step 1: Fetching rooms...")
    rooms = api("GET", "rooms")
    baraka = {r['room_number']: r for r in rooms if r.get('building_id') == 2}
    print(f"  {len(baraka)} Baraka rooms\n")

    # 2. Delete old Baraka tenants
    print("Step 2: Deleting old Baraka tenants...")
    old = api("GET", "tenants", params={"building_id": "2"})
    for t in old:
        api("DELETE", "tenants", params={"id": t['id']})
    print(f"  Deleted {len(old)}\n")

    # 3. Parse CSV
    print("Step 3: Parsing CSV...")
    FLOOR = {'Ground floor': 'G', 'First floor': 'F', 'Second floor': 'S', 'Roof': 'T'}
    FEMALE = ['سلمى', 'نادين', 'منال', 'سلوى', 'جمانه', 'يارا', 'ملك', 'السودانية', 'العقيد']

    with open("/mnt/c/Users/ahmed/GMRental/hostel_management/scripts/baraka_data.csv", 'r') as f:
        lines = f.read().strip().split('\n')

    now = datetime.now(timezone.utc).isoformat()
    tenants = []
    room_updates = {}

    for line in lines[1:]:
        parts = line.split(',')
        while len(parts) > 11:
            parts[3] += ',' + parts[4]
            parts.pop(4)
        if len(parts) < 11:
            parts += [''] * (11 - len(parts))

        csv_room, floor, status, name = [p.strip() for p in parts[:4]]
        rent_str, day_str, phone = [p.strip() for p in parts[4:7]]
        payment = parts[10].strip() if len(parts) > 10 else ''

        m = re.match(r'Room (\d+)(-*)', csv_room)
        if not m:
            continue

        fc = FLOOR.get(floor, 'G')
        db_num = f'B{m.group(1)}{fc}'

        if db_num not in baraka:
            continue

        rid = baraka[db_num]['id']
        rent = int(rent_str) if rent_str not in ('-', '', '0') else 0
        room_updates[rid] = {
            'status': 'occupied' if status == 'Occupied' else 'void',
            'monthly_rent': rent if rent > 0 else baraka[db_num].get('monthly_rent', 8000),
        }

        if status != 'Occupied' or not name:
            continue

        day = int(day_str) if day_str not in ('-', '') else 1
        gender = 'female' if any(f in name for f in FEMALE) else 'male'
        phone_clean = phone.lstrip('+') if phone else ''
        pstatus = 'paid' if payment.lower() == 'paid' else 'unpaid'

        tenants.append({
            'name': name,
            'phone': phone_clean,
            'gender': gender,
            'room_id': rid,
            'building_id': 2,
            'status': 'active',
            'insurance_amount': 0,
            'insurance_returned': False,
            'payment_status': pstatus,
            'due_date': f"2026-07-{day:02d}",
            'created_at': now,
        })

    print(f"  {len(tenants)} tenants to insert\n")

    # 4. Batch update rooms - use bulk patch via PostgREST
    print("Step 4: Updating rooms in bulk...")
    # Update all Baraka rooms in fewer calls - batch by floor
    batch_data = []
    for rid, data in room_updates.items():
        batch_data.append({**data, 'id': rid})
    
    # Send as bulk upsert
    result = api("POST", "rooms", data=batch_data)
    if not result:
        # Fallback: update with individual patches but with delay
        print("  Bulk update failed, using individual patches...")
        for rid, data in room_updates.items():
            api("PATCH", "rooms", data=data, params={"id": str(rid)})
            time.sleep(0.1)
    print(f"  Updated {len(room_updates)} rooms\n")

    # 5. Insert tenants in batches of 10
    print("Step 5: Inserting tenants...")
    created = 0
    for i in range(0, len(tenants), 10):
        batch = tenants[i:i+10]
        result = api("POST", "tenants", data=batch)
        created += len(result)
        time.sleep(0.5)
    print(f"  Inserted {created} tenants\n")

    # Summary
    print("═══ Done ═══")
    final_rooms = api("GET", "rooms", params={"building_id": "2"})
    final_tenants = api("GET", "tenants", params={"building_id": "2"})
    print(f"Baraka: {len(final_rooms)} rooms, {len(final_tenants)} tenants")

if __name__ == "__main__":
    main()
