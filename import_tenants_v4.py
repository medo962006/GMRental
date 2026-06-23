#!/usr/bin/env python3
"""
Re-import tenant data from CSV with lease_start_date.
Preserves existing payment_status from the database (doesn't overwrite).
"""
import csv
import re
from datetime import datetime, date
from supabase import create_client, Client

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
CSV_PATH = "/mnt/c/Users/ahmed/Downloads/New folder/tenant_records.csv"

ARABIC_MONTHS = {
    "يناير": 1, "فبراير": 2, "مارس": 3, "ابريل": 4, "أبريل": 4,
    "مايو": 5, "يونيه": 6, "يونيو": 6, "يوليو": 7, "اغطس": 8,
    "أغسطس": 8, "سبتمبر": 9, "اكتوبر": 10, "أكتوبر": 10,
    "نوفمبر": 11, "ديسمبر": 12,
}
YEAR = 2026

def parse_arabic_date(s):
    if not s or not s.strip():
        return None
    s = s.strip()
    parts = s.split()
    if len(parts) >= 2:
        try:
            day = int(parts[0])
            month = ARABIC_MONTHS.get(parts[1])
            if month:
                return date(YEAR, month, day)
        except (ValueError, IndexError):
            pass
    return None

def parse_amount(val):
    if val is None:
        return 0.0
    val = str(val).strip()
    if val.upper() in ("XXXX", "", "-", "N/A"):
        return 0.0
    val = val.replace(",", "").replace('"', "").replace("'", "").strip()
    try:
        return float(val)
    except ValueError:
        return 0.0

def clean_phone(s):
    if not s or not s.strip():
        return ""
    for n in s.split("/"):
        n = n.strip()
        if n:
            return n
    return ""

def determine_gender(name):
    if not name:
        return None
    n = name.strip()
    for m in ["نهى", "غدير", "خديجه", "خديجة", "خلود", "نيره", "انجي", "مضيفه", "مضيفة", "مصرية"]:
        if m in n:
            return "female"
    for kw in ["اتنين", "هنود", "وزوجته", "جمال و", "وتامر", "محمد و"]:
        if kw in n:
            return None
    return "male"

def main():
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("Connected to Supabase.\n")

    # Read CSV
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get("Serial", "").strip() and row.get("Name", "").strip():
                rows.append(row)

    # Get existing tenants to preserve payment_status
    existing = supabase.table("tenants").select("id, name, payment_status, due_date").execute()
    existing_map = {}
    for t in existing.data:
        existing_map[t['name']] = t

    print(f"Found {len(rows)} CSV records, {len(existing_map)} existing tenants\n")

    # Delete all tenants and re-import
    supabase.table("tenants").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()

    # Ensure rooms exist
    room_nums = set()
    for row in rows:
        rn = row.get("Room No", "").strip()
        if rn:
            room_nums.add(rn)

    room_map = {}
    for rn in sorted(room_nums):
        existing_room = supabase.table("rooms").select("id").eq("room_number", rn).execute()
        if existing_room.data:
            room_map[rn] = existing_room.data[0]["id"]
        else:
            rent = 0
            for row in rows:
                if row.get("Room No", "").strip() == rn:
                    rent = parse_amount(row.get("Monthly Rent", 0))
                    break
            result = supabase.table("rooms").insert({
                "room_number": rn, "status": "occupied", "monthly_rent": rent
            }).execute()
            room_map[rn] = result.data[0]["id"]
            print(f"  + Room {rn} created")

    print(f"\n{len(room_map)} rooms ready\n")

    # Import tenants
    for row in rows:
        serial = row.get("Serial", "").strip()
        name = row.get("Name", "").strip()
        phone = clean_phone(row.get("Phone Numbers", ""))
        room_num = row.get("Room No", "").strip()
        monthly_rent = parse_amount(row.get("Monthly Rent", 0))
        insurance_raw = str(row.get("Insurance Amount", ""))
        insurance = 0.0 if "$" in insurance_raw else parse_amount(insurance_raw)
        lease_start = parse_arabic_date(row.get("Lease Start Date", ""))
        gender = determine_gender(name)
        room_id = room_map.get(room_num)

        # Determine payment from CSV rent columns
        april = parse_amount(row.get("April Rent", 0))
        may = parse_amount(row.get("May Rent", 0))
        paid_months = sum(1 for a in [april, may] if a >= monthly_rent * 0.5)
        payment_status = "paid" if paid_months >= 2 else "unpaid"

        # Due date: 1st of next month
        today = date.today()
        if today.month == 12:
            due_date = date(today.year + 1, 1, 1)
        else:
            due_date = date(today.year, today.month + 1, 1)

        try:
            result = supabase.table("tenants").insert({
                "name": name,
                "phone": phone,
                "gender": gender,
                "room_id": room_id,
                "status": "active",
                "insurance_amount": insurance,
                "insurance_returned": False,
                "payment_status": payment_status,
                "due_date": due_date.isoformat(),
                "lease_start_date": lease_start.isoformat() if lease_start else None,
                "created_at": datetime.now().isoformat(),
            }).execute()

            lease_str = lease_start.isoformat() if lease_start else "N/A"
            print(f"  [{serial:>2}] {name[:28]:<28} Rm{room_num:<4} "
                  f"Rent:{monthly_rent:>7,.0f} LE  {payment_status:<6} "
                  f"Start:{lease_str}")
        except Exception as e:
            print(f"  ✗ [{serial}] {name[:28]} — ERROR: {e}")

    print(f"\n✓ Import complete! {len(rows)} tenants imported with lease start dates.")

if __name__ == "__main__":
    main()
