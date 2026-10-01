// Centralized Audit Logger for SwagPay
// Records security and operational events to PostgreSQL audit_logs table

function extractClientIp(req) {
  if (!req) return '127.0.0.1';
  const headers = req.headers || {};

  // Fly.io forwards the true client remote IP in 'fly-client-ip'
  const flyIp = headers['fly-client-ip'];
  if (flyIp && String(flyIp).trim() !== '') return String(flyIp).trim();

  // Cloudflare Connecting IP
  const cfIp = headers['cf-connecting-ip'];
  if (cfIp && String(cfIp).trim() !== '') return String(cfIp).trim();

  // Standard X-Forwarded-For header (first IP is client)
  const xForwarded = headers['x-forwarded-for'];
  if (xForwarded) {
    const first = String(xForwarded).split(',')[0].trim();
    if (first && first !== '' && first !== 'unknown') return first;
  }

  // Real IP
  const realIp = headers['x-real-ip'];
  if (realIp && String(realIp).trim() !== '') return String(realIp).trim();

  // Express trusted proxy ip
  if (req.ip && String(req.ip).trim() !== '') {
    return String(req.ip).replace(/^::ffff:/, '').trim();
  }

  // Direct socket / connection address
  const socketIp = req.socket?.remoteAddress || req.connection?.remoteAddress || '127.0.0.1';
  return String(socketIp).replace(/^::ffff:/, '').trim();
}

function extractDevice(req) {
  if (!req) return 'SwagPay Gateway';
  if (req.body?.deviceName) return String(req.body.deviceName).slice(0, 64);
  if (req.body?.deviceId) return String(req.body.deviceId).slice(0, 64);
  if (req.body?.posId) return `POS (${req.body.posId})`;
  const ua = req.headers?.['user-agent'] || '';
  if (ua.includes('Dart') || ua.includes('Flutter')) return 'SwagPay Terminal App';
  if (ua.includes('iPhone') || ua.includes('iPad')) return 'iOS Client';
  if (ua.includes('Android')) return 'Android POS Device';
  if (ua.includes('Macintosh') || ua.includes('Mac OS')) return 'macOS Admin Portal';
  if (ua.includes('Windows')) return 'Windows Admin Portal';
  if (ua.includes('Linux')) return 'Linux Node';
  if (ua.includes('Chrome') || ua.includes('Safari') || ua.includes('Firefox')) return 'Web Portal';
  return 'SwagPay Node';
}

async function recordAudit(pool, actorId, action, targetType, targetId, metadata, req) {
  try {
    const id = `aud_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
    const ip = extractClientIp(req);
    const device = extractDevice(req);

    let metaObj = null;
    if (metadata && typeof metadata === 'object') {
      metaObj = { device, ...metadata };
    } else if (metadata && String(metadata).trim() !== '' && String(metadata).trim() !== 'null') {
      metaObj = { device, note: String(metadata) };
    } else {
      metaObj = { device };
    }

    const metaStr = JSON.stringify(metaObj);

    await pool.query(
      `INSERT INTO audit_logs (id, "actorId", action, "targetType", "targetId", metadata, "ipAddress", "createdAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
      [id, actorId || 'System', action, targetType || null, targetId || null, metaStr, String(ip).slice(0, 64)]
    );
  } catch (err) {
    // Non-blocking: audit failure must not crash transactional requests
    console.error('Audit log failed:', err.message);
  }
}

module.exports = { recordAudit, extractClientIp, extractDevice };

