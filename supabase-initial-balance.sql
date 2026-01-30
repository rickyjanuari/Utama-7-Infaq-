-- =====================================================
-- Add Initial Balance (Saldo Awal) Support
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Add initial_balance column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS initial_balance DECIMAL(15,2) DEFAULT 0;

-- 2. Add initial_penyisihan column for penyisihan fund
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS initial_penyisihan DECIMAL(15,2) DEFAULT 0;

-- 3. Update RLS policy to allow users to read their own initial balance
-- (Already covered by existing policies)

-- 4. Create function to get user's balance including initial
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
    total_saldo DECIMAL,
    total_masuk DECIMAL,
    total_keluar DECIMAL,
    saldo_penyisihan DECIMAL,
    initial_balance DECIMAL,
    initial_penyisihan DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(p.initial_balance, 0) + 
            COALESCE(SUM(CASE WHEN t.type = 'infaq_masuk' AND NOT t.is_penyisihan THEN t.amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN t.type = 'pengeluaran' AND NOT t.is_penyisihan THEN t.amount ELSE 0 END), 0) as total_saldo,
        COALESCE(SUM(CASE WHEN t.type = 'infaq_masuk' AND NOT t.is_penyisihan THEN t.amount ELSE 0 END), 0) as total_masuk,
        COALESCE(SUM(CASE WHEN t.type = 'pengeluaran' AND NOT t.is_penyisihan THEN t.amount ELSE 0 END), 0) as total_keluar,
        COALESCE(p.initial_penyisihan, 0) +
            COALESCE(SUM(CASE WHEN t.is_penyisihan AND t.type = 'infaq_masuk' THEN t.amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN t.is_penyisihan AND t.type = 'pengeluaran' THEN t.amount ELSE 0 END), 0) as saldo_penyisihan,
        COALESCE(p.initial_balance, 0) as initial_balance,
        COALESCE(p.initial_penyisihan, 0) as initial_penyisihan
    FROM profiles p
    LEFT JOIN transactions t ON TRUE
    WHERE (p_user_id IS NULL OR p.id = p_user_id)
    GROUP BY p.initial_balance, p.initial_penyisihan
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
