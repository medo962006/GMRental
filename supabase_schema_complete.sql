-- ════════════════════════════════════════════════════════
-- Hostel Management — Complete Schema Update
-- Run this ENTIRE script in Supabase SQL Editor
-- https://supabase.com/dashboard/project/sfkymoimtjgafvbclnqy/sql
-- ════════════════════════════════════════════════════════

-- ── 1. Add lease_start_date to existing tenants table ──
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS lease_start_date DATE;

-- ── 2: Task Routines / Checklists ──────────────────────
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

-- ── 3: Operational Costs ───────────────────────────────
CREATE TABLE IF NOT EXISTS operational_costs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    cost_type VARCHAR(30) CHECK (cost_type IN ('salary', 'ad_spend', 'subscription', 'other')),
    billing_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ── 4: WhatsApp Logs ───────────────────────────────────
CREATE TABLE IF NOT EXISTS whatsapp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    message_type VARCHAR(30) CHECK (message_type IN ('debt_reminder', 'broadcast')),
    message_body TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'failed')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ── 5: Indexes ─────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_task_routines_status ON task_routines(status);
CREATE INDEX IF NOT EXISTS idx_task_routines_room ON task_routines(room_id);
CREATE INDEX IF NOT EXISTS idx_operational_costs_type ON operational_costs(cost_type);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_tenant ON whatsapp_logs(tenant_id);

-- ── 6: Disable RLS for testing ─────────────────────────
ALTER TABLE IF EXISTS task_routines DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS operational_costs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS whatsapp_logs DISABLE ROW LEVEL SECURITY;

-- ── 7: Car Information for Tenants ──────────────────────
ALTER TABLE tenants 
    ADD COLUMN IF NOT EXISTS has_car BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS car_model VARCHAR(100),
    ADD COLUMN IF NOT EXISTS license_plate VARCHAR(20);

-- Index for car search
CREATE INDEX IF NOT EXISTS idx_tenants_has_car ON tenants(has_car);
CREATE INDEX IF NOT EXISTS idx_tenants_license_plate ON tenants(license_plate);
CREATE INDEX IF NOT EXISTS idx_tenants_car_model ON tenants(car_model);

