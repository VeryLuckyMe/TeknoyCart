-- Add last_seen_at column to users table for real-time presence tracking
-- Run this in the Supabase SQL Editor

-- Add the column (nullable, defaults to NULL = never seen / offline)
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NULL;

-- Create an index for fast presence lookups
CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON users (last_seen_at);

-- Allow authenticated users to update their own last_seen_at
-- (The existing RLS policies should already cover UPDATE on users for the own row,
--  but if not, this policy ensures the heartbeat can write)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' 
    AND policyname = 'Users can update own last_seen_at'
  ) THEN
    CREATE POLICY "Users can update own last_seen_at"
      ON users
      FOR UPDATE
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Allow authenticated users to read other users' last_seen_at for presence checks
-- (The existing SELECT policy should already cover this)
