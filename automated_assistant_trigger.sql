-- ==========================================
-- TeknoyCart: Automated Chat Assistant Trigger Cleanup
-- Target Platform: Supabase / PostgreSQL
-- ==========================================
--
-- Running this script in the Supabase SQL Editor will clean up and drop
-- all potential duplicate database triggers listening to messages, 
-- ensuring ONLY ONE or ZERO automated replies are generated.
-- ==========================================

-- Drop all possible duplicate trigger names from the messages table
DROP TRIGGER IF EXISTS trigger_automated_assistant_reply ON messages;
DROP TRIGGER IF EXISTS trigger_automated_reply ON messages;
DROP TRIGGER IF EXISTS automated_assistant_trigger ON messages;
DROP TRIGGER IF EXISTS automated_reply_trigger ON messages;

-- Drop function if it exists
DROP FUNCTION IF EXISTS handle_automated_assistant_reply();
DROP FUNCTION IF EXISTS handle_automated_reply();
