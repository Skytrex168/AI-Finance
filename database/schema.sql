-- AI Personal Finance & Investment Advisor : PostgreSQL schema
CREATE TABLE roles (
  id SMALLSERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  role_id SMALLINT NOT NULL REFERENCES roles(id),
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE refresh_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE accounts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  name VARCHAR(80) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('CASH','BANK','SAVINGS','CARD','WALLET')),
  balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- user_id NULL = system default category
CREATE TABLE categories (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(60) NOT NULL,
  kind VARCHAR(10) NOT NULL CHECK (kind IN ('INCOME','EXPENSE')),
  UNIQUE (user_id, name)
);

CREATE TABLE transactions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  account_id BIGINT NOT NULL REFERENCES accounts(id),
  category_id BIGINT REFERENCES categories(id),
  type VARCHAR(10) NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  description VARCHAR(255) NOT NULL,
  txn_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ai_confidence NUMERIC(4,3),
  anomaly_score NUMERIC(4,3) NOT NULL DEFAULT 0,
  is_anomaly BOOLEAN NOT NULL DEFAULT FALSE,
  anomaly_reason VARCHAR(255),
  idempotency_key VARCHAR(80),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, idempotency_key)
);
CREATE INDEX idx_txn_user_date ON transactions(user_id, txn_date DESC);
CREATE INDEX idx_txn_user_cat ON transactions(user_id, category_id);

CREATE TABLE budgets (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  category_id BIGINT NOT NULL REFERENCES categories(id),
  month CHAR(7) NOT NULL,                      -- YYYY-MM
  limit_amount NUMERIC(14,2) NOT NULL CHECK (limit_amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, category_id, month)
);

CREATE TABLE goals (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  name VARCHAR(100) NOT NULL,
  target_amount NUMERIC(14,2) NOT NULL CHECK (target_amount > 0),
  saved_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE debts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  name VARCHAR(100) NOT NULL,
  principal NUMERIC(14,2) NOT NULL CHECK (principal > 0),
  remaining NUMERIC(14,2) NOT NULL,
  interest_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  due_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Simulated market instruments (no real trading)
CREATE TABLE assets (
  id BIGSERIAL PRIMARY KEY,
  symbol VARCHAR(12) NOT NULL UNIQUE,
  name VARCHAR(80) NOT NULL,
  asset_type VARCHAR(10) NOT NULL CHECK (asset_type IN ('STOCK','FUND','BOND','CRYPTO')),
  price NUMERIC(14,4) NOT NULL,
  risk_level SMALLINT NOT NULL CHECK (risk_level BETWEEN 1 AND 5)
);

-- 1:1 user <-> portfolio ; N:M portfolio/asset resolved by holdings
CREATE TABLE portfolios (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id),
  cash NUMERIC(14,2) NOT NULL DEFAULT 10000,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE portfolio_holdings (
  portfolio_id BIGINT NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  asset_id BIGINT NOT NULL REFERENCES assets(id),
  quantity NUMERIC(18,6) NOT NULL CHECK (quantity >= 0),
  avg_price NUMERIC(14,4) NOT NULL,
  PRIMARY KEY (portfolio_id, asset_id)
);

CREATE TABLE recommendations (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  kind VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id),
  action VARCHAR(60) NOT NULL,
  detail VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_user ON audit_logs(user_id, created_at DESC);
