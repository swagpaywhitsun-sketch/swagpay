-- SwagPay auth hardening migration (idempotent — safe to re-run)
-- Apply with: psql "$DATABASE_URL" -f database/auth-migration.sql

ALTER TABLE users ADD COLUMN IF NOT EXISTS "pinHash" TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS "deviceId" VARCHAR(128);

-- Weak bootstrap PINs must be replaced by the operator before production use.
-- These statements only neutralise credentials that are still exactly the seeded defaults.
UPDATE users SET pin = '!!rotate-me-' || id || '-' || floor(random() * 1e9)::text
WHERE pin IN ('1234', 'admin123', 'superadmin123');

CREATE TABLE IF NOT EXISTS sessions (
  "jti" VARCHAR(64) PRIMARY KEY,
  "userId" VARCHAR(64) NOT NULL REFERENCES users(id),
  "deviceId" VARCHAR(128),
  "deviceName" VARCHAR(128),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "lastSeenAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "revokedAt" TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS password_resets (
  id VARCHAR(64) PRIMARY KEY,
  "userId" VARCHAR(64) NOT NULL REFERENCES users(id),
  token VARCHAR(128) NOT NULL,
  otp VARCHAR(16) NOT NULL,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "usedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
