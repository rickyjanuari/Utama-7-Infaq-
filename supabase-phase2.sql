-- =====================================================
-- Phase 2: Advanced Features Schema
-- Jalankan di Supabase SQL Editor
-- =====================================================

-- 1. Campaigns / Program Donasi
CREATE TABLE IF NOT EXISTS campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  target_amount DECIMAL(15,2) DEFAULT 0,
  collected_amount DECIMAL(15,2) DEFAULT 0,
  start_date DATE,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
-- Public read access
CREATE POLICY "Public can view active campaigns" ON campaigns FOR SELECT USING (true);
-- Admin full access
CREATE POLICY "Admin full access campaigns" ON campaigns FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 2. Budgets / RAPB
CREATE TABLE IF NOT EXISTS budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  year INTEGER NOT NULL,
  category VARCHAR(50) NOT NULL,
  amount DECIMAL(15,2) DEFAULT 0,
  type VARCHAR(20) CHECK (type IN ('income', 'expense')), -- income/expense
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(year, category, type)
);

ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin full access budgets" ON budgets FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 3. Assets / Inventory
CREATE TABLE IF NOT EXISTS assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  purchase_date DATE,
  price DECIMAL(15,2) DEFAULT 0,
  current_value DECIMAL(15,2) DEFAULT 0,
  condition VARCHAR(50) DEFAULT 'good', -- good, fair, poor, broken
  location VARCHAR(100),
  quantity INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin full access assets" ON assets FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 4. Recurring Transactions
CREATE TABLE IF NOT EXISTS recurring_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  amount DECIMAL(15,2) DEFAULT 0,
  type VARCHAR(20) NOT NULL, -- infaq_masuk, pengeluaran
  category VARCHAR(50) DEFAULT 'umum',
  interval VARCHAR(20) DEFAULT 'monthly', -- monthly, weekly
  day_of_month INTEGER, -- 1-31
  last_generated DATE,
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin full access recurring" ON recurring_transactions FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 5. Update Transactions Table
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES campaigns(id),
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'approved'; -- approved, pending, rejected

-- 6. Trigger to update campaign collected_amount
CREATE OR REPLACE FUNCTION update_campaign_collected()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.campaign_id IS NOT NULL AND NEW.type = 'infaq_masuk' THEN
    UPDATE campaigns 
    SET collected_amount = (
      SELECT COALESCE(SUM(amount), 0) 
      FROM transactions 
      WHERE campaign_id = NEW.campaign_id AND type = 'infaq_masuk'
    )
    WHERE id = NEW.campaign_id;
  ELSIF (TG_OP = 'DELETE') AND OLD.campaign_id IS NOT NULL AND OLD.type = 'infaq_masuk' THEN
    UPDATE campaigns 
    SET collected_amount = (
      SELECT COALESCE(SUM(amount), 0) 
      FROM transactions 
      WHERE campaign_id = OLD.campaign_id AND type = 'infaq_masuk'
    )
    WHERE id = OLD.campaign_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_campaign_update ON transactions;
CREATE TRIGGER trigger_campaign_update
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_campaign_collected();
