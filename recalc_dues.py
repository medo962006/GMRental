#!/usr/bin/env python3
"""Recalculate due dates as move-in date + 1 month.
The CSV 'من' column is the move-in date.
Due date = move-in + 1 month (first rent payment due).
Also: mark all tenants unpaid (user wants manual control)."""

import csv
import re
import json
import urllib.request
from datetime import datetime

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

ARABIC_MONTHS = {
    "يناير": 1, "فبراير": 2, "مارس": 3, "ابريل": 4,
    "مايو": 5, "يونيه": 6, "يوليو": 7, "اغسطس": 8,
    "سبتمبر": 9, "اكتوبر": 10, "نوفمبر": 11, "ديسمبر": 12,
}

def parse_arabic_date(s):
    """Parse Arabic date like '22 مارس' or '7مايو' → (year, month, day)"""
    s = s.strip()
    if not s:
        return None
    if s == "ايونيه":
        return (2026, 6, 1)
    m = re.match(r"(\d{1,2})\s+(.+)", s)
    if m:
        day = int(m.group(1))
        month = ARABIC_MONTHS.get(m.group(2).strip())
        if month:
            return (2026, month, day)
    m = re.match(r"(\d{1,2})(.+)", s)
    if m:
        day = int(m.group(1))
        month = ARABIC_MONTHS.get(m.group(2).strip())
        if month:
            return (2026, month, day)
    return None

def add_one_month(year, month, day):
    """Add 1 month, clamping day to last valid day of target month."""
    month += 1
    if month > 12:
        month = 1
        year += 1
    # Get last day of target month
    if month == 2:
        last_day = 29 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 28
    elif month in (4, 6, 9, 11):
        last_day = 30
    else:
        last_day = 31
    day = min(day, last_day)
    return (year, month, day)

def supabase_get(table, select="*"):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select={select}"
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

# ── Load data ──────────────────────────────────────────────────────
tenants = supabase_get("tenants", "id,name,room_id,payment_status,due_date")
rooms = supabase_get("rooms", "id,room_number,building_id")
room_data = {r["id"]: r for r in rooms}

name_to_tenant = {t["name"].strip(): t for t in tenants}
room_to_tenant = {}
for t in tenants:
    rid = t.get("room_id")
    if rid:
        r = room_data.get(rid)
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
        move_in_raw = row.get("من", "").strip()
        move_in = parse_arabic_date(move_in_raw)
        
        if villa == "البركه":
            num = room_code[:-1]
            floor = room_code[-2].upper()
            room_num = f"B{num}{floor}"
        else:
            room_num = room_code[:-1]
        
        # Due date = move-in + 1 month
        if move_in:
            due = add_one_month(*move_in)
        else:
            due = None
        
        csv_rows.append({
            "name": name,
            "villa": villa,
            "room_num": room_num,
            "move_in": move_in,
            "due_date": due,
            "move_in_raw": move_in_raw,
        })

# ── Name matching ──────────────────────────────────────────────────
def find_db_tenant(csv_name, room_num, villa):
    if csv_name in name_to_tenant:
        return name_to_tenant[csv_name]
    
    fuzzy = {
        "نهي عادل عبداللطيف جاب الله": "نهى عادل عبداللطيف جاب الله",
        "محمد عمر وتامر محمد السيد": "محمود محمد وتامر",
        "محمود جمال وعمر محمد": "محمود جمال و عمرمحمد",
        "محمد حميد (ابو نواف)": "اتنين سعوديين",
        "خلود مصطفى محمود": "خلود مصطفى اسماعيل",
        "مهاب فكرى حامد": "مهاب فكري حامد",
        "نيره حازم و ايه ابوزيد": "نيره حازم محمد تاج و أيه ابوزيد",
        "انجى (مضيقة)": "انجي (مضيفه)",
        "عمرو محمد على احمد جودة": "عمرو محمد علي احمد جوده",
        "احمد رمضان احمد محمود": "احمد رمضان",
        "محمد فرحات عبدالبارى": "محمد فرحات",
        "الطاهر السيد حامد": "طاهر السيد حامد",
        "انس نبيل عبالجواد": "انس نبيل عبدالجواد",
        "عبدالرحمن احمد عبدالرسول": "عبدالرحمن احمد عبدالسيد",
        "اشرف جمال عجوه/محمذ جمال عجوه": "اشرف جمال عجوه/محمد جمال عجوه",
        "جومانه مروان شاهين": "جومانه مروان شاهين",
        "منال عبّد الحميد ابراهيم": "منال عبدالحميد ابراهيم شرقاوي",
        "سلوى خيمتونج": "سلوي خيمتونج",
        "مجد نبيل عثمان جوده": "مجد نبيل عثمان واخوه",
        "يارا أحمد عبدالحليم": "يارا احمد عبدالحليم",
        "حازم ناصر محمد الزهر": "حازم ناصر محمد الزهر",
        "ايمن جمال الدين الفرغلي": "ايمن جمال الدين الفرغلي",
        "امجد محمد احمد عبده": "امجد محمد احمد عبده",
        "هانى محمد محمد الشماع وابنه": "هانى محمد محمد الشماع وابنه",
        "وائل نصيف عبدالسيد ابراهيم": "وائل نصيف عبدالسيد",
    }
    
    db_name = fuzzy.get(csv_name)
    if db_name and db_name in name_to_tenant:
        return name_to_tenant[db_name]
    
    for db_name, t in name_to_tenant.items():
        if csv_name in db_name or db_name in csv_name:
            return t
    
    bld_id = 1 if villa == "الجوي" else 2
    return room_to_tenant.get((bld_id, room_num))

# ── Update all tenants ────────────────────────────────────────────
updated = 0
skipped = 0

for r in csv_rows:
    if not r["due_date"]:
        skipped += 1
        continue
    
    due_str = f"{r['due_date'][0]}-{r['due_date'][1]:02d}-{r['due_date'][2]:02d}"
    move_in_str = f"{r['move_in'][0]}-{r['move_in'][1]:02d}-{r['move_in'][2]:02d}" if r['move_in'] else "?"
    
    t = find_db_tenant(r["name"], r["room_num"], r["villa"])
    if not t:
        print(f"NOT FOUND: {r['name']}")
        skipped += 1
        continue
    
    # All tenants marked unpaid — user will manually mark paid
    status = supabase_patch("tenants", f"id=eq.{t['id']}", {
        "due_date": due_str,
        "payment_status": "unpaid"
    })
    
    if status in (200, 204):
        updated += 1
        print(f"✓ {t['name']:35s} | move-in: {move_in_str:12s} | due: {due_str} | unpaid")
    else:
        print(f"ERROR: {t['name']} → HTTP {status}")

# Fix duplicates
for t in tenants:
    if "وليد" in t["name"] and "الماحى" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": "2026-02-06", "payment_status": "unpaid"})
        print(f"✓ {t['name']} → due: 2026-02-06, unpaid")
        updated += 1
    if "ايمن" in t["name"] and "فرغلي" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"due_date": "2026-02-26", "payment_status": "unpaid"})
        updated += 1
    if "باسنت" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1
    if "حبيبي" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1
    if "عبدالله" in t["name"] and "ثابت" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1
    if "احمد نزيه" in t["name"]:
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1
    if t["name"] == "mohammed":
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1
    if t["name"] == "Ibrahim":
        supabase_patch("tenants", f"id=eq.{t['id']}", {"payment_status": "unpaid"})
        updated += 1

print(f"\n{'='*60}")
print(f"Updated: {updated} | Skipped: {skipped}")
print(f"\nAll tenants marked UNPAID with due_date = move-in + 1 month")
