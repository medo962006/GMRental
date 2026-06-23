#!/usr/bin/env python3
"""
Hostel Management — Tenant CSV Import Script v2
═══════════════════════════════════════════════════════════════════════
Re-runs the import with corrected payment logic.

Key insight from CSV:
- Rent columns show ACTUAL payments per month
- XXXX = month not yet reached for this tenant
- Empty = month passed but not paid (or not recorded)
- We're in mid-June 2026, so April+May should be paid, June is current

Payment status logic:
- If tenant has paid for all months from lease start through May → 'paid'
  (due_date = July 1 for next month's rent)
- If any month from start through May is missing → 'unpaid'
  (due_date = July 1 as urgent)
- June rent: if June column has a number → paid for June too
- June is "grace period" — not counting as overdue yet
"""

import csv
import re
import sys
from datetime import date, datetime, timedelta
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
TODAY = date(2026, 6, 13)


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
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError:
        return None


def parse_amount(val):
    if val is None:
        return 0.0
    val = str(val).strip()
    if val in ("XXXX", "", "-", "N/A", "n/a"):
        return 0.0
    val = val.replace(",", "").replace('"', "").replace("'", "").strip()
    try:
        return float(val)
    except ValueError:
        return 0.0


def clean_phone(s):
    if not s or not s.strip():
        return ""
    numbers = s.split("/")
    for n in numbers:
        n = n.strip()
        if n:
            return n
    return ""


def determine_gender(name):
    if not name:
        return None
    n = name.strip()
    female_markers = ["نهى", "غدير", "خديجه", "خديجة", "خلود", "نيره", "انجي", "مضيفه", "مضيفة", "مصرية", "سعوديه", "سعودية"]
    for m in female_markers:
        if m in n:
            return "female"
    if any(kw in n for kw in ["اتنين", "هنود", "وزوجته", "جمال و", "وتامر", "محمد و"]):
        return None
    return "male"


def analyze_payments(row):
    """
    Returns (payment_status, due_date, months_paid_count, months_expected_count, notes)
    """
    monthly_rent = parse_amount(row.get("Monthly Rent", 0))
    start_date = parse_arabic_date(row.get("Lease Start Date", ""))
    
    # Parse rent payments per month
    rent_paid = {
        4: parse_amount(row.get("April Rent", 0)),
        5: parse_amount(row.get("May Rent", 0)),
        6: parse_amount(row.get("June Rent", 0)),
        7: parse_amount(row.get("July Rent", 0)),
    }
    
    # Determine which months this tenant should have paid by now
    # We're June 13, 2026. April and May should definitely be paid.
    # June is the current month (grace period).
    # July hasn't started.
    
    # Months that should be fully paid: April, May
    # Month that's current: June
    # Future months: July+
    
    # Determine start month
    if start_date:
        start_month = start_date.month
    else:
        start_month = 4  # Default to April if no date
    
    # Months that should be paid by now (through May)
    required_months = []
    m = start_month
    while m <= 5:  # Through May
        required_months.append(m)
        m += 1
        if m > 12:
            m = 1
    
    # Check which required months are paid
    unpaid_required = []
    paid_required = []
    for m in required_months:
        if rent_paid.get(m, 0) >= monthly_rent * 0.5:  # At least half paid counts
            paid_required.append(m)
        else:
            unpaid_required.append(m)
    
    # June payment
    june_paid = rent_paid.get(6, 0) >= monthly_rent * 0.5
    
    # Determine status
    notes = []
    if unpaid_required:
        payment_status = "unpaid"
        missing = [f"{['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m]}" for m in unpaid_required]
        notes.append(f"Missing: {', '.join(missing)}")
    else:
        payment_status = "paid"
    
    if june_paid:
        notes.append("June paid")
    
    # Due date
    if payment_status == "unpaid":
        due_date = date(2026, 7, 1)  # Urgent — July 1
    elif june_paid:
        due_date = date(2026, 7, 5)  # Paid through June, next due July
    else:
        due_date = date(2026, 6, 25)  # June rent due by end of month
    
    months_paid_count = len(paid_required) + (1 if june_paid else 0)
    months_expected_count = len(required_months) + 1  # +1 for current month (June)
    
    return payment_status, due_date, months_paid_count, months_expected_count, "; ".join(notes)


def main():
    print("═" * 65)
    print("  HOSTEL MANAGEMENT — TENANT CSV IMPORTER v2")
    print("═" * 65)
    
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print(f"\n✓ Connected to Supabase")
    
    # ── Read CSV ──────────────────────────────────────────
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            serial = row.get("Serial", "").strip()
            name = row.get("Name", "").strip()
            if serial and name:  # Skip truly empty rows
                rows.append(row)
    
    print(f"  Found {len(rows)} valid tenant records")
    
    # ── Step 1: Create rooms ──────────────────────────────
    print("\n─ Step 1: Creating rooms ─")
    room_map = {}
    for row in rows:
        rn = row.get("Room No", "").strip()
        rent = parse_amount(row.get("Monthly Rent", 0))
        if rn and rn not in room_map:
            room_map[rn] = rent
    
    room_db_map = {}
    for rn, rent in room_map.items():
        existing = supabase.table("rooms").select("id").eq("room_number", rn).execute()
        if existing.data:
            rid = existing.data[0]["id"]
            supabase.table("rooms").update({"monthly_rent": rent, "status": "occupied"}).eq("id", rid).execute()
            room_db_map[rn] = rid
            print(f"  ↻ Room {rn} (ID:{rid}) updated")
        else:
            result = supabase.table("rooms").insert({
                "room_number": rn, "status": "occupied", "monthly_rent": rent
            }).execute()
            rid = result.data[0]["id"]
            room_db_map[rn] = rid
            print(f"  + Room {rn} (ID:{rid}) created")
    
    # ── Step 2: Clear existing tenants ────────────────────
    print("\n─ Step 2: Clearing existing tenants ─")
    supabase.table("tenants").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
    print("  ✓ Cleared")
    
    # ── Step 3: Import tenants ────────────────────────────
    print("\n─ Step 3: Importing tenants ─")
    results = []
    
    for row in rows:
        serial = row.get("Serial", "").strip()
        name = row.get("Name", "").strip()
        phone = clean_phone(row.get("Phone Numbers", ""))
        room_num = row.get("Room No", "").strip()
        monthly_rent = parse_amount(row.get("Monthly Rent", 0))
        insurance_raw = row.get("Insurance Amount", "")
        
        # Handle special insurance values
        if "$" in str(insurance_raw):
            insurance = 0.0  # USD amount, can't convert automatically
        else:
            insurance = parse_amount(insurance_raw)
        
        lease_start = parse_arabic_date(row.get("Lease Start Date", ""))
        gender = determine_gender(name)
        room_id = room_db_map.get(room_num)
        
        payment_status, due_date, months_paid, months_expected, notes = analyze_payments(row)
        
        tenant_data = {
            "name": name,
            "phone": phone,
            "gender": gender,
            "room_id": room_id,
            "status": "active",
            "insurance_amount": insurance,
            "insurance_returned": False,
            "payment_status": payment_status,
            "due_date": due_date.isoformat(),
            "created_at": datetime.now().isoformat(),
        }
        
        try:
            result = supabase.table("tenants").insert(tenant_data).execute()
            tid = result.data[0]["id"]
            icon = "✓" if payment_status == "paid" else "⚠"
            print(f"  {icon} [{serial:>2}] {name[:28]:<28} Room {room_num:<4} "
                  f"{monthly_rent:>7,.0f} LE  {payment_status:<6} "
                  f"Due:{due_date}  ({months_paid}/{months_expected}mo)")
            if notes:
                print(f"      └─ {notes}")
            results.append({"serial": serial, "name": name, "status": payment_status,
                          "rent": monthly_rent, "due_date": str(due_date), "id": tid})
        except Exception as e:
            print(f"  ✗ [{serial}] {name[:28]} — ERROR: {e}")
    
    # ── Summary ───────────────────────────────────────────
    print("\n" + "═" * 65)
    print("  IMPORT SUMMARY")
    print("═" * 65)
    
    total = len(results)
    paid = len([r for r in results if r["status"] == "paid"])
    unpaid = len([r for r in results if r["status"] == "unpaid"])
    total_rent = sum(r["rent"] for r in results)
    
    print(f"\n  Total tenants:      {total}")
    print(f"  Paid:               {paid}")
    print(f"  Unpaid:             {unpaid}")
    print(f"  Total monthly rent: {total_rent:,.0f} LE")
    print(f"  Rooms:              {len(room_map)}")
    
    print("\n─ PAID TENANTS ─")
    for r in results:
        if r["status"] == "paid":
            print(f"  ✓ {r['name'][:30]:<30} Room {r.get('room','?'):<4} {r['rent']:>7,.0f} LE")
    
    print("\n─ UNPAID TENANTS (action needed) ─")
    for r in results:
        if r["status"] == "unpaid":
            print(f"  ⚠ {r['name'][:30]:<30} {r['rent']:>7,.0f} LE  Due: {r['due_date']}")
    
    print("\n" + "═" * 65)
    print("  ✓ Import complete!")
    print("═" * 65)


if __name__ == "__main__":
    main()
