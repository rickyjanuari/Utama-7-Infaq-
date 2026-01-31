-- =====================================================
-- Special Access for cempakapramudita@gmail.com
-- Menjadikan user ini ADMIN agar bisa Edit, Delete, dan Add laporan sepenuhnya.
-- =====================================================

-- 1. Sync Profile jika Auth User sudah ada tapi Profile belum ada
DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Coba cari ID user di tabel auth.users
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'cempakapramudita@gmail.com';

  -- Jika user ditemukan di Auth, pastikan Profile ada dan jadi Admin
  IF v_user_id IS NOT NULL THEN
    INSERT INTO profiles (id, email, name, role, can_view_penyisihan)
    VALUES (v_user_id, 'cempakapramudita@gmail.com', 'Cempaka', 'admin', true)
    ON CONFLICT (id) DO UPDATE
    SET role = 'admin',
        can_view_penyisihan = true;
  END IF;
END
$$;

-- 2. Update trigger untuk user baru (User belum daftar sama sekali)
-- Trigger ini akan memastikan saat dia daftar nanti, otomatis jadi ADMIN
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, name, role, can_view_penyisihan)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        -- Force Admin role if email matches, otherwise default to 'guru'
        CASE 
            WHEN NEW.email = 'cempakapramudita@gmail.com' THEN 'admin'
            ELSE COALESCE(NEW.raw_user_meta_data->>'role', 'guru')
        END,
        COALESCE((NEW.raw_user_meta_data->>'can_view_penyisihan')::boolean, FALSE)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. (Optional) Pastikan Guru tetap bisa Add/Edit (jika role user tetap Guru)
-- Pastikan policy ini ada (dari supabase-fix-rls.sql)
-- Admin & Guru can insert transactions
DROP POLICY IF EXISTS "Admin and Guru can insert transactions" ON transactions;
CREATE POLICY "Admin and Guru can insert transactions" ON transactions
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND (profiles.role = 'admin' OR profiles.role = 'guru')
  )
);

-- Admin & Guru can update transactions
DROP POLICY IF EXISTS "Admin and Guru can update transactions" ON transactions;
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

-- Note: DELETE biasanya hanya Admin, tapi jika user ini jadi Admin, dia aman.
