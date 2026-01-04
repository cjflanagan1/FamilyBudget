require('dotenv').config();
const { pool } = require('./database');

const schema = `
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('parent', 'child')),
  phone_number VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cards table (linked Amex cards)
CREATE TABLE IF NOT EXISTS cards (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  plaid_account_id VARCHAR(255) UNIQUE,
  plaid_access_token VARCHAR(255),
  last_four VARCHAR(4),
  nickname VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  card_id INTEGER REFERENCES cards(id) ON DELETE CASCADE,
  plaid_transaction_id VARCHAR(255) UNIQUE,
  amount DECIMAL(10, 2) NOT NULL,
  merchant_name VARCHAR(255),
  category VARCHAR(100),
  date DATE NOT NULL,
  is_recurring BOOLEAN DEFAULT FALSE,
  is_food_delivery BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Spending limits table
CREATE TABLE IF NOT EXISTS spending_limits (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  monthly_limit DECIMAL(10, 2) NOT NULL,
  current_spend DECIMAL(10, 2) DEFAULT 0,
  reset_day INTEGER DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  merchant_name VARCHAR(255) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  billing_cycle VARCHAR(20) DEFAULT 'monthly',
  next_renewal_date DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification settings table
CREATE TABLE IF NOT EXISTS notification_settings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  alert_mode VARCHAR(20) DEFAULT 'all' CHECK (alert_mode IN ('all', 'weekly', 'threshold')),
  threshold_amount DECIMAL(10, 2) DEFAULT 25.00,
  weekly_summary_day INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alerts sent table (to prevent duplicate notifications)
CREATE TABLE IF NOT EXISTS alerts_sent (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE CASCADE,
  alert_type VARCHAR(50) NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, transaction_id, alert_type)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);
CREATE INDEX IF NOT EXISTS idx_transactions_card_id ON transactions(card_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_next_renewal ON subscriptions(next_renewal_date);
CREATE INDEX IF NOT EXISTS idx_alerts_sent_transaction ON alerts_sent(transaction_id);

-- Insert default family members
INSERT INTO users (name, role, phone_number) VALUES
  ('Terry', 'parent', NULL),
  ('CJ', 'parent', NULL),
  ('Paige', 'child', NULL),
  ('Haley', 'child', NULL)
ON CONFLICT DO NOTHING;

-- Insert default spending limits (can be updated later)
INSERT INTO spending_limits (user_id, monthly_limit)
SELECT id, 500.00 FROM users
ON CONFLICT (user_id) DO NOTHING;

-- Insert default notification settings for parents
INSERT INTO notification_settings (user_id, alert_mode)
SELECT id, 'all' FROM users WHERE role = 'parent'
ON CONFLICT (user_id) DO NOTHING;
`;

async function migrate() {
  try {
    console.log('Running database migrations...');
    await pool.query(schema);
    console.log('Migrations completed successfully!');

    // Verify users were created
    const result = await pool.query('SELECT name, role FROM users ORDER BY id');
    console.log('Family members:', result.rows);

    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

migrate();
