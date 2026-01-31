-- Add metadata column to transactions table for flexible data storage
-- This is used for 'Santunan' details (student_name, class, parent_rep) or other future category-specific data.

ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Optional: Create an index on metadata for faster JSON searching if needed later
CREATE INDEX IF NOT EXISTS idx_transactions_metadata ON transactions USING gin (metadata);
