-- =============================================================
-- TeknoyCart Database Schema Migration: Cancellations & Returns
-- Target Platform: Supabase / PostgreSQL
-- =============================================================

-- 1. Extend order_status ENUM or check constraint
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        CREATE TYPE order_status AS ENUM (
            'INQUIRY_SENT', 'APPROVED', 'REJECTED', 'PAYMENT_SUBMITTED', 
            'PAYMENT_VERIFIED', 'READY_FOR_PICKUP', 'COMPLETED', 'CANCELLED',
            'RETURN_REQUESTED', 'RETURN_APPROVED', 'RETURN_DECLINED', 'RETURN_COMPLETED'
        );
    END IF;
END $$;

-- Add new values to order_status enum safely if type already exists
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'CANCELLED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RETURN_REQUESTED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RETURN_APPROVED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RETURN_DECLINED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RETURN_COMPLETED';

-- 2. Create order_returns audit table
CREATE TABLE IF NOT EXISTS order_returns (
    return_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reason VARCHAR(100) NOT NULL, -- 'DEFECTIVE', 'WRONG_ITEM', 'MISREPRESENTED', 'OTHER'
    explanation TEXT NULL,
    proof_image_url TEXT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'DECLINED', 'RESOLVED_BY_ADMIN'
    seller_response_note TEXT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE NULL
);

-- 3. Create index for fast performance
CREATE INDEX IF NOT EXISTS idx_order_returns_order ON order_returns(order_id);
CREATE INDEX IF NOT EXISTS idx_order_returns_user ON order_returns(requested_by);

-- 4. Disable RLS for developer testing convenience
ALTER TABLE public.order_returns DISABLE ROW LEVEL SECURITY;
