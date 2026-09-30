// Centralized Audit Logger for SwagPay
// Records security and operational events to PostgreSQL audit_logs table

async function recordAudit(pool, actorId, action, targetType, targetId, metadata, req) {
  try {
    const id = `aud_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
    const ip = (req ? req.headers['x-forwarded-for'] || req.socket?.remoteAddress : '') || '127.0.0.1';
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

module.exports = { recordAudit };
