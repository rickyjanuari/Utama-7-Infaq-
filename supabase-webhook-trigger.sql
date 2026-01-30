-- =====================================================
-- Supabase Database Webhook Trigger
-- Untuk mengirim data ke Google Sheets saat ada perubahan
-- =====================================================

-- Jalankan SQL ini di Supabase SQL Editor

-- 1. Buat function untuk mengirim webhook
CREATE OR REPLACE FUNCTION notify_google_sheets()
RETURNS TRIGGER AS $$
DECLARE
  payload json;
  webhook_url text := 'GANTI_DENGAN_GOOGLE_APPS_SCRIPT_WEB_APP_URL';
BEGIN
  -- Buat payload berdasarkan event type
  IF TG_OP = 'DELETE' THEN
    payload := json_build_object(
      'type', 'DELETE',
      'table', TG_TABLE_NAME,
      'old_record', row_to_json(OLD)
    );
  ELSE
    payload := json_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', row_to_json(NEW)
    );
  END IF;

  -- Kirim HTTP request ke Google Apps Script
  -- Note: Membutuhkan pg_net extension atau Supabase Edge Function
  PERFORM net.http_post(
    url := webhook_url,
    headers := '{"Content-Type": "application/json"}',
    body := payload::text
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Buat trigger untuk transactions table
DROP TRIGGER IF EXISTS on_transaction_change ON transactions;
CREATE TRIGGER on_transaction_change
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION notify_google_sheets();

-- =====================================================
-- CATATAN PENTING:
-- =====================================================
-- Supabase free tier tidak support pg_net untuk HTTP calls.
-- Alternatif yang lebih baik: gunakan Supabase Edge Function
-- atau sync manual via Apps Script timer.
-- 
-- Lihat file: supabase-edge-function.ts
-- =====================================================
