// SwagPay auth core — signed tokens, scrypt hashing, server-bound sessions.
// Uses only Node's crypto module so there is no new dependency to audit.
const crypto = require('crypto');

const ACCESS_TTL_SECONDS = Number(process.env.ACCESS_TOKEN_TTL_SECONDS || 12 * 3600);
const REFRESH_TTL_SECONDS = Number(process.env.REFRESH_TOKEN_TTL_SECONDS || 30 * 24 * 3600);
const SCRYPT_PARAMS = { N: 16384, r: 8, p: 1, keylen: 64 };

function getSecret() {
  const secret = process.env.AUTH_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error(
      'AUTH_SECRET must be set to a random string of at least 32 characters (generate one with: openssl rand -hex 32)'
    );
  }
  return secret;
}

function base64url(input) {
  return Buffer.from(input).toString('base64url');
}

function sign(data) {
  return crypto.createHmac('sha256', getSecret()).update(data).digest('base64url');
}

function normaliseRole(user) {
  const raw = typeof user === 'string' ? user : (user && (user.dbRole || user.role)) || '';
  const role = String(raw).toUpperCase();
  return role === 'ADMIN' || role === 'SUPER_ADMIN' ? role : 'TELLER';
}

function createAccessToken(user, deviceId) {
  const payload = {
    uid: user.id,
    role: normaliseRole(user), // 'TELLER' | 'ADMIN' | 'SUPER_ADMIN'
    posId: user.posId || null,
    did: deviceId,
    typ: 'access',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + ACCESS_TTL_SECONDS,
  };
  const body = base64url(JSON.stringify(payload));
  return `${body}.${sign(body)}`;
}

function createRefreshToken(user, deviceId) {
  const payload = {
    uid: user.id,
    did: deviceId,
    typ: 'refresh',
    jti: crypto.randomUUID(),
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + REFRESH_TTL_SECONDS,
  };
  const body = base64url(JSON.stringify(payload));
  return `${body}.${sign(body)}`;
}

function verifyToken(token, expectedType) {
  if (typeof token !== 'string') return null;
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;
  const expected = sign(body);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;

  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch (_) {
    return null;
  }
  if (payload.typ !== expectedType) return null;
  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}

function hashPassword(plain) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(String(plain), salt, SCRYPT_PARAMS.keylen, SCRYPT_PARAMS);
  return `scrypt$${SCRYPT_PARAMS.N}$${SCRYPT_PARAMS.r}$${SCRYPT_PARAMS.p}$${salt.toString('base64')}$${hash.toString('base64')}`;
}

function verifyScryptHash(stored, plain) {
  const parts = String(stored).split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const [, N, r, p, saltB64, hashB64] = parts;
  let known, candidate;
  try {
    known = Buffer.from(hashB64, 'base64');
    candidate = crypto.scryptSync(String(plain), Buffer.from(saltB64, 'base64'), known.length, {
      N: Number(N),
      r: Number(r),
      p: Number(p),
    });
  } catch (_) {
    return false;
  }
  return known.length === candidate.length && crypto.timingSafeEqual(known, candidate);
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a || ''));
  const y = Buffer.from(String(b || ''));
  if (x.length !== y.length) return false;
  return crypto.timingSafeEqual(x, y);
}

// Accepts a scrypt hash, or a legacy plaintext column value (constant-time compared).
function verifyPassword(stored, plain) {
  if (!stored) return false;
  if (String(stored).startsWith('scrypt$')) return verifyScryptHash(stored, plain);
  return safeEqual(stored, plain);
}

// ─── MIDDLEWARE ─────────────────────────────────────────
// The only /api paths reachable without a token. Everything else is denied by default.
const PUBLIC_API_PATHS = new Set([
  '/auth/login',
  '/auth/refresh',
  '/auth/forgot-password',
  '/auth/reset-password',
  '/system/network-info',
]);
const PUBLIC_API_PATTERNS = [/^\/webhooks?(\/.*)?$/];

function isPublicApiPath(pathname) {
  if (PUBLIC_API_PATHS.has(pathname)) return true;
  return PUBLIC_API_PATTERNS.some((re) => re.test(pathname));
}

function bearerFrom(req) {
  const header = req.headers.authorization || '';
  if (!header.toLowerCase().startsWith('bearer ')) return null;
  return header.slice(7).trim() || null;
}

// Deny by default: any /api route that is not explicitly public must present a valid token.
function requireAuth(req, res, next) {
  const payload = verifyToken(bearerFrom(req), 'access');
  if (!payload) return res.status(401).json({ error: 'authentication_required' });
  req.auth = { userId: payload.uid, role: payload.role, posId: payload.posId, deviceId: payload.did };
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.auth) return res.status(401).json({ error: 'authentication_required' });
    if (!roles.includes(req.auth.role)) return res.status(403).json({ error: 'insufficient_role' });
    next();
  };
}

// A teller may only ever act as themselves: identity fields are taken from the
// token and overwrite whatever the client sent.
function enforceTellerIdentity(req, res, next) {
  if (!req.auth) return res.status(401).json({ error: 'authentication_required' });
  if (req.auth.role !== 'TELLER') return next();
  if (req.body && typeof req.body === 'object') {
    req.body.tellerId = req.auth.userId;
  }
  next();
}

async function upgradeLegacyPin(pool, userId, legacyPin, plainPassword) {
  if (String(legacyPin).startsWith('scrypt$')) return;
  if (!verifyPassword(legacyPin, plainPassword)) return;
  try {
    // The plaintext column is blanked in the same statement — an upgraded
    // account must not keep a recoverable secret in the database.
    await pool.query(`UPDATE users SET "pinHash" = $1, pin = '' WHERE id = $2`, [
      hashPassword(plainPassword),
      userId,
    ]);
  } catch (_) {
    // pinHash column not migrated yet — login still works, upgrade retried next time
  }
}

module.exports = {
  ACCESS_TTL_SECONDS,
  REFRESH_TTL_SECONDS,
  createAccessToken,
  createRefreshToken,
  verifyToken,
  isPublicApiPath,
  hashPassword,
  verifyPassword,
  safeEqual,
  bearerFrom,
  requireAuth,
  requireRole,
  enforceTellerIdentity,
  upgradeLegacyPin,
};
