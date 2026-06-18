-- ════════════════════════════════════════════════════════
-- Migration: Add receipt support to Masareef (Expenses)
-- ════════════════════════════════════════════════════════
-- 1. Add receipt_url column to masareef table
-- 2. Create 'receipts' storage bucket (public, 20 MB max)
-- ════════════════════════════════════════════════════════

-- Step 1: Add receipt_url column
ALTER TABLE masareef
ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- Step 2: Create storage bucket for receipts
-- Run this in Supabase SQL Editor:
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'receipts',
  'receipts',
  true,
  20971520,  -- 20 MB in bytes
  ARRAY['image/png', 'image/jpeg']
)
ON CONFLICT (id) DO UPDATE
SET
  public = true,
  file_size_limit = 20971520,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg'];

-- Step 3: Storage policy — allow public read access to receipts
CREATE POLICY "Public read access for receipts"
ON storage.objects FOR SELECT
USING (bucket_id = 'receipts');

-- Step 4: Storage policy — allow authenticated uploads
CREATE POLICY "Allow uploads for receipts"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'receipts');

-- Step 5: Storage policy — allow authenticated updates
CREATE POLICY "Allow updates for receipts"
ON storage.objects FOR UPDATE
USING (bucket_id = 'receipts');

-- Step 6: Storage policy — allow authenticated deletes
CREATE POLICY "Allow deletes for receipts"
ON storage.objects FOR DELETE
USING (bucket_id = 'receipts');
