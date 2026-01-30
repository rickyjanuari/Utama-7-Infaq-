-- Add QRIS URL column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS qris_url TEXT;

-- Update RLS if needed (usually profiles policy allows update for own profile)
