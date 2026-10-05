-- SwagPay Database Schema (Supabase PostgreSQL)
-- Matches .env DATABASE_URL

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(32),
  pin VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'TELLER', -- 'TELLER', 'ADMIN', 'SUPER_ADMIN'
  "posId" VARCHAR(64),
  "pinHash" TEXT,
  "deviceId" VARCHAR(128),
  active INTEGER NOT NULL DEFAULT 1,
  "singleTxnLimit" DOUBLE PRECISION DEFAULT 500000,
  "dailyLimit" DOUBLE PRECISION DEFAULT 5000000,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Issued sessions, revocable by an administrator.
CREATE TABLE IF NOT EXISTS sessions (
  "jti" VARCHAR(64) PRIMARY KEY,
  "userId" VARCHAR(64) NOT NULL REFERENCES users(id),
  "deviceId" VARCHAR(128),
  "deviceName" VARCHAR(128),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "lastSeenAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "revokedAt" TIMESTAMPTZ
);

-- Password reset requests (OTP and reset tokens).
CREATE TABLE IF NOT EXISTS password_resets (
  id VARCHAR(64) PRIMARY KEY,
  "userId" VARCHAR(64) NOT NULL REFERENCES users(id),
  token VARCHAR(128) NOT NULL,
  otp VARCHAR(16) NOT NULL,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "usedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pos_terminals (
  id VARCHAR(64) PRIMARY KEY,
  code VARCHAR(64) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  location VARCHAR(255),
  active INTEGER NOT NULL DEFAULT 1,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
  id VARCHAR(64) PRIMARY KEY,
  reference VARCHAR(128) UNIQUE NOT NULL,
  "gatewayReference" VARCHAR(128),
  "tellerId" VARCHAR(64) REFERENCES users(id),
  "posId" VARCHAR(64) REFERENCES pos_terminals(id),
  network VARCHAR(32) NOT NULL DEFAULT 'MTN', -- 'MTN', 'VODAFONE', 'AIRTELTIGO'
  "momoNumber" VARCHAR(32) NOT NULL,
  "customerName" VARCHAR(255),
  amount DOUBLE PRECISION NOT NULL,
  fee DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  "totalCharged" DOUBLE PRECISION NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'SUCCESS', 'FAILED'
  "failureReason" TEXT,
  "receiptNumber" VARCHAR(64),
  reconciled INTEGER NOT NULL DEFAULT 0,
  "reconciliationDiff" TEXT,
  metadata TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refund_requests (
  id VARCHAR(64) PRIMARY KEY,
  "transactionId" VARCHAR(64) REFERENCES transactions(id),
  reference VARCHAR(128) NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  "tellerId" VARCHAR(64) REFERENCES users(id),
  "tellerName" VARCHAR(255) NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED'
  "reviewedBy" VARCHAR(255),
  "reviewedAt" TIMESTAMPTZ,
  "rejectionReason" TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shifts (
  id VARCHAR(64) PRIMARY KEY,
  "tellerId" VARCHAR(64) REFERENCES users(id),
  "tellerName" VARCHAR(255) NOT NULL,
  "posId" VARCHAR(64),
  "startTime" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "endTime" TIMESTAMPTZ,
  "totalCollected" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  "totalCount" INTEGER NOT NULL DEFAULT 0,
  "successCount" INTEGER NOT NULL DEFAULT 0,
  "failedCount" INTEGER NOT NULL DEFAULT 0,
  "isClosed" INTEGER NOT NULL DEFAULT 0,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(64) PRIMARY KEY,
  "actorId" VARCHAR(64),
  action VARCHAR(128) NOT NULL,
  "targetType" VARCHAR(64),
  "targetId" VARCHAR(64),
  metadata TEXT,
  "ipAddress" VARCHAR(64),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reconciliation_reports (
  id VARCHAR(64) PRIMARY KEY,
  "runDate" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "totalLocal" INTEGER NOT NULL DEFAULT 0,
  "totalGateway" INTEGER NOT NULL DEFAULT 0,
  "matchedCount" INTEGER NOT NULL DEFAULT 0,
  "mismatchCount" INTEGER NOT NULL DEFAULT 0,
  "totalVolumeGhs" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  details TEXT,
  "notifiedAdmin" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- No users are seeded by design. Accounts are created by an authenticated admin via
-- POST /api/users (hashed secret) and the bootstrap superuser comes from the
-- ADMIN_BOOTSTRAP_EMAIL / ADMIN_BOOTSTRAP_PASSWORD deployment secrets.

-- Seed Default POS Terminal if not exist
INSERT INTO pos_terminals (id, code, name, location, active)
VALUES
  ('pos_01', 'POS-01', 'Till 1 - Accra Mall', 'Accra Mall Food Court', 1)
ON CONFLICT (id) DO NOTHING;
