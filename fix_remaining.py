#!/usr/bin/env python3
"""Fix remaining skipped tenants."""

import csv
import re
import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

ARABIC_MONTHS = {
    "يناير": 1, "فبراير": 2, "مارس": 3, "ابريل": 4,
    "مايو": 5, "يونيه": 6, "يوليو": 7, "اغسطس": 8,
    "سبتمبر": 9, "اكتوبر": 10, "نوفمبر": 11, "ديسمبر": 12,
}

def parse_arabic_date(s):
    s = s.strip()
    if not s:
        return None
    if s == "ايونيه":
        return (2026, 6, 1)
    # Try "22 مارس" (with space)
    m = re.match(r"(\d{1,2})\s+(.+)", s)
    if m:
        day = int(m.group(1))
        month = ARABIC_MONTHS.get(m.group(2).strip())
        if month:
            return (2026, month, day)
    # Try "7مايو" (no space)
    m = re.match(r"(\d{1,2})(.+)", s)
    if m:
        day = int(m.group(1))
        month = ARABIC_MONTHS.get(m.group(2).strip())
        if month:
            return (2026, month, day)
    return None

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

# ── Load all data ──────────────────────────────────────────────────
tenants = supabase_get("tenants", "id,name,room_id,payment_status,due_date")
rooms = supabase_get("rooms", "id,room_number,building_id,monthly_rent")

# Build room_id → room data map
room_data = {r["id"]: r for r in rooms}

# Build (building_id, room_number) → tenant map
room_to_tenant = {}
for t in tenants:
    r = room_data.get(t["room_id"])
    if r:
        room_to_tenant[(r["building_id"], r["room_number"])] = t

# ── Parse CSV ──────────────────────────────────────────────────────
csv_rows = []
with open("/mnt/c/Users/ahmed/Downloads/New folder/real_estate_rentals.csv", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        villa = row["فيلا"].strip()
        if villa not in ("الجوي", "البركه"):
            continue
        name = row["الاسم"].strip()
        room_code = row["رقم الغرفه"].strip()
        due_raw = row.get("من", "").strip()
        
        due_date = parse_arabic_date(due_raw)
        
        csv_rows.append({
            "name": name,
            "villa": villa,
            "room_code": room_code,
            "due_raw": due_raw,
            "due_date": due_date,
        })

# ── Match and update ──────────────────────────────────────────────
# Build name → tenant map
name_to_tenant = {}
for t in tenants:
    name_to_tenant[t["name"].strip()] = t

# Also need building_id for each villa
# Gawy = building 1, Baraka = building 2 (from earlier analysis)
VILLA_TO_BLD = {"الجوي": 1, "البركه": 2}

updated = 0
skipped = 0
errors = []

for r in csv_rows:
    if not r["due_date"]:
        skipped += 1
        errors.append(f"SKIP (no date): {r['name']} → {r['due_raw']}")
        continue
    
    due_str = f"{r['due_date'][0]}-{r['due_date'][1]:02d}-{r['due_date'][2]:02d}"
    
    # Try 1: exact name match
    match = name_to_tenant.get(r["name"].strip())
    
    # Try 2: fuzzy name match
    if not match:
        for t in tenants:
            if r["name"].strip() in t["name"].strip() or t["name"].strip() in r["name"].strip():
                match = t
                break
    
    # Try 3: match by (building_id, room_number)
    if not match:
        bld_id = VILLA_TO_BLD.get(r["villa"])
        if r["villa"] == "البركه":
            num = r["room_code"][:-1]
            floor = r["room_code"][-2].upper()
            room_num = f"B{num}{floor}"
        else:
            room_num = r["room_code"][:-1]
        
        match = room_to_tenant.get((bld_id, room_num))
    
    if not match:
        skipped += 1
        errors.append(f"SKIP (not found): {r['name']} | {r['villa']} | {r['room_code']}")
        continue
    
    # Update
    tenant_id = match["id"]
    status = supabase_patch(
        "tenants",
        f"id=eq.{tenant_id}",
        {"due_date": due_str, "payment_status": "paid"}
    )
    
    if status in (200, 204):
        updated += 1
        print(f"✓ {r['name']} → due: {due_str}, paid (DB: {match['name']})")
    else:
        errors.append(f"ERROR updating {r['name']}: HTTP {status}")

print(f"\n{'='*60}")
print(f"Updated: {updated} | Skipped: {skipped}")
if errors:
    print(f"\nSkipped/Errors:")
    for e in errors:
        print(f"  {e}")
