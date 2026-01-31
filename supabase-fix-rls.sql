-- =====================================================
-- RLS Policies untuk Admin dan Guru bisa Edit/Delete
-- Jalankan di Supabase SQL Editor
-- =====================================================

-- 1. Hapus trigger bermasalah (jika ada)
DROP TRIGGER IF EXISTS on_transaction_change ON transactions;
DROP FUNCTION IF EXISTS notify_google_sheets();

-- 2. Tambah kolom saldo awal (jika belum ada)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS initial_balance DECIMAL(15,2) DEFAULT 0;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS initial_penyisihan DECIMAL(15,2) DEFAULT 0;

-- 3. Hapus policies lama yang mungkin conflict
DROP POLICY IF EXISTS "Admin can update all transactions" ON transactions;
DROP POLICY IF EXISTS "Guru can update all transactions" ON transactions;
DROP POLICY IF EXISTS "Admin and Guru can update transactions" ON transactions;
DROP POLICY IF EXISTS "Admin and Guru can delete transactions" ON transactions;
DROP POLICY IF EXISTS "Admin and Guru can insert transactions" ON transactions;

-- 4. Buat policy untuk INSERT - Admin & Guru bisa insert
CREATE POLICY "Admin and Guru can insert transactions" ON transactions
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND (profiles.role = 'admin' OR profiles.role = 'guru')
  )
);

-- 4. Buat policy untuk UPDATE - Admin & Guru bisa update semua
CREATE POLICY "Admin and Guru can update transactions" ON transactions
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND (profiles.role = 'admin' OR profiles.role = 'guru')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND (profiles.role = 'admin' OR profiles.role = 'guru')
  )
);

-- 5. Buat policy untuk DELETE - Admin & Guru bisa delete semua
CREATE POLICY "Admin and Guru can delete transactions" ON transactions
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND (profiles.role = 'admin' OR profiles.role = 'guru')
  )
);

-- 6. Verifikasi policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'transactions';
