-- =====================================================
-- RLS Policy untuk Public Read Access
-- Jalankan di Supabase SQL Editor
-- =====================================================

-- 1. Allow public (anon) to READ non-penyisihan transactions
DROP POLICY IF EXISTS "Public can view non-penyisihan transactions" ON transactions;

CREATE POLICY "Public can view non-penyisihan transactions" ON transactions
FOR SELECT TO anon
USING (is_penyisihan = false);

-- 2. Allow public (anon) to READ initial_balance from profiles
DROP POLICY IF EXISTS "Public can view initial balance" ON profiles;

CREATE POLICY "Public can view initial balance" ON profiles
FOR SELECT TO anon
USING (true);

-- Verifikasi
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename IN ('transactions', 'profiles');
