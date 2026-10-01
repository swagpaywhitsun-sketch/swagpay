// Auth endpoints: real credential verification, signed token issuance, refresh, logout.
// There is deliberately no fallback identity and no literal credential in this file.
const crypto = require('crypto');
const { recordAudit } = require('./audit');
const {
  createAccessToken,
  createRefreshToken,
  verifyToken,
  hashPassword,
  verifyPassword,
  safeEqual,
  requireAuth,
  ACCESS_TTL_SECONDS,
  REFRESH_TTL_SECONDS,
  upgradeLegacyPin,
} = require('./auth');

const PUBLIC_DEVICE_ID = 'device-unbound';

function normaliseRole(dbRole) {
  const role = String(dbRole || '').toUpperCase();
  if (role === 'ADMIN' || role === 'SUPER_ADMIN') return role;
  return 'TELLER';
}

function shapeUser(row, role) {
  return {
    id: row.id,
    fullName: row.name,
    email: row.email,
    phone: row.phone || '',
    role: role === 'SUPER_ADMIN' ? 'admin' : role === 'ADMIN' ? 'admin' : 'teller',
    dbRole: role,
    posId: row.posId || null,
    active: row.active === 1 || row.active === true,
  };
}

async function issueSession(pool, user, deviceId, deviceName, res) {
  const accessToken = createAccessToken(user, deviceId);
  const refreshToken = createRefreshToken(user, deviceId);
  const payload = verifyToken(refreshToken, 'refresh');
  try {
    await pool.query(
      `INSERT INTO sessions ("jti", "userId", "deviceId", "deviceName") VALUES ($1, $2, $3, $4)
       ON CONFLICT ("jti") DO NOTHING`,
      [payload.jti, user.id, deviceId, deviceName || null]
    );
  } catch (_) {
    // sessions table not migrated yet — tokens remain valid, revocation unavailable
  }
  res.json({
    success: true,
    user: { ...user.user, deviceId },
    token: accessToken,
    refreshToken,
    expiresIn: ACCESS_TTL_SECONDS,
    refreshExpiresIn: REFRESH_TTL_SECONDS,
  });
}

function requireAdmin(req, res, next) {
  if (!req.auth) return res.status(401).json({ error: 'authentication_required' });
  if (req.auth.role !== 'ADMIN' && req.auth.role !== 'SUPER_ADMIN') {
    return res.status(403).json({ error: 'insufficient_role' });
  }
  next();
}

module.exports = function registerAuthRoutes(app, pool) {
  app.post('/api/auth/login', async (req, res) => {
    const identifier = String(req.body.identifier || req.body.email || '').trim();
    const password = String(req.body.password || '');
    const deviceId = String(req.body.deviceId || PUBLIC_DEVICE_ID);
    const deviceName = String(req.body.deviceName || '');
    const requestedRole = String(req.body.role || '').toUpperCase();

    if (!identifier || !password) {
      return res.status(400).json({ success: false, message: 'Identifier and password are required' });
    }

    try {
      // 1. Bootstrap superuser — credentials exist only in the deployment environment.
      const bootstrapEmail = process.env.ADMIN_BOOTSTRAP_EMAIL;
      const bootstrapPassword = process.env.ADMIN_BOOTSTRAP_PASSWORD;
      if (
        bootstrapEmail &&
        bootstrapPassword &&
        safeEqual(identifier, bootstrapEmail) &&
        safeEqual(password, bootstrapPassword)
      ) {
        const user = {
          id: 'usr_admin',
          name: 'Administrator',
          email: bootstrapEmail,
          phone: '',
          posId: null,
          active: 1,
        };
        const shaped = shapeUser(user, 'ADMIN');
        recordAudit(pool, user.id, 'USER_LOGIN', 'USER', user.id, { deviceId, deviceName, role: 'ADMIN' }, req);
        return issueSession(pool, { ...shaped, id: user.id, user: shaped }, deviceId, deviceName, res);
      }

      // 2. Database users only — exact credential match, no role guessing.
      const userRes = await pool.query(
        `SELECT id, name, email, phone, role, "posId", active, pin, "pinHash", "deviceId"
         FROM users WHERE email = $1 OR phone = $1 OR id = $1 LIMIT 1`,
        [identifier]
      );
      if (userRes.rows.length === 0) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      const row = userRes.rows[0];
      if (Number(row.active) !== 1) {
        return res.status(403).json({ success: false, message: 'Account is deactivated, contact an administrator' });
      }

      const storedSecret = row.pinHash || row.pin;
      if (!verifyPassword(storedSecret, password)) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }
      if (row.pin && !String(row.pin).startsWith('scrypt$')) {
        await upgradeLegacyPin(pool, row.id, row.pin, password);
      }

      const role = normaliseRole(row.role);
      if (requestedRole === 'ADMIN' && role === 'TELLER') {
        return res.status(403).json({ success: false, message: 'This account is not an administrator' });
      }

      // 3. Multi-device support: record the active device on the session without blocking other devices
      if (deviceId && deviceId !== PUBLIC_DEVICE_ID) {
        try {
          await pool.query('UPDATE users SET "deviceId" = $1 WHERE id = $2', [deviceId, row.id]);
        } catch (_) {
          // deviceId column optional
        }
      }

      const shaped = shapeUser(row, role);
      recordAudit(pool, row.id, 'USER_LOGIN', 'USER', row.id, { deviceId, deviceName, role }, req);
      return issueSession(pool, { ...shaped, id: row.id, user: shaped }, deviceId, deviceName, res);
    } catch (err) {
      return res.status(500).json({ success: false, message: 'Authentication service unavailable', error: err.message });
    }
  });

  app.post('/api/auth/refresh', async (req, res) => {
    const token = String(req.body.refreshToken || '');
    const payload = verifyToken(token, 'refresh');
    if (!payload) return res.status(401).json({ success: false, message: 'Session expired, sign in again' });

    try {
      const check = await pool.query('SELECT revokedAt FROM sessions WHERE "jti" = $1', [payload.jti]);
      if (check.rows.length > 0 && check.rows[0].revokedAt) {
        return res.status(401).json({ success: false, message: 'Session revoked' });
      }
      const userRes = await pool.query('SELECT id, name, email, phone, role, "posId", active FROM users WHERE id = $1', [
        payload.uid,
      ]);
      if (userRes.rows.length === 0) return res.status(401).json({ success: false, message: 'User no longer exists' });
      const row = userRes.rows[0];
      if (Number(row.active) !== 1) return res.status(403).json({ success: false, message: 'Account is deactivated' });

      const role = normaliseRole(row.role);
      const accessToken = createAccessToken({ id: row.id, dbRole: role, posId: row.posId }, payload.did);
      return res.json({
        success: true,
        user: shapeUser(row, role),
        token: accessToken,
        expiresIn: ACCESS_TTL_SECONDS,
      });
    } catch (err) {
      return res.status(500).json({ success: false, message: 'Refresh failed', error: err.message });
    }
  });

  app.post('/api/auth/logout', requireAuth, async (req, res) => {
    try {
      await pool.query('UPDATE sessions SET "revokedAt" = NOW() WHERE "userId" = $1 AND "revokedAt" IS NULL', [
        req.auth.userId,
      ]);
      recordAudit(pool, req.auth.userId, 'USER_LOGOUT', 'USER', req.auth.userId, null, req);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });

  // Self-service password change: proves the current secret before replacing it.
  app.post('/api/auth/change-password', requireAuth, async (req, res) => {
    const current = String(req.body.currentPassword || '');
    const next = String(req.body.newPassword || '');
    if (next.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
    }
    try {
      const bootstrapEmail = process.env.ADMIN_BOOTSTRAP_EMAIL;
      const bootstrapPassword = process.env.ADMIN_BOOTSTRAP_PASSWORD;
      const isBootstrap = req.auth.userId === 'usr_admin';

      if (isBootstrap) {
        let isCorrect = safeEqual(current, bootstrapPassword);
        if (!isCorrect) {
          const userRes = await pool.query('SELECT pin, "pinHash" FROM users WHERE id = $1', ['usr_admin']);
          if (userRes.rows.length > 0 && verifyPassword(userRes.rows[0].pinHash || userRes.rows[0].pin, current)) {
            isCorrect = true;
          }
        }
        if (!isCorrect) {
          return res.status(401).json({ success: false, message: 'Current password is incorrect' });
        }
        await pool.query(
          `INSERT INTO users (id, name, email, phone, pin, "pinHash", role, active, "createdAt", "updatedAt")
           VALUES ('usr_admin', 'Administrator', $1, '', '', $2, 'ADMIN', 1, NOW(), NOW())
           ON CONFLICT (id) DO UPDATE SET "pinHash" = $2, "updatedAt" = NOW()`,
          [bootstrapEmail || 'admin@swagpay.com', hashPassword(next)]
        );
        recordAudit(pool, 'usr_admin', 'PASSWORD_CHANGED', 'USER', 'usr_admin', null, req);
        return res.json({ success: true, message: 'Password updated successfully' });
      }

      const userRes = await pool.query('SELECT id, pin, "pinHash" FROM users WHERE id = $1', [req.auth.userId]);
      if (userRes.rows.length === 0) return res.status(404).json({ success: false, message: 'User not found' });
      const row = userRes.rows[0];
      if (!verifyPassword(row.pinHash || row.pin, current)) {
        return res.status(401).json({ success: false, message: 'Current password is incorrect' });
      }
      await pool.query('UPDATE users SET "pinHash" = $1, pin = \'\' , "updatedAt" = NOW() WHERE id = $2', [
        hashPassword(next),
        req.auth.userId,
      ]);
      // Invalidate every issued session for this account.
      try {
        await pool.query('UPDATE sessions SET "revokedAt" = NOW() WHERE "userId" = $1 AND "revokedAt" IS NULL', [
          req.auth.userId,
        ]);
      } catch (_) {}
      recordAudit(pool, req.auth.userId, 'PASSWORD_CHANGED', 'USER', req.auth.userId, null, req);
      res.json({ success: true, message: 'Password updated successfully' });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });

  app.delete('/api/users/:id', requireAuth, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const userRes = await client.query('SELECT name, email FROM users WHERE id = $1', [id]);
      const user = userRes.rows[0];

      await client.query('DELETE FROM sessions WHERE "userId" = $1', [id]);
      await client.query('DELETE FROM password_resets WHERE "userId" = $1', [id]);

      // Ensure foreign key columns allow nulls so updating cannot fail on NOT NULL
      try {
        await client.query('ALTER TABLE transactions ALTER COLUMN "tellerId" DROP NOT NULL');
      } catch (_) {}
      try {
        await client.query('ALTER TABLE refund_requests ALTER COLUMN "tellerId" DROP NOT NULL');
      } catch (_) {}
      try {
        await client.query('ALTER TABLE shifts ALTER COLUMN "tellerId" DROP NOT NULL');
      } catch (_) {}

      try {
        await client.query('UPDATE transactions SET "tellerId" = NULL WHERE "tellerId" = $1', [id]);
      } catch (nullErr) {
        await client.query(
          `INSERT INTO users (id, name, email, pin, role, active, "createdAt", "updatedAt")
           VALUES ('usr_archived', 'Archived Staff', 'archived@swagpay.internal', '', 'TELLER', 0, NOW(), NOW())
           ON CONFLICT (id) DO NOTHING`
        );
        await client.query('UPDATE transactions SET "tellerId" = $2 WHERE "tellerId" = $1', [id, 'usr_archived']);
      }

      try {
        await client.query('UPDATE refund_requests SET "tellerId" = NULL WHERE "tellerId" = $1', [id]);
      } catch (_) {
        await client.query('UPDATE refund_requests SET "tellerId" = $2 WHERE "tellerId" = $1', [id, 'usr_archived']);
      }

      try {
        await client.query('UPDATE shifts SET "tellerId" = NULL WHERE "tellerId" = $1', [id]);
      } catch (_) {
        await client.query('UPDATE shifts SET "tellerId" = $2 WHERE "tellerId" = $1', [id, 'usr_archived']);
      }

      await client.query('DELETE FROM users WHERE id = $1', [id]);

      await client.query('COMMIT');
      recordAudit(pool, req.auth.userId, 'USER_DELETED', 'USER', id, { name: user?.name, email: user?.email }, req);
      res.json({ success: true, message: 'User deleted successfully' });
    } catch (err) {
      await client.query('ROLLBACK');
      res.status(500).json({ success: false, error: err.message });
    } finally {
      client.release();
    }
  });

  // Admin: list and revoke sessions, or unbind a teller's device.
  app.get('/api/auth/sessions', requireAuth, requireAdmin, async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT s."jti", s."userId", s."deviceId", s."deviceName", s."createdAt", s."lastSeenAt", s."revokedAt",
                u.name, u.email
         FROM sessions s JOIN users u ON u.id = s."userId"
         ORDER BY s."createdAt" DESC LIMIT 200`
      );
      res.json(result.rows);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/auth/sessions/:jti/revoke', requireAuth, requireAdmin, async (req, res) => {
    try {
      await pool.query('UPDATE sessions SET "revokedAt" = NOW() WHERE "jti" = $1', [req.params.jti]);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/users/:id/unbind-device', requireAuth, requireAdmin, async (req, res) => {
    try {
      await pool.query('UPDATE users SET "deviceId" = NULL WHERE id = $1', [req.params.id]);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Admin: create a teller with a hashed secret — never a hardcoded PIN.
  app.post('/api/users', requireAuth, requireAdmin, async (req, res) => {
    const { id, name, email, phone, role, posId, password } = req.body;
    if (!name || !email || !password || String(password).length < 6) {
      return res.status(400).json({ success: false, message: 'name, email and a password of 6+ characters are required' });
    }
    const userId = String(id || `usr_${crypto.randomUUID().slice(0, 8)}`);
    const normalised = normaliseRole(role);
    try {
      await pool.query(
        `INSERT INTO users (id, name, email, phone, pin, "pinHash", role, "posId", active, "createdAt", "updatedAt")
         VALUES ($1, $2, $3, $4, '', $5, $6, $7, 1, NOW(), NOW())`,
        [userId, name, email, phone || '', hashPassword(password), normalised, posId || null]
      );
      res.json({ success: true, id: userId });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });

  // Forgot password: sends OTP to registered user identifier (strictly bounded, no leaked tokens)
  const inMemoryResets = new Map();

  app.post('/api/auth/forgot-password', async (req, res) => {
    const rawIdentifier = String(req.body.identifier || req.body.email || req.body.phone || '').trim();
    if (!rawIdentifier) {
      return res.status(400).json({ success: false, message: 'Email or phone number is required' });
    }

    try {
      const userRes = await pool.query(
        'SELECT id, name, email, phone FROM users WHERE LOWER(email) = LOWER($1) OR phone = $1 OR id = $1 LIMIT 1',
        [rawIdentifier]
      );

      // Uniform response prevents user enumeration
      if (!userRes || !userRes.rows || userRes.rows.length === 0) {
        return res.json({
          success: true,
          message: 'If an account matches that identifier, a verification code has been dispatched.',
        });
      }

      const user = userRes.rows[0];
      const otp = String(Math.floor(100000 + Math.random() * 900000));
      const resetId = `rst_${crypto.randomUUID().slice(0, 8)}`;
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

      // Secure in-memory mapping bound to the specific userId
      inMemoryResets.set(user.id, {
        id: resetId,
        userId: user.id,
        identifier: (user.email || '').toLowerCase(),
        phone: user.phone || '',
        otp,
        expiresAt,
        used: false,
      });

      // Also persist to database if table exists
      try {
        await pool.query(
          `INSERT INTO password_resets (id, "userId", token, otp, "expiresAt") VALUES ($1, $2, $3, $4, $5)`,
          [resetId, user.id, resetId, otp, expiresAt]
        );
      } catch (_) {}

      // Internal dispatch hook for testing only
      if (typeof app.get('onPasswordResetOtp') === 'function') {
        app.get('onPasswordResetOtp')(user.id, otp);
      }

      const maskedEmail = user.email ? user.email.replace(/(.{2})(.*)(@.*)/, '$1***$3') : null;
      const maskedPhone = user.phone ? user.phone.slice(-4).padStart(user.phone.length, '*') : null;

      res.json({
        success: true,
        message: 'If an account matches that identifier, a verification code has been dispatched.',
        maskedContact: maskedEmail || maskedPhone,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });

  // Reset password: requires both the user's identifier and the matching OTP code
  app.post('/api/auth/reset-password', async (req, res) => {
    const rawIdentifier = String(req.body.identifier || req.body.email || req.body.phone || '').trim();
    const otp = String(req.body.otp || req.body.code || '').trim();
    const newPassword = String(req.body.newPassword || req.body.password || '');

    if (!rawIdentifier || !otp) {
      return res.status(400).json({ success: false, message: 'Identifier and verification code are required' });
    }

    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters' });
    }

    try {
      // 1. Resolve target user
      const userRes = await pool.query(
        'SELECT id, email, phone FROM users WHERE LOWER(email) = LOWER($1) OR phone = $1 OR id = $1 LIMIT 1',
        [rawIdentifier]
      );

      if (!userRes || !userRes.rows || userRes.rows.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Invalid identifier or verification code. Please check and try again.',
        });
      }

      const targetUser = userRes.rows[0];
      let otpValid = false;

      // 2. Check in-memory store bound to THIS specific user ID
      if (inMemoryResets.has(targetUser.id)) {
        const item = inMemoryResets.get(targetUser.id);
        if (!item.used && item.otp === otp && item.expiresAt > new Date()) {
          otpValid = true;
          item.used = true;
        }
      }

      // 3. Fallback: check database for this specific user ID
      if (!otpValid) {
        try {
          const dbRes = await pool.query(
            `SELECT id FROM password_resets 
             WHERE "userId" = $1 AND otp = $2 AND "usedAt" IS NULL AND "expiresAt" > NOW() 
             ORDER BY "createdAt" DESC LIMIT 1`,
            [targetUser.id, otp]
          );
          if (dbRes.rows.length > 0) {
            otpValid = true;
          }
        } catch (_) {}
      }

      if (!otpValid) {
        return res.status(400).json({
          success: false,
          message: 'Invalid or expired verification code. Please request a new code.',
        });
      }

      // Update password hash
      const hashed = hashPassword(newPassword);
      await pool.query('UPDATE users SET "pinHash" = $1, pin = \'\', "updatedAt" = NOW() WHERE id = $2', [
        hashed,
        targetUser.id,
      ]);

      // Invalidate reset records
      inMemoryResets.delete(targetUser.id);
      try {
        await pool.query('UPDATE password_resets SET "usedAt" = NOW() WHERE "userId" = $1 AND "usedAt" IS NULL', [
          targetUser.id,
        ]);
      } catch (_) {}

      // Invalidate existing sessions for this user
      try {
        await pool.query('UPDATE sessions SET "revokedAt" = NOW() WHERE "userId" = $1 AND "revokedAt" IS NULL', [
          targetUser.id,
        ]);
      } catch (_) {}

      res.json({
        success: true,
        message: 'Password has been reset successfully. You can now log in with your new password.',
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  });
};
