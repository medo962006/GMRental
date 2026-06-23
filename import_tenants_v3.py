#!/usr/bin/env python3
"""
Hostel Management — Tenant CSV Import v3 (FINAL)
═══════════════════════════════════════════════════════════
Corrected logic:
- CSV rent columns: April, May, June, July
- We're in mid-June 2026
- April + May = MUST be paid (past months)
- June = current month (grace period, due by month-end)
- July = future
- Only flag unpaid if April or May is missing
- June empty = still in grace period, not overdue
"""

import csv
import re
from datetime import date, datetime
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


def analyze_payments(row):
    """
    Correct logic:
    - April (col) and May (col) are past months — must be paid
    - June (col) is current month — grace period
    - July (col) is future — XXXX means not yet due
    - If June has a number → tenant paid June too
    - Only count months from lease start month onward
    """
    monthly_rent = parse_amount(row.get("Monthly Rent", 0))
    start_date = parse_arabic_date(row.get("Lease Start Date", ""))
    start_month = start_date.month if start_date else 3  # Default March
    
    # Parse rent columns
    april_paid = parse_amount(row.get("April Rent", 0))
    may_paid = parse_amount(row.get("May Rent", 0))
    june_paid = parse_amount(row.get("June Rent", 0))
    # July column often has text like "دافعه شهرين لتركيب التكييف" — ignore
    
    # Determine which past months this tenant should have paid
    # Past months = April and May (we're June 13)
    # But only from their start month
    past_months_expected = []
    for m in [4, 5]:  # April, May
        if m >= start_month:
            past_months_expected.append(m)
    
    # Check payment for each past month
    past_payments = {4: april_paid, 5: may_paid}
    unpaid_past = []
    paid_past = []
    for m in past_months_expected:
        if past_payments.get(m, 0) >= monthly_rent * 0.5:
            paid_past.append(m)
        else:
            unpaid_past.append(m)
    
    # June status
    june_paid_full = june_paid >= monthly_rent * 0.5
    
    # Status determination
    notes = []
    if unpaid_past:
        payment_status = "unpaid"
        missing_names = ["Apr" if m == 4 else "May" for m in unpaid_past]
        notes.append(f"Unpaid: {', '.join(missing_names)}")
        due_date = date(2026, 7, 1)
    elif june_paid_full:
        payment_status = "paid"
        notes.append("Paid through June")
        due_date = date(2026, 7, 5)
    else:
        payment_status = "paid"  # Paid past months, June in grace period
        notes.append("June due")
        due_date = date(2026, 6, 25)
    
    if june_paid_full:
        notes.append("June paid")
    
    return payment_status, due_date, len(paid_past), len(past_months_expected), "; ".join(notes)


def main():
    print("═" * 65)
    print("  HOSTEL MANAGEMENT — TENANT IMPORT v3 (FINAL)")
    print("═" * 65)
    
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # ── Read CSV ──────────────────────────────────────────
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            serial = row.get("Serial", "").strip()
            name = row.get("Name", "").strip()
            room = row.get("Room No", "").strip()
            # Skip rows without actual data (serial but no name or room)
            if serial and name and room:
                rows.append(row)
    
    print(f"\n  Valid tenant records: {len(rows)}")
    
    # ── Rooms ─────────────────────────────────────────────
    print("\n─ Rooms ─")
    room_map = {}
    for row in rows:
        rn = row.get("Room No", "").strip()
        rent = parse_amount(row.get("Monthly Rent", 0))
        if rn and rn not in room_map:
            room_map[rn] = rent
    
    room_db_map = {}
    for rn, rent in sorted(room_map.items()):
        existing = supabase.table("rooms").select("id").eq("room_number", rn).execute()
        if existing.data:
            rid = existing.data[0]["id"]
            supabase.table("rooms").update({"monthly_rent": rent, "status": "occupied"}).eq("id", rid).execute()
            room_db_map[rn] = rid
        else:
            result = supabase.table("rooms").insert({
                "room_number": rn, "status": "occupied", "monthly_rent": rent
            }).execute()
            rid = result.data[0]["id"]
            room_db_map[rn] = rid
    print(f"  {len(room_map)} rooms ready")
    
    # ── Clear tenants ─────────────────────────────────────
    supabase.table("tenants").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
    print("  Old tenants cleared")
    
    # ── Import ────────────────────────────────────────────
    print("\n─ Importing tenants ─")
    results = []
    
    for row in rows:
        serial = row.get("Serial", "").strip()
        name = row.get("Name", "").strip()
        phone = clean_phone(row.get("Phone Numbers", ""))
        room_num = row.get("Room No", "").strip()
        monthly_rent = parse_amount(row.get("Monthly Rent", 0))
        insurance_raw = str(row.get("Insurance Amount", ""))
        
        if "$" in insurance_raw:
            insurance = 0.0
        else:
            insurance = parse_amount(insurance_raw)
        
        lease_start = parse_arabic_date(row.get("Lease Start Date", ""))
        gender = determine_gender(name)
        room_id = room_db_map.get(room_num)
        payment_status, due_date, paid_count, expected_count, notes = analyze_payments(row)
        
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
            print(f"  {icon} [{serial:>2}] {name[:26]:<26} Rm{room_num:<4} "
                  f"{monthly_rent:>7,.0f}LE  {payment_status:<6} Due:{due_date}")
            results.append({"serial": serial, "name": name, "room": room_num,
                          "status": payment_status, "rent": monthly_rent,
                          "due_date": str(due_date), "id": tid, "notes": notes})
        except Exception as e:
            print(f"  ✗ [{serial}] {name[:26]} — {e}")
    
    # ── Summary ───────────────────────────────────────────
    total = len(results)
    paid = len([r for r in results if r["status"] == "paid"])
    unpaid = len([r for r in results if r["status"] == "unpaid"])
    total_rent = sum(r["rent"] for r in results)
    
    print(f"\n{'═' * 65}")
    print(f"  RESULTS: {total} tenants | {paid} paid | {unpaid} unpaid")
    print(f"  Total monthly rent: {total_rent:,.0f} LE")
    print(f"{'═' * 65}")
    
    if unpaid > 0:
        print("\n  UNPAID TENANTS:")
        for r in results:
            if r["status"] == "unpaid":
                print(f"  ⚠ {r['name'][:28]:<28} Rm{r['room']:<4} "
                      f"{r['rent']:>7,.0f}LE  Due:{r['due_date']}")
    
    print(f"\n  ✓ Done! Run the Flutter app to see the dashboard.")


if __name__ == "__main__":
    main()
