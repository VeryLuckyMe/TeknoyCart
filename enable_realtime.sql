-- =============================================================
-- TeknoyCart: Enable Realtime & Disable RLS for Messaging
-- Target Platform: Supabase / PostgreSQL
-- Run this directly in the Supabase SQL Editor (FR-15, NFR-03)
-- =============================================================

-- 1. Enable Supabase Realtime replication on the messages and chats tables
-- This allows the mobile app to listen to real-time INSERT events when a user sends a message.
begin;
  -- Remove tables from publication if they exist to avoid duplicate errors
  alter publication supabase_realtime drop table if exists public.messages;
  alter publication supabase_realtime drop table if exists public.chats;

  -- Add tables to the realtime publication
  alter publication supabase_realtime add table public.messages;
  alter publication supabase_realtime add table public.chats;
commit;

-- 2. Configure Row Level Security (RLS)
-- If RLS is enabled in your Supabase dashboard, clients cannot read or write messages
-- from other accounts unless correct policies are set.
--
-- Easiest/Recommended option for development/testing: Disable RLS for chat tables
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries DISABLE ROW LEVEL SECURITY;

-- OPTIONAL: If you want to keep RLS ENABLED and use policies instead, run these:
/*
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Policy to allow authenticated users to insert messages in rooms they are part of
CREATE POLICY "Allow users to insert messages in their chats" 
ON public.messages FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.chats 
    WHERE chats.chat_id = messages.chat_id 
    AND (chats.buyer_id = auth.uid() OR chats.seller_id = auth.uid())
  )
);

-- Policy to allow users to view messages in rooms they are part of
CREATE POLICY "Allow users to view messages in their chats" 
ON public.messages FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.chats 
    WHERE chats.chat_id = messages.chat_id 
    AND (chats.buyer_id = auth.uid() OR chats.seller_id = auth.uid())
  )
);
*/

SELECT 'Supabase Realtime and RLS successfully configured! 💬⚡' AS status;
