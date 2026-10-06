// /api/auth/login contract, exercised against an in-memory pool so the database
// code paths are covered without a live Supabase instance.
//   node --test server/
const test = require('node:test');
const assert = require('node:assert');
const express = require('express');

process.env.AUTH_SECRET = process.env.AUTH_SECRET || 'test-secret-0123456789abcdef0123456789abcdef';
process.env.ADMIN_BOOTSTRAP_EMAIL = 'root@swagpay.test';
process.env.ADMIN_BOOTSTRAP_PASSWORD = 'bootstrap-secret-not-a-demo-value';

const auth = require('./auth');
const registerAuthRoutes = require('./authRoutes');

/// Records every write so tests can assert on side effects (device binding, PIN upgrade).
function fakePool(users) {
  const writes = [];
  return {
    writes,
    async query(sql, params = []) {
      if (/FROM users/i.test(sql)) {
        const id = (params[0] || '').toLowerCase();
        const digits = id.replace(/\D/g, '');
        const last9 = digits.length >= 9 ? digits.slice(-9) : (params[1] || null);
        const row = users.find((u) => {
          if ((u.email || '').toLowerCase() === id) return true;
          if (u.id === id) return true;
          if (u.phone === id) return true;
          if (last9 && (u.phone || '').replace(/\D/g, '').endsWith(last9)) return true;
          return false;
        });
        return { rows: row ? [{ active: 1, deviceId: null, pinHash: null, ...row }] : [] };
      }
      if (/UPDATE users SET "deviceId"/i.test(sql)) {
        writes.push({ kind: 'bind', deviceId: params[0], userId: params[1] });
        return { rows: [] };
      }
      if (/UPDATE users SET "pinHash"/i.test(sql)) {
        writes.push({ kind: 'upgrade', pinHash: params[0], userId: params[1] });
        return { rows: [] };
      }
      if (/UPDATE users SET avatar/i.test(sql)) {
        writes.push({ kind: 'avatar', avatar: params[0], userId: params[1] });
        const u = users.find((x) => x.id === params[1]);
        if (u) u.avatar = params[0];
        return { rows: [] };
      }
      if (/INSERT INTO sessions/i.test(sql)) return { rows: [] };
      if (/SELECT revokedAt FROM sessions/i.test(sql)) return { rows: [] };
      if (/password_resets/i.test(sql)) return { rows: [] };
      if (/UPDATE sessions/i.test(sql)) return { rows: [] };
      throw new Error(`unhandled sql in fake pool: ${sql.slice(0, 60)}`);
    },
  };
}

async function login(pool, body) {
  const app = express();
  app.use(express.json());
  registerAuthRoutes(app, pool);
  const server = await new Promise((r) => {
    const s = app.listen(0, () => r(s));
  });
  try {
    const res = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  } finally {
    server.close();
  }
}

test('a database account signs in and receives a device-bound session', async () => {
  const pinHash = auth.hashPassword('teller-secret');
  const pool = fakePool([
    { id: 'usr_7', name: 'Akosua', email: 'akosua@swagpay.test', phone: '0550000007', role: 'TELLER', posId: 'pos_02', pin: '', pinHash },
  ]);

  const res = await login(pool, { identifier: 'akosua@swagpay.test', password: 'teller-secret', deviceId: 'dev-77' });

  assert.equal(res.status, 200);
  assert.equal(res.body.user.role, 'teller');
  assert.equal(res.body.user.dbRole, 'TELLER');
  assert.equal(res.body.user.deviceId, 'dev-77');
  const claims = auth.verifyToken(res.body.token, 'access');
  assert.equal(claims.uid, 'usr_7', 'token carries the row id, not a client claim');
  assert.equal(claims.role, 'TELLER', 'token role must be the canonical uppercase form requireRole() checks');
  assert.equal(claims.did, 'dev-77');
  assert.deepEqual(
    pool.writes.find((w) => w.kind === 'bind'),
    { kind: 'bind', deviceId: 'dev-77', userId: 'usr_7' },
    'first login pins the account to that terminal'
  );
});

test('wrong credentials and unknown accounts are indistinguishable', async () => {
  const pool = fakePool([
    { id: 'usr_7', name: 'A', email: 'akosua@swagpay.test', role: 'TELLER', posId: null, pin: '', pinHash: auth.hashPassword('right') },
  ]);
  const wrongPass = await login(pool, { identifier: 'akosua@swagpay.test', password: 'wrong' });
  const noSuchUser = await login(pool, { identifier: 'nobody@swagpay.test', password: 'wrong' });

  assert.equal(wrongPass.status, 401);
  assert.equal(noSuchUser.status, 401);
  assert.equal(wrongPass.body.message, noSuchUser.body.message, 'no user enumeration');
});

test('a deactivated account is refused even with the right secret', async () => {
  const pool = fakePool([
    { id: 'usr_8', name: 'Off', email: 'off@swagpay.test', role: 'TELLER', active: 0, pin: '', pinHash: auth.hashPassword('pw') },
  ]);
  const res = await login(pool, { identifier: 'off@swagpay.test', password: 'pw' });
  assert.equal(res.status, 403);
});

test('an account can sign in from any authorized device and records active device', async () => {
  const pool = fakePool([
    { id: 'usr_9', name: 'B', email: 'b@swagpay.test', role: 'TELLER', deviceId: 'dev-original', pin: '', pinHash: auth.hashPassword('pw') },
  ]);
  const res = await login(pool, { identifier: 'b@swagpay.test', password: 'pw', deviceId: 'dev-second-device' });
  assert.equal(res.status, 200);
  assert.equal(res.body.success, true);
  assert.ok(pool.writes.some((w) => w.kind === 'bind' && w.deviceId === 'dev-second-device'));
});

test('a teller cannot request an admin session', async () => {
  const pool = fakePool([
    { id: 'usr_10', name: 'T', email: 't@swagpay.test', role: 'TELLER', pin: '', pinHash: auth.hashPassword('pw') },
  ]);
  const res = await login(pool, { identifier: 't@swagpay.test', password: 'pw', role: 'ADMIN' });
  assert.equal(res.status, 403);
});

test('a legacy plaintext PIN still signs in and is upgraded to a hash', async () => {
  const pool = fakePool([
    { id: 'usr_11', name: 'Old', email: 'old@swagpay.test', role: 'TELLER', pin: 'legacy-pin-value', pinHash: null },
  ]);
  const res = await login(pool, { identifier: 'old@swagpay.test', password: 'legacy-pin-value' });

  assert.equal(res.status, 200);
  const upgrade = pool.writes.find((w) => w.kind === 'upgrade');
  assert.ok(upgrade, 'the plaintext column must be replaced by a scrypt hash');
  assert.match(upgrade.pinHash, /^scrypt\$/);
});

test('the bootstrap admin works without a database row and is not a teller', async () => {
  const pool = fakePool([]);
  const res = await login(pool, { identifier: 'root@swagpay.test', password: 'bootstrap-secret-not-a-demo-value' });
  assert.equal(res.status, 200);
  assert.equal(res.body.user.role, 'admin');
  assert.equal(auth.verifyToken(res.body.token, 'access').role, 'ADMIN');
});

test('the bootstrap admin password is never accepted for a database user', async () => {
  const pool = fakePool([
    { id: 'usr_x', name: 'X', email: 'x@swagpay.test', role: 'TELLER', pin: '', pinHash: auth.hashPassword('other') },
  ]);
  const res = await login(pool, { identifier: 'x@swagpay.test', password: 'bootstrap-secret-not-a-demo-value' });
  assert.equal(res.status, 401);
});

test('missing identifier or password is a 400, not a crash', async () => {
  const res = await login(fakePool([]), { identifier: '', password: '' });
  assert.equal(res.status, 400);
});

test('forgot password does not leak secrets and requires user-bound OTP verification', async () => {
  const pool = fakePool([
    { id: 'usr_fp1', name: 'Teller FP', email: 'fp@swagpay.test', phone: '0241234567', role: 'TELLER', pin: '', pinHash: auth.hashPassword('initialPass1') },
    { id: 'usr_admin', name: 'Admin Victim', email: 'admin@swagpay.test', phone: '0249999999', role: 'ADMIN', pin: '', pinHash: auth.hashPassword('adminPass1') },
  ]);
  const app = express();
  app.use(express.json());

  let capturedOtp = null;
  app.set('onPasswordResetOtp', (userId, otp) => {
    if (userId === 'usr_fp1') capturedOtp = otp;
  });

  registerAuthRoutes(app, pool);
  const server = await new Promise((r) => {
    const s = app.listen(0, () => r(s));
  });

  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const fpRes = await fetch(`${baseUrl}/api/auth/forgot-password`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: 'fp@swagpay.test' }),
    });
    assert.equal(fpRes.status, 200);
    const fpData = await fpRes.json();
    assert.equal(fpData.success, true);
    // MUST NOT leak the raw OTP or resetToken in the response body
    assert.equal(fpData.otp, undefined, 'OTP must never be exposed in API response');
    assert.equal(fpData.resetToken, undefined, 'Reset token must never be exposed in API response');
    assert.ok(capturedOtp, 'OTP should be dispatched internally');

    // Attacker attempts to use user 1's OTP on admin's email -> MUST FAIL
    const crossAccountRes = await fetch(`${baseUrl}/api/auth/reset-password`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        identifier: 'admin@swagpay.test',
        otp: capturedOtp,
        newPassword: 'attackerNewPassword123',
      }),
    });
    assert.equal(crossAccountRes.status, 400);

    // Legitimate user resets password with their own identifier and matching OTP
    const resetRes = await fetch(`${baseUrl}/api/auth/reset-password`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        identifier: 'fp@swagpay.test',
        otp: capturedOtp,
        newPassword: 'newBrandNewPassword123',
      }),
    });
    assert.equal(resetRes.status, 200);
    const resetData = await resetRes.json();
    assert.equal(resetData.success, true);
    assert.ok(pool.writes.some((w) => w.kind === 'upgrade'));
  } finally {
    server.close();
  }
});

test('tellers can log in using their phone number', async () => {
  const secret = auth.hashPassword('Swag@1234');
  const pool = fakePool([
    {
      id: 'usr_teller_phone',
      email: 'teller_phone@swagpay.test',
      phone: '0241234567',
      role: 'TELLER',
      pinHash: secret,
    },
  ]);

  // Login with exact phone
  const resExact = await login(pool, { identifier: '0241234567', password: 'Swag@1234' });
  assert.equal(resExact.status, 200);
  assert.equal(resExact.body.user.id, 'usr_teller_phone');

  // Login with international prefix 233241234567
  const resPrefix = await login(pool, { identifier: '233241234567', password: 'Swag@1234' });
  assert.equal(resPrefix.status, 200);
  assert.equal(resPrefix.body.user.id, 'usr_teller_phone');
});

test('user profile picture is persisted and synced across devices on login', async () => {
  const secret = auth.hashPassword('Swag@1234');
  const pool = fakePool([
    {
      id: 'usr_teller_avatar',
      email: 'teller_avatar@swagpay.test',
      role: 'TELLER',
      pinHash: secret,
      avatar: 'data:image/jpeg;base64,initial_avatar_data',
    },
  ]);

  // 1. First device logs in and receives the avatar
  const dev1 = await login(pool, {
    identifier: 'teller_avatar@swagpay.test',
    password: 'Swag@1234',
    deviceId: 'device-1',
  });
  assert.equal(dev1.status, 200);
  assert.equal(dev1.body.user.avatar, 'data:image/jpeg;base64,initial_avatar_data');

  // 2. User updates their avatar
  const app = express();
  app.use(express.json());
  registerAuthRoutes(app, pool);
  const server = await new Promise((r) => {
    const s = app.listen(0, () => r(s));
  });
  try {
    const updateRes = await fetch(`http://127.0.0.1:${server.address().port}/api/users/me/avatar`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        Authorization: `Bearer ${dev1.body.token}`,
      },
      body: JSON.stringify({ avatar: 'data:image/jpeg;base64,new_synced_avatar_data' }),
    });
    assert.equal(updateRes.status, 200);
    const updateBody = await updateRes.json();
    assert.equal(updateBody.success, true);
    assert.equal(updateBody.avatar, 'data:image/jpeg;base64,new_synced_avatar_data');

    // 3. User logs in from a completely DIFFERENT device (device-2)
    const dev2 = await login(pool, {
      identifier: 'teller_avatar@swagpay.test',
      password: 'Swag@1234',
      deviceId: 'device-2',
    });
    assert.equal(dev2.status, 200);
    assert.equal(dev2.body.user.avatar, 'data:image/jpeg;base64,new_synced_avatar_data');
  } finally {
    server.close();
  }
});


