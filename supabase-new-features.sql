-- =====================================================
-- Phase 1: Categories & Target Infaq
-- Jalankan di Supabase SQL Editor
-- =====================================================

-- 1. Add category column to transactions
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'umum';

-- 2. Add monthly_target to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS monthly_target DECIMAL(15,2) DEFAULT 0;

-- 3. Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  user_name VARCHAR(255),
  action VARCHAR(20), -- INSERT, UPDATE, DELETE
  table_name VARCHAR(50),
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Enable RLS on audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 5. Policy: Only admin can view audit logs
CREATE POLICY "Admin can view audit logs" ON audit_logs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  )
);

-- 6. Policy: All authenticated users can insert audit logs
CREATE POLICY "Users can insert audit logs" ON audit_logs
FOR INSERT TO authenticated
WITH CHECK (true);

-- 7. Trigger function to log changes
CREATE OR REPLACE FUNCTION log_transaction_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_name VARCHAR(255);
BEGIN
  -- Get user name
  SELECT name INTO v_user_name FROM profiles WHERE id = auth.uid();
  
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, new_data)
    VALUES (auth.uid(), v_user_name, 'INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, old_data, new_data)
    VALUES (auth.uid(), v_user_name, 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, old_data)
    VALUES (auth.uid(), v_user_name, 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create trigger
DROP TRIGGER IF EXISTS transaction_audit_trigger ON transactions;
CREATE TRIGGER transaction_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION log_transaction_changes();

-- Verification
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'transactions' AND column_name = 'category';
