#!/usr/bin/env python3
"""
Hostel Management — Tenant CSV Import Script
═══════════════════════════════════════════════════════════════════════
Reads tenant_records.csv, creates rooms if needed, imports all tenants
with correct payment status, due dates, and rent calculations.

Run from WSL:
  pip3 install supabase
  python3 import_tenants.py
"""

import csv
import re
import sys
from datetime import date, datetime, timedelta
from supabase import create_client, Client

# ── Supabase config (same as Flutter app) ──────────────────────
SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

# CSV path (Windows-mounted in WSL)
CSV_PATH = "/mnt/c/Users/ahmed/Downloads/New folder/tenant_records.csv"

# ── Arabic/Egyptian month mapping ──────────────────────────────
ARABIC_MONTHS = {
    "يناير": 1, "يناير": 1, "كانون الثاني": 1,
    "فبراير": 2, "فبراير": 2, "شباط": 2,
    "مارس": 3, "مارس": 3, "آذار": 3,
    "ابريل": 4, "أبريل": 4, "نيسان": 4,
    "مايو": 5, "مايو": 5, "أيار": 5,
    "يونيه": 6, "يونيو": 6, "حزيران": 6,
    "يوليو": 7, "يوليو": 7, "تموز": 7,
    "اغطس": 8, "أغسطس": 8, "آب": 8,
    "سبتمبر": 9, "سبتمبر": 9, "أيلول": 9,
    "اكتوبر": 10, "أكتوبر": 10, "تشرين الأول": 10,
    "نوفمبر": 11, "نوفمبر": 11, "تشرين الثاني": 11,
    "ديسمبر": 12, "ديسمبر": 12, "كانون الأول": 12,
}

# Current year — the CSV data is for 2026
YEAR = 2026

# ── Helper functions ────────────────────────────────────────────

def parse_arabic_date(date_str: str) -> date | None:
    """Parse Arabic date like '22 مارس' or '11 مايو' into a date object."""
    if not date_str or not date_str.strip():
        return None
    date_str = date_str.strip()
    # Try "DD MonthName" format
    parts = date_str.split()
    if len(parts) >= 2:
        try:
            day = int(parts[0])
            month_name = parts[1]
            month = ARABIC_MONTHS.get(month_name)
            if month:
                return date(YEAR, month, day)
        except (ValueError, IndexError):
            pass
    # Try ISO format fallback
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        pass
    return None


def parse_amount(val) -> float:
    """Parse a monetary value that might have commas, quotes, or be 'XXXX'."""
    if val is None:
        return 0.0
    val = str(val).strip()
    if val in ("XXXX", "", "-", "N/A", "n/a"):
        return 0.0
    # Remove commas and quotes
    val = val.replace(",", "").replace('"', "").replace("'", "").strip()
    try:
        return float(val)
    except ValueError:
        return 0.0


def clean_phone(phone_str: str) -> str:
    """Extract and clean phone numbers, return first valid one."""
    if not phone_str or not phone_str.strip():
        return ""
    # Split on ' / ' for multiple numbers
    numbers = phone_str.split("/")
    for num in numbers:
        num = num.strip()
        # Remove dashes and spaces
        cleaned = re.sub(r"[\s\-]", "", num)
        if cleaned:
            return num  # Return original format of first number
    return ""


def determine_gender(name: str) -> str | None:
    """Best-effort gender detection from name."""
    if not name:
        return None
    name_lower = name.strip().lower()
    # Explicit female markers
    female_markers = ["نهى", "غدير", "خديجه", "خديجة", "خلود", "نيره", "انجي", "مضيفه", "مضيفة", "مصرية", "سعوديه", "سعودية"]
    for marker in female_markers:
        if marker in name_lower:
            return "female"
    # Group bookings or unclear — return None
    if any(kw in name_lower for kw in ["اتنين", "هنود", "محمد و", "وزوجته", "جمال و", "وتامر"]):
        return None
    return "male"


def is_insurance_returned(insurance: float, rent_applied: float, monthly_rent: float) -> bool:
    """
    If insurance >= monthly rent, it was effectively 'returned' 
    (used as rent payment). But in this hostel model, insurance is 
    held until tenant leaves. Mark as not returned by default.
    """
    return False


def calculate_payment_status(tenant_row: dict) -> tuple[str, date | None, float]:
    """
    Determine payment_status, due_date, and expected_rent from CSV data.
    
    Logic:
    - Rent columns (April, May, June, July) show what was actually paid for that month
    - XXXX means no payment needed yet (month hasn't started from tenant's perspective)
    - Empty means payment was NOT made for that month (overdue)
    - If all months up to current are paid → 'paid', due_date = next month
    - If any month up to current is missing → 'unpaid', due_date = 1st of next month
    
    Returns: (payment_status, due_date, total_rent_due)
    """
    monthly_rent = parse_amount(tenant_row["Monthly Rent"])
    start_date = parse_arabic_date(tenant_row["Lease Start Date"])
    
    # Determine which months have been paid
    months_paid = {}
    month_order = [
        ("April Rent", 4),
        ("May Rent", 5),
        ("June Rent", 6),
        ("July Rent", 7),
    ]
    
    for col_name, month_num in month_order:
        amount = parse_amount(tenant_row.get(col_name, ""))
        if amount > 0:
            months_paid[month_num] = amount
    
    # Current date context: assume we're in June 2026
    # (data was recorded June 2026 based on conversation date)
    current_month = 6  # June
    today = date(2026, 6, 13)
    
    # Calculate which months should have been paid by now
    # Tenants pay monthly starting from lease start
    months_expected = []
    
    if start_date:
        # From start month through current month
        m = start_date.month
        while m <= current_month:
            months_expected.append(m)
            m += 1
            if m > 12:
                m = 1
    else:
        # If no start date, assume all months up to current
        months_expected = [4, 5, 6]  # April, May, June
    
    # Check which expected months are unpaid
    unpaid_months = []
    for m in months_expected:
        if m not in months_paid and m <= current_month:
            unpaid_months.append(m)
    
    # Calculate total rent due (unpaid months * monthly rent)
    total_rent_due = len(unpaid_months) * monthly_rent
    
    # Determine status
    if unpaid_months:
        payment_status = "unpaid"
        # Due date: 1st of next month from today
        if current_month == 12:
            due_date = date(YEAR + 1, 1, 1)
        else:
            due_date = date(YEAR, current_month + 1, 1)
    else:
        payment_status = "paid"
        # Due date: 1st of next month (for upcoming rent)
        if current_month == 12:
            due_date = date(YEAR + 1, 1, 5)
        else:
            due_date = date(YEAR, current_month + 1, 5)
    
    return payment_status, due_date, total_rent_due


# ── Main import logic ──────────────────────────────────────────

def main():
    print("═" * 60)
    print("  HOSTEL MANAGEMENT — TENANT CSV IMPORTER")
    print("═" * 60)
    
    # Connect to Supabase
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print(f"\n✓ Connected to Supabase: {SUPABASE_URL}")
    
    # ── Step 1: Read CSV ────────────────────────────────────
    print(f"\n─ Reading CSV: {CSV_PATH} ─")
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Skip empty rows
            if row.get("Serial", "").strip():
                rows.append(row)
    
    print(f"  Found {len(rows)} tenant records")
    
    # ── Step 2: Extract unique rooms ─────────────────────────
    room_map = {}  # room_number -> {rent, status}
    for row in rows:
        room_num = row.get("Room No", "").strip()
        rent = parse_amount(row.get("Monthly Rent", 0))
        if room_num:
            if room_num not in room_map:
                room_map[room_num] = {"rent": rent, "status": "occupied"}
            # If duplicate, use the higher rent
            elif rent > room_map[room_num]["rent"]:
                room_map[room_num]["rent"] = rent
    
    print(f"\n─ Rooms to create ({len(room_map)} unique) ─")
    for rn, data in sorted(room_map.items()):
        print(f"  Room {rn}: {data['rent']:.0f} LE/month")
    
    # ── Step 3: Create rooms ─────────────────────────────────
    print("\n─ Creating/updating rooms ─")
    room_db_map = {}  # room_number -> db_id
    
    for room_num, data in room_map.items():
        # Check if room exists
        existing = supabase.table("rooms").select("id").eq("room_number", room_num).execute()
        
        if existing.data:
            room_id = existing.data[0]["id"]
            # Update rent
            supabase.table("rooms").update({
                "monthly_rent": data["rent"],
                "status": "occupied"
            }).eq("id", room_id).execute()
            print(f"  ↻ Room {room_num} (ID: {room_id}) — updated")
        else:
            result = supabase.table("rooms").insert({
                "room_number": room_num,
                "status": "occupied",
                "monthly_rent": data["rent"]
            }).execute()
            room_id = result.data[0]["id"]
            print(f"  + Room {room_num} (ID: {room_id}) — created")
        
        room_db_map[room_num] = room_id
    
    # ── Step 4: Clear existing tenants (optional — for clean import)
    print("\n─ Clearing existing tenant data ─")
    try:
        # Delete all tenants first
        supabase.table("tenants").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        print("  ✓ Existing tenants cleared")
    except Exception as e:
        print(f"  ⚠ Could not clear tenants: {e}")
    
    # ── Step 5: Import tenants ───────────────────────────────
    print("\n─ Importing tenants ─")
    import_results = []
    
    for i, row in enumerate(rows):
        serial = row.get("Serial", "").strip()
        name = row.get("Name", "").strip()
        phone = clean_phone(row.get("Phone Numbers", ""))
        room_num = row.get("Room No", "").strip()
        monthly_rent = parse_amount(row.get("Monthly Rent", 0))
        insurance = parse_amount(row.get("Insurance Amount", 0))
        lease_start = parse_arabic_date(row.get("Lease Start Date", ""))
        gender = determine_gender(name)
        
        # Special case: Row 17 has "$300" insurance
        insurance_raw = row.get("Insurance Amount", "")
        if "$" in str(insurance_raw):
            insurance = 0.0  # Can't store USD in LE field — log separately
        
        room_id = room_db_map.get(room_num)
        
        # Calculate payment status
        payment_status, due_date, rent_due = calculate_payment_status(row)
        
        # Build tenant record
        tenant_data = {
            "name": name,
            "phone": phone,
            "gender": gender,
            "room_id": room_id,
            "status": "active",
            "insurance_amount": insurance,
            "insurance_returned": False,
            "payment_status": payment_status,
            "due_date": due_date.isoformat() if due_date else None,
            "created_at": datetime.now().isoformat(),
        }
        
        try:
            result = supabase.table("tenants").insert(tenant_data).execute()
            tenant_id = result.data[0]["id"]
            status_icon = "✓" if payment_status == "paid" else "!"
            print(f"  {status_icon} [{serial}] {name[:30]:<30} → Room {room_num:<4} "
                  f"Rent: {monthly_rent:>7.0f} LE  Status: {payment_status:<6} "
                  f"Due: {due_date}  ID: {tenant_id[:8]}...")
            import_results.append({
                "serial": serial,
                "name": name,
                "room": room_num,
                "rent": monthly_rent,
                "payment_status": payment_status,
                "due_date": str(due_date) if due_date else None,
                "id": tenant_id,
            })
        except Exception as e:
            print(f"  ✗ [{serial}] {name[:30]} — ERROR: {e}")
            import_results.append({
                "serial": serial,
                "name": name,
                "error": str(e),
            })
    
    # ── Step 6: Summary ──────────────────────────────────────
    print("\n" + "═" * 60)
    print("  IMPORT SUMMARY")
    print("═" * 60)
    
    total_tenants = len([r for r in import_results if "error" not in r])
    paid_count = len([r for r in import_results if r.get("payment_status") == "paid"])
    unpaid_count = len([r for r in import_results if r.get("payment_status") == "unpaid"])
    error_count = len([r for r in import_results if "error" in r])
    
    total_monthly_rent = sum(r.get("rent", 0) for r in import_results if "error" not in r)
    total_insurance = sum(
        parse_amount(row.get("Insurance Amount", 0)) 
        for row in rows 
        if "$" not in str(row.get("Insurance Amount", ""))
    )
    
    print(f"\n  Rooms created:      {len(room_map)}")
    print(f"  Tenants imported:   {total_tenants}")
    print(f"  Paid tenants:       {paid_count}")
    print(f"  Unpaid tenants:     {unpaid_count}")
    print(f"  Errors:             {error_count}")
    print(f"  Total monthly rent: {total_monthly_rent:,.0f} LE")
    print(f"  Total insurance:    {total_insurance:,.0f} LE")
    
    # ── Unpaid detail ────────────────────────────────────────
    print("\n─ UNPAID TENANTS (need attention) ─")
    unpaid = [r for r in import_results if r.get("payment_status") == "unpaid"]
    if unpaid:
        for t in unpaid:
            print(f"  • {t['name']:<35} Room {t['room']:<4} "
                  f"Rent: {t['rent']:>7,.0f} LE  Due: {t['due_date']}")
    else:
        print("  All tenants are paid up!")
    
    # ── Rooms status ─────────────────────────────────────────
    print("\n─ ROOMS STATUS ─")
    for rn, data in sorted(room_map.items()):
        rent_data = supabase.table("rooms").select("*").eq("room_number", rn).execute()
        if rent_data.data:
            r = rent_data.data[0]
            print(f"  Room {rn}: {r['monthly_rent']:>7,.0f} LE/month  Status: {r['status']}  ID: {r['id']}")
    
    print("\n" + "═" * 60)
    print("  ✓ Import complete! Check your Flutter app.")
    print("═" * 60)


if __name__ == "__main__":
    main()
