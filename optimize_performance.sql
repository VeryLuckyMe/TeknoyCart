-- =============================================================
-- TeknoyCart: Database Performance Optimization Script
-- Target Platform: Supabase / PostgreSQL
-- Run this directly in the Supabase SQL Editor to speed up index lookup speeds (FR-18, NFR-01)
-- =============================================================

-- 1. Indexing Chat Room Lookups (Speeds up loading the chat rooms inbox list and checks)
CREATE INDEX IF NOT EXISTS idx_chats_buyer_id ON public.chats(buyer_id);
CREATE INDEX IF NOT EXISTS idx_chats_seller_id ON public.chats(seller_id);
CREATE INDEX IF NOT EXISTS idx_chats_buyer_seller ON public.chats(buyer_id, seller_id);

-- 2. Indexing Message History Sent Order (Speeds up message history loading)
CREATE INDEX IF NOT EXISTS idx_messages_sent_at_desc ON public.messages(sent_at DESC);

-- 3. Indexing Users Roles and Verification Status (Speeds up login authentication guards)
CREATE INDEX IF NOT EXISTS idx_users_email_hash ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- 4. Indexing Orders for Fast Verification Hub Loads (Web dashboard optimization)
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON public.orders(seller_id);

-- Confirm execution
SELECT 'Performance indexes successfully created! ⚡' AS status;
