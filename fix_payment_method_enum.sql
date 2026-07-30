-- ============================================================
-- TeknoyCart Database Migration: Expand payment_method ENUM
-- Target: Supabase / PostgreSQL
-- ============================================================

-- 1. Create or extend payment_method ENUM type to accept all variants
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
        CREATE TYPE payment_method AS ENUM (
            'GCASH', 'GCash', 'CASH_ON_PICKUP', 'CASH_ON_DELIVERY', 'Cash on Delivery'
        );
    END IF;
END $$;

-- 2. Safely add values to existing payment_method ENUM type
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'GCASH';
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'GCash';
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'CASH_ON_PICKUP';
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'CASH_ON_DELIVERY';
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'Cash on Delivery';
