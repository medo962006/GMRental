#!/usr/bin/env python3
"""
Create Phase 2+3 database tables in Supabase.
Run: python3 create_tables.py
"""
import sys
sys.path.insert(0, '/mnt/c/Users/ahmed/GMRental/hostel_management')

from supabase import create_client, Client

SUPABASE_URL = "https://sfkymoimtjgafvbclnqy.supabase.co"
SUPABASE_KEY = "sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC"

SQL = """
CREATE TABLE IF NOT EXISTS task_routines (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    assigned_to VARCHAR(50) DEFAULT 'Worker',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    room_id INT REFERENCES rooms(id) ON DELETE SET NULL,
    trigger_context VARCHAR(50) DEFAULT 'Manual',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS operational_costs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    cost_type VARCHAR(30) CHECK (cost_type IN ('salary', 'ad_spend', 'subscription', 'other')),
    billing_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE TABLE IF NOT EXISTS whatsapp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    message_type VARCHAR(30) CHECK (message_type IN ('debt_reminder', 'broadcast')),
    message_body TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'failed')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE task_routines DISABLE ROW LEVEL SECURITY;
ALTER TABLE operational_costs DISABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_logs DISABLE ROW LEVEL SECURITY;
"""

def main():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("Connected to Supabase.")
    print("NOTE: The supabase_py client does not support raw SQL execution directly.")
    print("Please run the SQL manually in Supabase SQL Editor:")
    print("=" * 60)
    print(SQL)
    print("=" * 60)
    print("\nAlternatively, use the Supabase CLI or dashboard SQL editor.")
    print(f"Dashboard URL: https://supabase.com/dashboard/project/sfkymoimtjgafvbclnqy/sql")

if __name__ == "__main__":
    main()
