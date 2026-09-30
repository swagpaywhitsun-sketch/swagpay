// Centralized Audit Logger for SwagPay
// Records security and operational events to PostgreSQL audit_logs table

function extractClientIp(req) {
  if (!req) return '127.0.0.1';
  // Fly.io forwards the true client remote IP in 'fly-client-ip'
  const flyIp = req.headers['fly-client-ip'];
  if (flyIp) return String(flyIp).trim();

  // Cloudflare Connecting IP
  const cfIp = req.headers['cf-connecting-ip'];
  if (cfIp) return String(cfIp).trim();

  // Standard X-Forwarded-For header (first IP is client)
  const xForwarded = req.headers['x-forwarded-for'];
  if (xForwarded) {
    const first = String(xForwarded).split(',')[0].trim();
    if (first) return first;
  }

  // Real IP
  const realIp = req.headers['x-real-ip'];
  if (realIp) return String(realIp).trim();

  // Direct socket / connection address
  const socketIp = req.socket?.remoteAddress || req.connection?.remoteAddress || req.ip || '127.0.0.1';
  return String(socketIp).replace(/^::ffff:/, '').trim();
}

async function recordAudit(pool, actorId, action, targetType, targetId, metadata, req) {
  try {
    const id = `aud_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
    const ip = extractClientIp(req);
    const metaStr = typeof metadata === 'object' ? JSON.stringify(metadata) : metadata || null;
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

module.exports = { recordAudit, extractClientIp };

