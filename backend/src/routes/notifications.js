const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function toNotification(row) {
  return {
    id: row.id,
    userId: row.user_id ?? '',
    recipientRole: row.recipient_role ?? null,
    type: row.type ?? 'system',
    title: row.title ?? '',
    description: row.description ?? '',
    priority: row.priority ?? 'medium',
    isRead: row.is_read === 1,
    link: row.link ?? null,
    createdAt: iso(row.created_at) ?? new Date().toISOString(),
  };
}

router.use(authenticate);

function scopeWhere(user, includeRoleBroadcasts) {
  if (includeRoleBroadcasts && user.role === 'admin') {
    return {
      sql: '(user_id = ? OR recipient_role = ?) AND is_deleted = 0',
      params: [user.uid, 'admin'],
    };
  }
  return { sql: 'user_id = ? AND is_deleted = 0', params: [user.uid] };
}

// GET /api/notifications?includeRoleBroadcasts=true
router.get('/', async (req, res, next) => {
  try {
    const include =
      req.query.includeRoleBroadcasts === 'true' ||
      req.query.includeRoleBroadcasts === '1';
    const scope = scopeWhere(req.user, include);
    const rows = await mysql.query(
      `SELECT * FROM notifications WHERE ${scope.sql} ORDER BY created_at DESC LIMIT 200`,
      scope.params,
    );
    return res.json(rows.map(toNotification));
  } catch (err) {
    return next(err);
  }
});

// GET /api/notifications/unread-count?includeRoleBroadcasts=true
router.get('/unread-count', async (req, res, next) => {
  try {
    const include =
      req.query.includeRoleBroadcasts === 'true' ||
      req.query.includeRoleBroadcasts === '1';
    const scope = scopeWhere(req.user, include);
    const rows = await mysql.query(
      `SELECT COUNT(*) AS c FROM notifications WHERE ${scope.sql} AND is_read = 0`,
      scope.params,
    );
    return res.json({ unread: Number(rows[0]?.c ?? 0) });
  } catch (err) {
    return next(err);
  }
});

// POST /api/notifications (staff create single)
router.post('/', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const allowedTypes = new Set([
      'system',
      'event',
      'employment',
      'survey',
      'announcement',
      'document',
    ]);
    const id = crypto.randomUUID();
    await mysql.query(
      `INSERT INTO notifications
         (id, user_id, recipient_role, type, title, description, priority, link)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        body.userId ? String(body.userId) : null,
        body.recipientRole === 'admin' || body.recipientRole === 'alumni'
          ? body.recipientRole
          : null,
        allowedTypes.has(body.type) ? body.type : 'system',
        body.title ? String(body.title) : '',
        body.description ? String(body.description) : '',
        ['low', 'medium', 'high'].includes(body.priority)
          ? body.priority
          : 'medium',
        body.link ? String(body.link) : null,
      ],
    );
    const rows = await mysql.query(
      'SELECT * FROM notifications WHERE id = ? LIMIT 1',
      [id],
    );
    return res.status(201).json(toNotification(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// POST /api/notifications/broadcast (admin fan-out to all alumni)
router.post('/broadcast', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const allowedTypes = new Set([
      'system',
      'event',
      'employment',
      'survey',
      'announcement',
      'document',
    ]);
    const alumni = await mysql.query(
      "SELECT id FROM users WHERE role = 'alumni' AND is_deleted = 0 AND (disabled IS NULL OR disabled = 0)",
    );
    if (alumni.length === 0) return res.json({ sent: 0 });
    const values = alumni.map(() => '(?, ?, ?, ?, ?, ?, ?)').join(', ');
    const params = [];
    for (const a of alumni) {
      params.push(
        crypto.randomUUID(),
        a.id,
        allowedTypes.has(body.type) ? body.type : 'system',
        body.title ? String(body.title) : '',
        body.description ? String(body.description) : '',
        ['low', 'medium', 'high'].includes(body.priority)
          ? body.priority
          : 'medium',
        body.link ? String(body.link) : null,
      );
    }
    await mysql.query(
      `INSERT INTO notifications
         (id, user_id, type, title, description, priority, link)
       VALUES ${values}`,
      params,
    );
    return res.json({ sent: alumni.length });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/notifications/:id/read
router.patch('/:id/read', async (req, res, next) => {
  try {
    await mysql.query('UPDATE notifications SET is_read = 1 WHERE id = ? LIMIT 1', [
      req.params.id,
    ]);
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/notifications/read-all?includeRoleBroadcasts=true
router.patch('/read-all', async (req, res, next) => {
  try {
    const include =
      req.query.includeRoleBroadcasts === 'true' ||
      req.query.includeRoleBroadcasts === '1';
    const scope = scopeWhere(req.user, include && req.user.role === 'admin');
    await mysql.query(
      `UPDATE notifications SET is_read = 1 WHERE ${scope.sql} AND is_read = 0`,
      scope.params,
    );
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    await mysql.query(
      'UPDATE notifications SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
    );
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/notifications (body: { ids: [...] })
router.delete('/', async (req, res, next) => {
  try {
    const ids = Array.isArray(req.body?.ids) ? req.body.ids : [];
    if (ids.length === 0) return res.json({ deleted: 0 });
    const placeholders = ids.map(() => '?').join(', ');
    const result = await mysql.query(
      `UPDATE notifications SET is_deleted = 1, deleted_at = ? WHERE is_deleted = 0 AND id IN (${placeholders})`,
      [
        new Date().toISOString().slice(0, 19).replace('T', ' '),
        ...ids.map(String),
      ],
    );
    return res.json({ deleted: result.affectedRows ?? 0 });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
