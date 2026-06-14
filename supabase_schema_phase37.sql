-- ════════════════════════════════════════════════════════
-- Phase 3.7: Insurance Ledger & Notifications
-- Run in Supabase SQL Editor
-- ════════════════════════════════════════════════════════

-- Advanced Insurance Ledger Table
CREATE TABLE IF NOT EXISTS insurance_ledger (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    total_agreed_amount NUMERIC(10, 2) NOT NULL,
    amount_paid_so_far NUMERIC(10, 2) DEFAULT 0.00,
    remaining_balance NUMERIC(10, 2) GENERATED ALWAYS AS (total_agreed_amount - amount_paid_so_far) STORED,
    due_date_for_remaining DATE,
    status VARCHAR(30) DEFAULT 'partial' CHECK (status IN ('partial', 'fully_paid', 'refunded', 'forfeited')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Insurance Transactions History
CREATE TABLE IF NOT EXISTS insurance_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    insurance_id UUID REFERENCES insurance_ledger(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) CHECK (transaction_type IN ('payment_received', 'refund_paid', 'deduction_spend')),
    amount NUMERIC(10, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Unified Admin Notification Queue
CREATE TABLE IF NOT EXISTS admin_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    category VARCHAR(30) CHECK (category IN ('rent_due', 'insurance_alert', 'task_pending')),
    is_read_by_admin JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_insurance_ledger_tenant ON insurance_ledger(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insurance_ledger_status ON insurance_ledger(status);
CREATE INDEX IF NOT EXISTS idx_insurance_transactions_insurance ON insurance_transactions(insurance_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_category ON admin_notifications(category);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_created ON admin_notifications(created_at DESC);

-- Disable RLS for initial testing
ALTER TABLE insurance_ledger DISABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE admin_notifications DISABLE ROW LEVEL SECURITY;
