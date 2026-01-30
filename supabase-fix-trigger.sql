-- =====================================================
-- PERBAIKAN: Hapus Trigger Webhook yang Error
-- Jalankan di Supabase SQL Editor
-- =====================================================

-- 1. Hapus trigger yang bermasalah
DROP TRIGGER IF EXISTS on_transaction_change ON transactions;

-- 2. Hapus function yang menggunakan net schema
DROP FUNCTION IF EXISTS notify_google_sheets();

-- Selesai! Error sudah tidak akan muncul lagi.
-- 
-- CATATAN:
-- Sync ke Google Sheets sudah dilakukan dari frontend (client-side)
-- melalui file sheets.ts, jadi tidak perlu webhook dari database.
