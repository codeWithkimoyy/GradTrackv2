const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');
const passwords = require('../config/passwords');

const router = express.Router();

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function toEntry(row) {
  return {
    id: row.id,
    action: row.action,
    title: row.title ?? null,
    description: row.description ?? null,
    actorId: row.actor_id ?? null,
    actorName: row.actor_name ?? null,
    actorRole: row.actor_role ?? null,
    targetId: row.target_id ?? null,
    targetType: row.target_type ?? row.target_resource ?? null,
    details: row.details_json
      ? typeof row.details_json === 'object'
        ? row.details_json
        : JSON.parse(row.details_json)
      : null,
    createdAt: iso(row.created_at) ?? new Date().toISOString(),
  };
}

router.use(authenticate);

// GET /api/audit-logs (admin, newest first)
router.get('/', requireAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const rows = await mysql.query(
      `SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT ${limit}`,
    );
    return res.json(rows.map(toEntry));
  } catch (err) {
    return next(err);
  }
});

// POST /api/audit-logs (admin append-only)
router.post('/', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.action) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'action is required.',
      });
    }
    const id = crypto.randomUUID();
    await mysql.query(
      `INSERT INTO audit_logs
         (id, user_id, action, title, description, actor_id, actor_name,
          actor_role, target_id, target_type, details_json, ip_address)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        req.user.uid,
        String(body.action),
        body.title ? String(body.title) : null,
        body.description ? String(body.description) : null,
        body.actorId ? String(body.actorId) : req.user.uid,
        body.actorName ? String(body.actorName) : req.user.fullName,
        body.actorRole ? String(body.actorRole) : req.user.role,
        body.targetId ? String(body.targetId) : null,
        body.targetType ? String(body.targetType) : null,
        body.details !== undefined ? JSON.stringify(body.details) : null,
        req.ip ?? null,
      ],
    );
    return res.status(201).json({ id, createdAt: passwords.utcNowSql() });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
