#!/usr/bin/env python3
"""Parse CSV, write due_dates.txt, and update Supabase tenants."""

import csv
import re
import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

# Arabic month name → number
ARABIC_MONTHS = {
    "يناير": 1, "فبراير": 2, "مارس": 3, "ابريل": 4,
    "مايو": 5, "يونيه": 6, "يوليو": 7, "اغسطس": 8,
    "سبتمبر": 9, "اكتوبر": 10, "نوفمبر": 11, "ديسمبر": 12,
}

def parse_arabic_date(s):
    """Parse '22 مارس' → (2026, 3, 22). Returns None if unparseable."""
    s = s.strip()
    if not s:
        return None
    # Handle 'ايونيه' (June, no day) → use day 1
    if s == "ايونيه":
        return (2026, 6, 1)
    m = re.match(r"(\d{1,2})\s+(.+)", s)
    if not m:
        return None
    day = int(m.group(1))
    month_name = m.group(2).strip()
    month = ARABIC_MONTHS.get(month_name)
    if not month:
        return None
    return (2026, month, day)

def csv_to_room_number(villa, room_code):
    """Convert CSV room code to DB room number."""
    # Remove trailing 'b' for Baraka, 'g'/'f'/'s' for Gawy
    if villa == "البركه":
        # e.g. '7gb' → 'B7G', '5fb' → 'B5F', '1sb' → 'B1S'
        num = room_code[:-1]  # strip 'b'
        floor_letter = room_code[-2].upper()  # 'g', 'f', 's'
        return f"B{num}{floor_letter}"
    else:  # الجوي
        # e.g. '2gg' → '2g', '10fg' → '10f', '7sg' → '7s'
        # Last char is floor: g/f/s
        return room_code[:-1]  # strip last letter (duplicate)

# ── Step 1: Parse CSV ──────────────────────────────────────────────
rows = []
with open("/mnt/c/Users/ahmed/Downloads/New folder/real_estate_rentals.csv", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        villa = row["فيلا"].strip()
        if villa not in ("الجوي", "البركه"):
            continue
        name = row["الاسم"].strip()
        room_code = row["رقم الغرفه"].strip()
        due_raw = row.get("من", "").strip()
        
        room_number = csv_to_room_number(villa, room_code)
        due_date = parse_arabic_date(due_raw)
        
        rows.append({
            "name": name,
            "villa": villa,
            "room_number": room_number,
            "due_raw": due_raw,
            "due_date": due_date,
        })

# ── Step 2: Write due_dates.txt ───────────────────────────────────
lines = []
for r in rows:
    due_str = f"{r['due_date'][0]}-{r['due_date'][1]:02d}-{r['due_date'][2]:02d}" if r['due_date'] else "NO_DATE"
    lines.append(f"{r['name']} | {r['villa']} | {r['room_number']} | due: {due_str} | raw: {r['due_raw']}")

with open(r"C:\Users\ahmed\GMRental\hostel_management\due_dates.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"Written {len(lines)} lines to due_dates.txt")

# ── Step 3: Fetch all tenants from Supabase ───────────────────────
def supabase_get(table, select="*", params=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select={select}"
    if params:
        url += "&" + "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

def supabase_patch(table, filters, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{filters}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, method="PATCH", headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.read().decode()}")
        return e.code

tenants = supabase_get("tenants", "id,name,room_id,payment_status,due_date")
rooms = supabase_get("rooms", "id,room_number,building_id")

# Build room_number → room_id map
room_map = {r["room_number"]: r["id"] for r in rooms}

# ── Step 4: Match and update ──────────────────────────────────────
updated = 0
skipped = 0
errors = []

for r in rows:
    if not r["due_date"]:
        skipped += 1
        errors.append(f"SKIP (no date): {r['name']} → {r['due_raw']}")
        continue
    
    due_str = f"{r['due_date'][0]}-{r['due_date'][1]:02d}-{r['due_date'][2]:02d}"
    
    # Match by name
    match = None
    for t in tenants:
        if t["name"].strip() == r["name"].strip():
            match = t
            break
    
    if not match:
        # Fuzzy: check if name is contained
        for t in tenants:
            if r["name"].strip() in t["name"].strip() or t["name"].strip() in r["name"].strip():
                match = t
                break
    
    if not match:
        skipped += 1
        errors.append(f"SKIP (not in DB): {r['name']} | {r['villa']} | {r['room_number']}")
        continue
    
    # Update due_date and mark paid
    tenant_id = match["id"]
    status = supabase_patch(
        "tenants",
        f"id=eq.{tenant_id}",
        {"due_date": due_str, "payment_status": "paid"}
    )
    
    if status in (200, 204):
        updated += 1
        print(f"✓ {r['name']} → due: {due_str}, paid")
    else:
        errors.append(f"ERROR updating {r['name']}: HTTP {status}")

print(f"\n{'='*60}")
print(f"Updated: {updated} | Skipped: {skipped}")
if errors:
    print(f"\nSkipped/Errors:")
    for e in errors:
        print(f"  {e}")
