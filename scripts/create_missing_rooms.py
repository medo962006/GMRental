#!/usr/bin/env python3
"""Create all missing Baraka rooms from CSV data."""
import json, urllib.request, urllib.error, re

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma3ltb2ltdGpnYWZ2YmNsbnF5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM1OTg2MiwiZXhwIjoyMDk2OTM1ODYyfQ.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
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
        with urllib.request.urlopen(req, timeout=60) as res:
            raw = res.read()
            return json.loads(raw) if raw else []
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  ERR {e.code}: {err[:100]}")
        return []

def main():
    print("═══ Creating Missing Baraka Rooms ═══\n")

    # Get existing Baraka rooms
    rooms = api("GET", "rooms", params={"building_id": "2"})
    existing = {r['room_number'] for r in rooms}
    print(f"Existing Baraka rooms: {len(existing)}")

    # Parse CSV to find all needed rooms
    FLOOR = {'Ground floor': 'G', 'First floor': 'F', 'Second floor': 'S', 'Roof': 'T'}
    FLOOR_RENT = {
        'Ground floor': [10000, 8000, 9500, 12500, 10500, 9500, 8000, 9500, 10500, 12500, 8000, 8000, 9500],
        'First floor': [12000, 10000, 0, 7000, 9000, 9500, 0, 8000, 0, 10000, 11000, 10000, 10000, 0, 10000],
        'Second floor': [13500, 13000, 0, 0, 9000, 0, 9000, 9000, 0, 0, 0, 13000, 12000, 0],
        'Roof': [10000, 10000, 0, 12500],
    }

    with open("/mnt/c/Users/ahmed/GMRental/hostel_management/scripts/baraka_data.csv", 'r') as f:
        lines = f.read().strip().split('\n')

    needed = {}  # db_room_num -> {floor, status, rent}
    for line in lines[1:]:
        parts = line.split(',')
        while len(parts) > 11:
            parts[3] += ',' + parts[4]
            parts.pop(4)
        if len(parts) < 4:
            continue

        csv_room, floor, status = [p.strip() for p in parts[:3]]
        rent_str = parts[4].strip() if len(parts) > 4 else '0'

        m = re.match(r'Room (\d+)(-*)', csv_room)
        if not m:
            continue

        num = m.group(1)
        fc = FLOOR.get(floor, 'G')
        db_num = f'B{num}{fc}'

        if db_num in existing:
            continue

        rent = int(rent_str) if rent_str not in ('-', '', '0') else 8000
        needed[db_num] = {
            'room_number': db_num,
            'floor': fc,
            'status': 'occupied' if status == 'Occupied' else 'void',
            'monthly_rent': rent,
            'building_id': 2,
        }

    if not needed:
        print("No missing rooms to create!")
        return

    print(f"Missing rooms to create: {len(needed)}")
    for rn in sorted(needed.keys()):
        print(f"  {rn}")

    # Create in batches
    batch = list(needed.values())
    print(f"\nCreating {len(batch)} rooms...")
    result = api("POST", "rooms", data=batch)
    print(f"Created {len(result)} rooms")

    # Summary
    all_rooms = api("GET", "rooms", params={"building_id": "2"})
    print(f"\nBaraka now has {len(all_rooms)} rooms total")

if __name__ == "__main__":
    main()
