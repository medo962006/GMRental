-- ════════════════════════════════════════════════════════
-- HOSTEL MANAGER v2 — COMPLETE SCHEMA
-- Run this in Supabase SQL Editor
-- ════════════════════════════════════════════════════════

-- 1. BUILDINGS TABLE
CREATE TABLE IF NOT EXISTS buildings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Insert default buildings
INSERT INTO buildings (id, name, name_ar) VALUES
    (1, 'Gawy', 'المبنى الرئيسي'),
    (2, 'Baraka Building', 'مبنى بركة')
ON CONFLICT (id) DO NOTHING;

-- 2. ADD building_id TO ROOMS (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='rooms' AND column_name='building_id') THEN
        ALTER TABLE rooms ADD COLUMN building_id INT DEFAULT 1 REFERENCES buildings(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='rooms' AND column_name='floor') THEN
        ALTER TABLE rooms ADD COLUMN floor VARCHAR(10) DEFAULT 'G';
    END IF;
END$$;

-- 3. ADD building_id TO TENANTS (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tenants' AND column_name='building_id') THEN
        ALTER TABLE tenants ADD COLUMN building_id INT DEFAULT 1 REFERENCES buildings(id);
    END IF;
END$$;

-- 4. INSURANCE LEDGER TABLE
CREATE TABLE IF NOT EXISTS insurance_ledger (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    total_agreed_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    amount_paid_so_far NUMERIC(10,2) NOT NULL DEFAULT 0,
    remaining_balance NUMERIC(10,2) GENERATED ALWAYS AS (total_agreed_amount - amount_paid_so_far) STORED,
    due_date_for_remaining DATE,
    status VARCHAR(20) DEFAULT 'partial' CHECK (status IN ('partial', 'fully_paid', 'refunded', 'forfeited')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 5. INSURANCE TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS insurance_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    insurance_id UUID NOT NULL REFERENCES insurance_ledger(id) ON DELETE CASCADE,
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('payment_received', 'refund_paid', 'deduction_spend', 'adjustment')),
    amount NUMERIC(10,2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 6. ADMIN NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS admin_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    category VARCHAR(30) DEFAULT 'general' CHECK (category IN ('rent_due', 'insurance_alert', 'task_pending', 'general', 'payment_received', 'tenant_checkout')),
    is_read_by_admin JSONB DEFAULT '[]'::jsonb,
    related_tenant_id UUID,
    related_room_id INT,
    priority VARCHAR(10) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 7. TASK ROUTINES TABLE (if not exists from Phase 2)
CREATE TABLE IF NOT EXISTS task_routines (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_to VARCHAR(50) DEFAULT 'Worker',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    room_id INT REFERENCES rooms(id),
    trigger_context VARCHAR(50) DEFAULT 'Manual',
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 8. OPERATIONAL COSTS TABLE (if not exists from Phase 2)
CREATE TABLE IF NOT EXISTS operational_costs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    cost_type VARCHAR(50) DEFAULT 'general',
    billing_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 9. WHATSAPP LOGS TABLE (if not exists from Phase 2)
CREATE TABLE IF NOT EXISTS whatsapp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    message_type VARCHAR(30) DEFAULT 'manual',
    message_body TEXT,
    status VARCHAR(20) DEFAULT 'sent',
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ════════════════════════════════════════════════════════
-- INDEXES
-- ════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_rooms_building ON rooms(building_id);
CREATE INDEX IF NOT EXISTS idx_rooms_floor ON rooms(floor);
CREATE INDEX IF NOT EXISTS idx_tenants_building ON tenants(building_id);
CREATE INDEX IF NOT EXISTS idx_tenants_room ON tenants(room_id);
CREATE INDEX IF NOT EXISTS idx_insurance_tenant ON insurance_ledger(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insurance_status ON insurance_ledger(status);
CREATE INDEX IF NOT EXISTS idx_notifications_category ON admin_notifications(category);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON admin_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_task_routines_status ON task_routines(status);

-- ════════════════════════════════════════════════════════
-- DISABLE RLS FOR ALL TABLES (testing/development)
-- ════════════════════════════════════════════════════════
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t);
    END LOOP;
END$$;

-- ════════════════════════════════════════════════════════
-- SEED BUILDING 2 DATA (Baraka Building)
-- ════════════════════════════════════════════════════════

-- Ground Floor rooms (1-13)
INSERT INTO rooms (room_number, status, monthly_rent, building_id, floor) VALUES
    ('1', 'occupied', 10000, 2, 'G'),
    ('2', 'occupied', 0, 2, 'G'),
    ('3', 'occupied', 9500, 2, 'G'),
    ('4', 'occupied', 12500, 2, 'G'),
    ('5', 'occupied', 10500, 2, 'G'),
    ('6', 'occupied', 9500, 2, 'G'),
    ('7', 'occupied', 8000, 2, 'G'),
    ('8', 'occupied', 9500, 2, 'G'),
    ('9', 'occupied', 10500, 2, 'G'),
    ('10', 'occupied', 12500, 2, 'G'),
    ('11', 'occupied', 8000, 2, 'G'),
    ('12', 'occupied', 8000, 2, 'G'),
    ('13', 'occupied', 9500, 2, 'G')
ON CONFLICT (room_number) DO NOTHING;

-- First Floor rooms (1-15)
INSERT INTO rooms (room_number, status, monthly_rent, building_id, floor) VALUES
    ('1', 'occupied', 12000, 2, 'F'),
    ('2', 'occupied', 10000, 2, 'F'),
    ('3', 'void', 0, 2, 'F'),
    ('4', 'occupied', 7000, 2, 'F'),
    ('5', 'occupied', 9000, 2, 'F'),
    ('6', 'occupied', 9500, 2, 'F'),
    ('7', 'void', 0, 2, 'F'),
    ('8', 'occupied', 8000, 2, 'F'),
    ('9', 'void', 0, 2, 'F'),
    ('10', 'occupied', 10000, 2, 'F'),
    ('11', 'occupied', 11000, 2, 'F'),
    ('12', 'occupied', 10000, 2, 'F'),
    ('13', 'occupied', 10000, 2, 'F'),
    ('14', 'void', 0, 2, 'F'),
    ('15', 'occupied', 10000, 2, 'F')
ON CONFLICT (room_number) DO NOTHING;

-- Second Floor rooms (1-4)
INSERT INTO rooms (room_number, status, monthly_rent, building_id, floor) VALUES
    ('1', 'occupied', 13500, 2, 'S'),
    ('2', 'occupied', 13000, 2, 'S'),
    ('3', 'void', 0, 2, 'S'),
    ('4', 'void', 0, 2, 'S')
ON CONFLICT (room_number) DO NOTHING;

-- Note: Building 2 tenants should be inserted after rooms are created
-- Use a separate script or the app's UI to add tenants to Building 2 rooms
