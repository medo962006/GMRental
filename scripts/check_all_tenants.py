#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check all tenants' due dates and payment status"""
import urllib.request, json
from datetime import datetime

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

today = datetime(2026, 6, 16)

for building_id, name in [(1, "Gawy"), (2, "Baraka")]:
    tenants = api("GET", "tenants", params={"building_id": str(building_id)})
    rooms = api("GET", "rooms", params={"building_id": str(building_id)})
    room_map = {r['id']: r for r in rooms}
    
    print(f"\n{'='*70}")
    print(f"  {name} ({len(tenants)} tenants)")
    print(f"{'='*70}")
    
    paid_count = 0
    unpaid_count = 0
    overdue_count = 0
    
    for t in sorted(tenants, key=lambda x: x.get('due_date') or ''):
        room = room_map.get(t['room_id'])
        rn = room['room_number'] if room else '?'
        rent = room.get('monthly_rent', 0) if room else 0
        due = t.get('due_date')
        status = t['payment_status']
        
        is_overdue = False
        if due:
            try:
                due_dt = datetime.strptime(due, "%Y-%m-%d")
                is_overdue = today > due_dt
            except:
                pass
        
        if status == 'paid':
            paid_count += 1
            icon = 'PAID'
        else:
            unpaid_count += 1
            icon = 'UNPAID'
        
        if is_overdue:
            overdue_count += 1
            icon = 'OVERDUE'
        
        print(f"  {icon:8s} {t['name'][:25]:25s}  rn={rn:5s}  rent={rent:>8.0f}  "
              f"due={due or 'N/A':10s}  status={status:6s}")
    
    print(f"\n  Summary: {paid_count} paid, {unpaid_count} unpaid, {overdue_count} overdue")
