#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Baraka CSV Import — Arabic format (2026-06-16)
Columns: الاسم, ارقام التليفونات, الجنسية, رقم الغرفة, قيمة الايجار الشهري,
        قيمة التأمين, مدة عقد الايجار, تاريخ بداية الايجار,
        ايجار شهر يناير, ايجار شهر فبراير, ايجار شهر مارس,
        ايجار شهر ابريل, ايجار شهر مايو, ايجار شهر يونيو
"""
import json, urllib.request, re, time, sys, io
from datetime import datetime, timezone

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
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
        except Exception as e:
            if attempt < retries - 1:
                time.sleep((attempt + 1) * 2)
            else:
                print(f"  FAILED {method} {path}: {e}")
                return []

def parse_room(raw):
    """Parse '7g', '4f', '1R+2R', '4 g' → (db_room_number, floor_char) or (None, None)"""
    raw = raw.strip().lower().replace(' ', '')
    if '+' in raw:
        raw = raw.split('+')[0].strip()
    m = re.match(r'(\d+)([gfstr])', raw)
    if not m:
        return None, None
    num = int(m.group(1))
    fc = m.group(2).upper()
    # CSV uses R for roof, DB uses T
    db_floor = 'T' if fc == 'R' else fc
    return f"B{num}{db_floor}", fc

def parse_amount(raw):
    """Parse '8,000.00' or '' or '0.00' → float"""
    if not raw or not raw.strip() or raw.strip() in ('-',):
        return 0.0
    try:
        return float(raw.replace(',', '').strip())
    except ValueError:
        return 0.0

def parse_arabic_date(raw):
    """Parse '22 ديسمبر' → ISO date string"""
    if not raw or not raw.strip():
        return None
    arabic_months = {
        'يناير': 1, 'فبراير': 2, 'مارس': 3, 'ابريل': 4,
        'مايو': 5, 'يونيه': 6, 'يونيو': 6, 'يوليو': 7,
        'اغسطس': 8, 'سبتمبر': 9, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
    }
    parts = raw.strip().split()
    if len(parts) >= 2:
        try:
            day = int(parts[0])
            month = arabic_months.get(parts[1])
            if month:
                return f"2026-{month:02d}-{min(day, 28):02d}"
        except (ValueError, IndexError):
            pass
    return None

def determine_payment(row):
    """Check monthly rent columns — if most have amounts → paid, else unpaid"""
    paid = 0
    total = 0
    for key in ['jan', 'feb', 'mar', 'apr', 'may', 'jun']:
        val = parse_amount(row.get(key, ''))
        if val > 0:
            paid += 1
            total += 1
        elif row.get(key, '').strip() in ('', '-'):
            pass  # not yet due
        else:
            total += 1  # has some content but 0
    if total == 0:
        return 'unpaid'
    return 'paid' if paid > total * 0.5 else 'unpaid'

def main():
    print("═══ Baraka CSV Import (Arabic Format) ═══\n")

    # 1. Fetch Baraka rooms
    print("Step 1: Fetching Baraka rooms...")
    all_rooms = api("GET", "rooms")
    baraka = {r['room_number']: r for r in all_rooms if r.get('building_id') == 2}
    print(f"  {len(baraka)} Baraka rooms in DB\n")

    # 2. Delete old Baraka tenants
    print("Step 2: Deleting old Baraka tenants...")
    old = api("GET", "tenants", params={"building_id": "2"})
    for t in old:
        api("DELETE", "tenants", params={"id": t['id']})
    print(f"  Deleted {len(old)}\n")

    # 3. Parse CSV
    print("Step 3: Parsing CSV...")
    csv_path = "C:\\Users\\ahmed\\GMRental\\hostel_management\\scripts\\baraka_data_new.csv"
    with open(csv_path, 'r', encoding='utf-8') as f:
        lines = f.read().strip().split('\n')

    now = datetime.now(timezone.utc).isoformat()
    tenants = []
    room_updates = {}
    skipped = 0

    for i, line in enumerate(lines[1:], 2):
        # Simple CSV parse (no quoted fields with commas in this data)
        parts = line.split(',')
        if len(parts) < 8:
            skipped += 1
            continue

        name = parts[0].strip()
        phone = parts[1].strip()
        nationality = parts[2].strip()
        room_raw = parts[3].strip()

        if not name or not room_raw:
            skipped += 1
            continue

        db_room, floor_char = parse_room(room_raw)
        if not db_room:
            print(f"  Line {i}: Cannot parse room '{room_raw}', skipping")
            skipped += 1
            continue

        rent = parse_amount(parts[4]) if len(parts) > 4 else 0
        insurance = parse_amount(parts[5]) if len(parts) > 5 else 0
        lease_start = parse_arabic_date(parts[7]) if len(parts) > 7 else None

        # Monthly rent columns (8-13)
        monthly = {
            'jan': parts[8].strip() if len(parts) > 8 else '',
            'feb': parts[9].strip() if len(parts) > 9 else '',
            'mar': parts[10].strip() if len(parts) > 10 else '',
            'apr': parts[11].strip() if len(parts) > 11 else '',
            'may': parts[12].strip() if len(parts) > 12 else '',
            'jun': parts[13].strip() if len(parts) > 13 else '',
        }
        payment_status = determine_payment(monthly)

        # Clean phone — DB requires NOT NULL and VARCHAR(20)
        # Some CSV rows have multiple phones like "010-0230038/011-11756122"
        # Take first phone number and truncate to 20 chars
        phone_clean = re.sub(r'[^\d]', '', phone)
        if not phone_clean:
            phone_clean = '0000000000'  # placeholder for unknown
        # Take first 11 digits (Egyptian mobile) or truncate to 20
        if len(phone_clean) > 20:
            phone_clean = phone_clean[:11]  # take first mobile number

        # Gender — DB allows only 'male', 'female', or null
        gender = None
        female_names = ['نادين', 'منال', 'سلوى', 'جمانه', 'يارا', 'ملك', 'فاطمه', 'سلمي', 'سلوي', 'خيمتونج']
        if any(fn in name for fn in female_names):
            gender = 'female'
        else:
            gender = 'male'

        # Find or create room
        if db_room in baraka:
            room_id = baraka[db_room]['id']
        else:
            result = api("POST", "rooms", data={
                "room_number": db_room,
                "building_id": 2,
                "status": "occupied",
                "monthly_rent": rent if rent > 0 else 8000,
                "floor": 'T' if floor_char == 'R' else floor_char,
            })
            if result:
                room_id = result[0]['id']
                baraka[db_room] = result[0]
                print(f"  Created room {db_room}")
            else:
                skipped += 1
                continue

        if rent > 0:
            room_updates[room_id] = {'monthly_rent': rent, 'status': 'occupied'}

        # Due date = lease_start + 1 month
        due_date = None
        if lease_start:
            dt = datetime.strptime(lease_start, "%Y-%m-%d")
            m = dt.month + 1
            y = dt.year
            if m > 12:
                m = 1
                y += 1
            due_date = f"{y}-{m:02d}-{dt.day:02d}"

        tenants.append({
            'name': name,
            'phone': phone_clean,
            'gender': gender,
            'room_id': room_id,
            'building_id': 2,
            'status': 'active',
            'insurance_amount': insurance,
            'insurance_returned': False,
            'payment_status': payment_status,
            'due_date': due_date,
            'lease_start_date': lease_start,
            'created_at': now,
        })

    print(f"  Parsed {len(tenants)} tenants, skipped {skipped}\n")

    # 4. Update rooms
    print("Step 4: Updating rooms...")
    for rid, data in room_updates.items():
        api("PATCH", "rooms", data=data, params={"id": str(rid)})
    print(f"  Updated {len(room_updates)} rooms\n")

    # 5. Insert tenants
    print("Step 5: Inserting tenants...")
    created = 0
    for i in range(0, len(tenants), 10):
        batch = tenants[i:i+10]
        result = api("POST", "tenants", data=batch)
        created += len(result)
        time.sleep(0.3)
    print(f"  Inserted {created}\n")

    # 6. Verify
    print("═══ Verification ═══")
    final_rooms = api("GET", "rooms", params={"building_id": "2"})
    final_tenants = api("GET", "tenants", params={"building_id": "2"})
    void = [r for r in final_rooms if r['status'] == 'void']
    occ = [r for r in final_rooms if r['status'] == 'occupied']
    print(f"  Rooms: {len(final_rooms)} ({len(occ)} occupied, {len(void)} void)")
    print(f"  Tenants: {len(final_tenants)}")
    void_nums = sorted([r['room_number'] for r in void])
    print(f"  Void: {', '.join(void_nums)}")
    print("\n  Sample:")
    for t in final_tenants[:5]:
        room = next((r for r in final_rooms if r['id'] == t['room_id']), None)
        rn = room['room_number'] if room else '?'
        print(f"    {t['name']} → {rn} ({t['payment_status']})")
    print("\n═══ Done ═══")

if __name__ == "__main__":
    main()
