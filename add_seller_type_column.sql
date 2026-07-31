-- =====================================================
-- TeknoyCart Migration: Add seller_type to users table
-- Purpose: Distinguish Student/Personal vs Org/Shop sellers
-- Run this in: Supabase Dashboard > SQL Editor
-- =====================================================

-- 1. Add seller_type column to users table
--    NULL for BUYER accounts (they have no seller type)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS seller_type VARCHAR(20)
  CHECK (seller_type IN ('STUDENT', 'ORG'));

-- 2. (Optional) Back-fill existing SELLER rows as 'STUDENT'
--    since all existing sellers registered with a Student ID
UPDATE users
SET seller_type = 'STUDENT'
WHERE role = 'SELLER' AND seller_type IS NULL;
