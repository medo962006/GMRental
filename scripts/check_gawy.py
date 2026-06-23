#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check why specific tenants show wrong payment status"""
import urllib.request, json

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

def api(method, path, data=None, params=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    if params:
        url += "?" + "&".join(f"{k}=eq.{v}" for k, v in params.items())
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read()
            return json.loads(raw) if raw else []
    except Exception as e:
        return []

# Get all Gawy tenants with their room rent
tenants = api("GET", "tenants", params={"building_id": "1"})
rooms = api("GET", "rooms", params={"building_id": "1"})
room_map = {r['id']: r for r in rooms}

print(f"Gawy: {len(tenants)} tenants, {len(rooms)} rooms\n")

total_rent = 0
total_collected = 0
total_unpaid = 0
overdue_total = 0

for t in sorted(tenants, key=lambda x: x['name']):
    room = room_map.get(t['room_id'])
    rent = room.get('monthly_rent', 0) if room else 0
    total_rent += rent
    
    # Check if overdue
    due = t.get('due_date')
    is_overdue = False
    if due and t['payment_status'] == 'unpaid':
        from datetime import datetime
        try:
            due_dt = datetime.strptime(due, "%Y-%m-%d")
            is_overdue = datetime.now() > due_dt
            if is_overdue:
                overdue_total += rent
        except:
            pass
    
    status_icon = '✅' if t['payment_status'] == 'paid' else '❌'
    if t['payment_status'] == 'paid':
        total_collected += rent
    else:
        total_unpaid += rent
    
    print(f"  {status_icon} {t['name'][:25]:25s} rent={rent:>8.0f}  status={t['payment_status']:6s}  due={due or 'N/A':10s}  overdue={is_overdue}")

print(f"\n{'═'*60}")
print(f"Total monthly rent:  {total_rent:>10.0f}")
print(f"Collected (paid):    {total_collected:>10.0f}")
print(f"Unpaid:              {total_unpaid:>10.0f}")
print(f"Overdue:             {overdue_total:>10.0f}")
print(f"Collection rate:     {total_collected/total_rent*100 if total_rent else 0:>9.1f}%")

# Now reproduce the dashboard stats query
print(f"\n{'═'*60}")
print("Dashboard stats query simulation:")

# The dashboard uses getDashboardStats which does:
# totalRent = sum of all active tenants' room.monthlyRent
# totalPaid = sum of paid tenants' room.monthlyRent  
# totalUnpaid = sum of unpaid tenants' room.monthlyRent

paid_rent = sum(room_map.get(t['room_id'], {}).get('monthly_rent', 0) 
                for t in tenants if t['payment_status'] == 'paid' and t['status'] == 'active')
unpaid_rent = sum(room_map.get(t['room_id'], {}).get('monthly_rent', 0) 
                 for t in tenants if t['payment_status'] == 'unpaid' and t['status'] == 'active')

print(f"  totalRentExpected (active): {paid_rent + unpaid_rent:>10.0f}")
print(f"  totalRentPaid:              {paid_rent:>10.0f}")
print(f"  totalRentUnpaid:            {unpaid_rent:>10.0f}")

# Check the overdue count
overdue_count = 0
for t in tenants:
    if t['payment_status'] == 'unpaid' and t.get('due_date'):
        try:
            from datetime import datetime
            if datetime.now() > datetime.strptime(t['due_date'], "%Y-%m-%d"):
                overdue_count += 1
                room = room_map.get(t['room_id'])
                rn = room['room_number'] if room else '?'
                print(f"  OVERDUE: {t['name']} → Room {rn}, due {t['due_date']}, rent {room.get('monthly_rent', '?') if room else '?'}")
        except: pass

print(f"\n  Overdue tenants: {overdue_count}")
print(f"  Overdue amount:  {overdue_total:>10.0f}")
