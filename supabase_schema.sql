-- ════════════════════════════════════════════════════════
-- Hostel Management System — Phase 1 Database Schema
-- For Supabase PostgreSQL
-- ════════════════════════════════════════════════════════
--
-- Run this in Supabase SQL Editor.
-- RLS is NOT enabled — enable it in production.
-- ════════════════════════════════════════════════════════

-- Rooms Table
CREATE TABLE IF NOT EXISTS rooms (
    id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'void' CHECK (status IN ('occupied', 'void', 'maintenance')),
    monthly_rent NUMERIC(10, 2) NOT NULL
);

-- Tenants Table
CREATE TABLE IF NOT EXISTS tenants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female')),
    room_id INT REFERENCES rooms(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    insurance_amount NUMERIC(10, 2) DEFAULT 0.00,
    insurance_returned BOOLEAN DEFAULT FALSE,
    payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN ('paid', 'unpaid')),
    due_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Masareef (Expenses) Table
CREATE TABLE IF NOT EXISTS masareef (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    category VARCHAR(50) DEFAULT 'general',
    date_incurred DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ── Indexes for common queries ─────────────────────

CREATE INDEX IF NOT EXISTS idx_tenants_room_id ON tenants(room_id);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
CREATE INDEX IF NOT EXISTS idx_tenants_payment_status ON tenants(payment_status);
CREATE INDEX IF NOT EXISTS idx_masareef_date ON masareef(date_incurred);
CREATE INDEX IF NOT EXISTS idx_masareef_category ON masareef(category);

-- ── Seed Data (optional) ───────────────────────────

INSERT INTO rooms (room_number, status, monthly_rent) VALUES
('101', 'void', 2500.00),
('102', 'void', 2500.00),
('201', 'void', 3000.00),
('202', 'void', 3000.00),
('301', 'void', 3500.00)
ON CONFLICT (room_number) DO NOTHING;

-- ── Disable RLS for testing (enable in production) ─

ALTER TABLE rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE tenants DISABLE ROW LEVEL SECURITY;
ALTER TABLE masareef DISABLE ROW LEVEL SECURITY;
