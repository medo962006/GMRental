-- ════════════════════════════════════════════════════════
-- Migration: Tenant national ID cards (storage)
-- ════════════════════════════════════════════════════════
-- 1. Add id_front_url / id_back_url columns to tenants (back is optional)
-- 2. Create 'tenant-ids' storage bucket (public, 10 MB max)
-- 3. Storage policies: public read + authenticated write/update/delete
-- ════════════════════════════════════════════════════════

-- Step 1: Add ID card URL columns to tenants
ALTER TABLE tenants
ADD COLUMN IF NOT EXISTS id_front_url TEXT,
ADD COLUMN IF NOT EXISTS id_back_url TEXT;

-- Step 2: Create storage bucket for tenant ID cards
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'tenant-ids',
  'tenant-ids',
  true,
  10485760,  -- 10 MB in bytes
  ARRAY['image/png', 'image/jpeg']
)
ON CONFLICT (id) DO UPDATE
SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg'];

-- Step 3: Storage policy — allow public read access to tenant-ids
CREATE POLICY "Public read access for tenant-ids"
ON storage.objects FOR SELECT
USING (bucket_id = 'tenant-ids');

-- Step 4: Storage policy — allow authenticated uploads
CREATE POLICY "Allow uploads for tenant-ids"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'tenant-ids');

-- Step 5: Storage policy — allow authenticated updates
CREATE POLICY "Allow updates for tenant-ids"
ON storage.objects FOR UPDATE
USING (bucket_id = 'tenant-ids');

-- Step 6: Storage policy — allow authenticated deletes
CREATE POLICY "Allow deletes for tenant-ids"
ON storage.objects FOR DELETE
USING (bucket_id = 'tenant-ids');