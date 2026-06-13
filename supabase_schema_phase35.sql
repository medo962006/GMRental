-- ════════════════════════════════════════════════════════
-- Phase 3.5: App Version Tracking for OTA Updates
-- Run in Supabase SQL Editor
-- ════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS app_versions (
    id SERIAL PRIMARY KEY,
    min_required_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    latest_patch_number INT NOT NULL DEFAULT 0,
    force_update_required BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Insert initial version record
INSERT INTO app_versions (min_required_version, latest_patch_number, force_update_required)
VALUES ('1.0.0', 0, FALSE)
ON CONFLICT DO NOTHING;

-- Disable RLS for testing
ALTER TABLE IF EXISTS app_versions DISABLE ROW LEVEL SECURITY;
