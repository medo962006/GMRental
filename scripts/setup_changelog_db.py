#!/usr/bin/env python3
"""Create changelog and device_codes tables, then set up admin device."""
import json, urllib.request, urllib.error, uuid
from datetime import datetime, timezone

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma3ltb2ltdGpnYWZ2YmNsbnF5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM1OTg2MiwiZXhwIjoyMDk2OTM1ODYyfQ.O9GP543-_rnOcB_2HAb4cF2YJhFFkOxRGEQiWdQktXc"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def run_sql(query):
    url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
    body = json.dumps({"query": query}).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            result = res.read().decode()
            print(f"  OK: {query[:70]}...")
            return result
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  ERR {e.code}: {err[:100]}")
        return None

def main():
    print("═══ Changelog Database Setup ═══\n")

    # Create device_codes table
    print("Step 1: Creating device_codes table...")
    run_sql("""
        CREATE TABLE IF NOT EXISTS device_codes (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            code TEXT UNIQUE NOT NULL,
            device_name TEXT,
            is_active BOOLEAN DEFAULT true,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            last_seen_at TIMESTAMPTZ DEFAULT NOW()
        );
    """)

    # Create changelog table
    print("Step 2: Creating changelog table...")
    run_sql("""
        CREATE TABLE IF NOT EXISTS changelog (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            device_code TEXT NOT NULL REFERENCES device_codes(code),
            admin_name TEXT,
            action TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT,
            entity_name TEXT,
            old_value JSONB,
            new_value JSONB,
            details TEXT,
            building_id INTEGER DEFAULT 1,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    """)

    # Create index for faster queries
    print("Step 3: Creating indexes...")
    run_sql("CREATE INDEX IF NOT EXISTS idx_changelog_device ON changelog(device_code);")
    run_sql("CREATE INDEX IF NOT EXISTS idx_changelog_created ON changelog(created_at DESC);")
    run_sql("CREATE INDEX IF NOT EXISTS idx_changelog_building ON changelog(building_id);")

    # Insert a default admin device
    print("\nStep 4: Creating default admin device...")
    device_code = str(uuid.uuid4())[:8].upper()
    
    url = f"{SUPABASE_URL}/rest/v1/device_codes"
    body = json.dumps({
        "code": device_code,
        "device_name": "Admin Device",
        "is_active": True
    }).encode()
    req = urllib.request.Request(url, data=body, headers={**HEADERS, "Prefer": "return=representation"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            result = json.loads(res.read())
            print(f"  Device code: {device_code}")
    except Exception as e:
        print(f"  Device may already exist: {e}")
        device_code = "ADMIN001"
        # Try to insert with a simpler code
        body = json.dumps({"code": device_code, "device_name": "Admin Device"}).encode()
        req = urllib.request.Request(url, data=body, headers={**HEADERS, "Prefer": "return=representation"}, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as res:
                print(f"  Device code: {device_code}")
        except:
            print(f"  Using device code: {device_code}")

    # Insert a test changelog entry
    print("\nStep 5: Inserting test changelog entry...")
    url = f"{SUPABASE_URL}/rest/v1/changelog"
    body = json.dumps({
        "device_code": device_code,
        "admin_name": "System",
        "action": "setup",
        "entity_type": "system",
        "entity_name": "Changelog",
        "details": "Changelog system initialized",
        "building_id": 1
    }).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            print("  Test entry created")
    except Exception as e:
        print(f"  Test entry error: {e}")

    print(f"\n═══ Setup Complete ═══")
    print(f"Device Code: {device_code}")
    print(f"Save this code — you'll need it to identify this admin device in the app.")

if __name__ == "__main__":
    main()
