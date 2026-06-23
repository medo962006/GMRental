#!/usr/bin/env python3
"""Import Baraka and Gawy reception CSV files into Supabase reception_history table."""

import csv
import re
import requests
import sys
from datetime import datetime

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}

ARABIC_MONTHS = {
    "يناير": 1, "فبراير": 2, "مارس": 3, "ابريل": 4,
    "مايو": 5, "يونيو": 6, "يوليو": 7, "اغسطس": 8,
    "سبتمبر": 9, "اكتوبر": 10, "نوفمبر": 11, "ديسمبر": 12,
    "يونيه": 6, "يونية": 6, "يولية": 7, "اغسطس": 8,
    "اوت": 8, "اكتوبر": 10, "نوفمبر": 11, "ديسمير": 12,
    "كانون الثاني": 1, "شباط": 2, "اذار": 3, "نيسان": 4,
    "ايار": 5, "حزيران": 6, "تموز": 7, "اب": 8,
    "ايلول": 9, "تشرين الاول": 10, "تشرين الثاني": 11, "كانون الاول": 12,
}

def parse_arabic_date(text):
    """Parse Arabic date like '22 مارس' or '22مارس' or '15/6' or '2 يونيه'."""
    if not text or not text.strip():
        return None
    text = text.strip()

    # Try DD/MM or DD/M format
    slash_match = re.match(r'^(\d{1,2})/(\d{1,2})$', text)
    if slash_match:
        day = int(slash_match.group(1))
        month = int(slash_match.group(2))
        if 1 <= month <= 12 and 1 <= day <= 31:
            return f"2026-{month:02d}-{day:02d}"
        return None

    # Try "DD MonthName" or "DDMonthName"
    # Normalize: ensure space between number and month
    normalized = re.sub(r'(\d+)([أ-ي])', r'\1 \2', text)
    parts = normalized.split()
    if len(parts) >= 2:
        try:
            day = int(parts[0])
            month_name = parts[1].lower().strip()
            # Try full month name match
            month = ARABIC_MONTHS.get(month_name)
            if month is None:
                # Try partial match
                for k, v in ARABIC_MONTHS.items():
                    if month_name in k or k in month_name:
                        month = v
                        break
            if month and 1 <= day <= 31:
                return f"2026-{month:02d}-{day:02d}"
        except (ValueError, IndexError):
            pass

    return None


def parse_amount(text):
    """Parse amount string like '12500.00' or '16000' or empty."""
    if not text or not text.strip():
        return 0.0
    text = text.strip().replace(',', '').replace('،', '')
    try:
        return float(text)
    except ValueError:
        return 0.0


def parse_csv(filepath, building_id, has_phone=False):
    """Parse a reception CSV file and return list of records."""
    records = []

    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        header = next(reader)
        print(f"  Header: {header}")

        for row_num, row in enumerate(reader, start=2):
            if not row or not row[0].strip():
                continue  # Skip empty rows

            # Parse based on whether phone column exists
            if has_phone:
                # Gawy format: تسلسل,الاسم,ارقام التليفونات,الجنسية,تاريخ الدخول,رقم الغرفة,قيمة الايجار الشهري,قيمة التأمين,مدة عقد الايجار,ما تم دفعة مقدم,باقي,طريقة الدفع,حالة العقد
                name = row[1].strip() if len(row) > 1 else ''
                phone = row[2].strip() if len(row) > 2 else ''
                nationality = row[3].strip() if len(row) > 3 else ''
                move_in = row[4].strip() if len(row) > 4 else ''
                room = row[5].strip() if len(row) > 5 else ''
                rent = row[6].strip() if len(row) > 6 else ''
                insurance = row[7].strip() if len(row) > 7 else ''
                duration = row[8].strip() if len(row) > 8 else ''
                paid = row[9].strip() if len(row) > 9 else ''
                remaining = row[10].strip() if len(row) > 10 else ''
                method = row[11].strip() if len(row) > 11 else ''
                status = row[12].strip() if len(row) > 12 else ''
            else:
                # Baraka format: تسلسل,الاسم,الجنسية,تاريخ الدخول,رقم الغرفة,قيمة الايجار الشهري,قيمة التأمين,مدة عقد الايجار,ما تم دفعة مقدم,باقي,طريقة الدفع,حالة العقد
                name = row[1].strip() if len(row) > 1 else ''
                phone = ''
                nationality = row[2].strip() if len(row) > 2 else ''
                move_in = row[3].strip() if len(row) > 3 else ''
                room = row[4].strip() if len(row) > 4 else ''
                rent = row[5].strip() if len(row) > 5 else ''
                insurance = row[6].strip() if len(row) > 6 else ''
                duration = row[7].strip() if len(row) > 7 else ''
                paid = row[8].strip() if len(row) > 8 else ''
                remaining = row[9].strip() if len(row) > 9 else ''
                method = row[10].strip() if len(row) > 10 else ''
                status = row[11].strip() if len(row) > 11 else ''

            if not name and not room:
                continue  # Skip completely empty rows

            move_in_date = parse_arabic_date(move_in)

            record = {
                "name": name,
                "phone": phone,
                "nationality": nationality,
                "building_id": building_id,
                "room_number": room,
                "move_in_date": move_in_date,
                "monthly_rent": parse_amount(rent),
                "insurance_amount": parse_amount(insurance),
                "lease_duration": duration,
                "amount_paid_upfront": parse_amount(paid),
                "remaining_amount": parse_amount(remaining),
                "payment_method": method,
                "lease_status": status,
            }
            records.append(record)

    return records


def upload_records(records):
    """Upload records to Supabase reception_history table."""
    url = f"{SUPABASE_URL}/rest/v1/reception_history"

    # Upload in batches of 50
    batch_size = 50
    total = len(records)
    success = 0
    failed = 0

    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        try:
            resp = requests.post(url, headers=HEADERS, json=batch, timeout=30)
            if resp.status_code in (200, 201):
                success += len(batch)
                print(f"  Batch {i // batch_size + 1}: {len(batch)} uploaded ✓")
            else:
                failed += len(batch)
                print(f"  Batch {i // batch_size + 1}: FAILED ({resp.status_code}): {resp.text[:200]}")
        except Exception as e:
            failed += len(batch)
            print(f"  Batch {i // batch_size + 1}: ERROR: {e}")

    return success, failed


def main():
    base = "/mnt/c/Users/ahmed/Downloads/New folder"

    # Import Gawy (building_id = 1) - has phone column
    print("=" * 60)
    print("Importing Gawy Reception.csv (building_id=1)...")
    gawy_records = parse_csv(f"{base}/Gawy Reception.csv", building_id=1, has_phone=True)
    print(f"  Parsed {len(gawy_records)} records")

    # Import Baraka (building_id = 2) - no phone column
    print("\nImporting Baraka Reception.csv (building_id=2)...")
    baraka_records = parse_csv(f"{base}/Baraka Reception.csv", building_id=2, has_phone=False)
    print(f"  Parsed {len(baraka_records)} records")

    all_records = gawy_records + baraka_records
    print(f"\nTotal records to import: {len(all_records)}")

    # Show sample
    if all_records:
        print(f"\nSample record: {all_records[0]}")

    # Upload
    print("\nUploading to Supabase...")
    success, failed = upload_records(all_records)

    print(f"\n{'=' * 60}")
    print(f"Done! {success} uploaded, {failed} failed out of {len(all_records)} total")

    # Verify
    url = f"{SUPABASE_URL}/rest/v1/reception_history?select=id&limit=1"
    resp = requests.get(url, headers=HEADERS, timeout=10)
    if resp.status_code == 200:
        count_url = f"{SUPABASE_URL}/rest/v1/reception_history?select=count"
        count_resp = requests.get(count_url, headers={**HEADERS, "Prefer": "count=exact"}, timeout=10)
        if count_resp.status_code == 200:
            total = count_resp.headers.get('content-range', 'unknown')
            print(f"Total rows in reception_history: {total}")


if __name__ == "__main__":
    main()
