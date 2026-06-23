#!/usr/bin/env python3
"""Check the 7 skipped tenants and their actual room assignments."""

import json
import urllib.request

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

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

tenants = supabase_get("tenants", "id,name,room_id,payment_status,due_date")
rooms = supabase_get("rooms", "id,room_number,building_id")

room_data = {r["id"]: r for r in rooms}

skipped_names = [
    "انس نبيل عبالجواد",
    "عبدالرحمن احمد عبدالرسول",
    "اشرف جمال عجوه/محمذ جمال عجوه",
    "يارا أحمد عبدالحليم",
    "منال عبّد الحميد ابراهيم",
    "سلوى خيمتونج",
    "مجد نبيل عثمان جوده",
]

for t in tenants:
    for sn in skipped_names:
        if sn in t["name"] or t["name"] in sn:
            r = room_data.get(t["room_id"])
            bld = "Gawy" if r and r["building_id"] == 1 else "Baraka" if r and r["building_id"] == 2 else "?"
            print(f"CSV: {sn}")
            print(f"  DB:  {t['name']} | room: {r['room_number'] if r else '?'} ({bld}) | status: {t['payment_status']} | due: {t['due_date']}")
            print()
            break

# Also check if any of these names exist at all
print("── All tenants containing these names ──")
for t in tenants:
    for sn in skipped_names:
        if sn[:6] in t["name"]:
            r = room_data.get(t["room_id"])
            print(f"  {t['name']} | {r['room_number'] if r else '?'} | {t['payment_status']} | {t['due_date']}")
