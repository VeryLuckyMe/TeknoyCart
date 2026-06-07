-- =============================================================
-- TeknoyCart: GCash Integration and Payment Columns Script
-- Target Platform: Supabase / PostgreSQL
-- =============================================================

-- 1. Add GCash Number column to users table for public profiles
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS gcash_number TEXT;

-- 2. Add payment reference columns to orders table
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_reference TEXT,
ADD COLUMN IF NOT EXISTS payment_proof_url TEXT;

-- Confirm execution status
SELECT 'Payment schema update columns successfully checked/added! 💳' AS status;
