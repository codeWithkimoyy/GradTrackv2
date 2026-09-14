const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

// Generic content collections replacing the Firestore docs managed through
// the shared CollectionListScreen (announcements, events, jobs, reports).
const COLLECTIONS = {
  announcements: {
    table: 'announcements',
    fields: ['title', 'description', 'visibility'],
  },
  events: {
    table: 'events',
    fields: ['title', 'description', 'location', 'eventDate', 'visibility'],
    column: {
      title: 'title',
      description: 'description',
      location: 'location',
      eventDate: 'event_date',
      visibility: 'visibility',
    },
  },
  jobs: {
    table: 'jobs',
    fields: [
      'company',
      'title',
      'jobTitle',
      'industry',
      'employmentType',
      'salary',
      'location',
      'workSetup',
      'description',
      'startDate',
      'endDate',
      'isCurrent',
      'visibility',
    ],
    column: {
      company: 'company',
      title: 'title',
      jobTitle: 'job_title',
      industry: 'industry',
      employmentType: 'employment_type',
      salary: 'salary',
      location: 'location',
      workSetup: 'work_setup',
      description: 'description',
      startDate: 'start_date',
      endDate: 'end_date',
      isCurrent: 'is_current',
      visibility: 'visibility',
    },
  },
  reports: {
    table: 'reports',
    fields: ['type', 'title', 'period', 'description'],
  },
};

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function toItem(collection, row) {
  const base = { ...row };
  const out = { id: row.id };
  for (const [key, value] of Object.entries(base)) {
    if (key === 'id') continue;
    const camel = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    out[camel] = value;
  }
  if (collection === 'events') {
    out.eventDate = row.event_date ? iso(row.event_date) : null;
  }
  if (collection === 'jobs') {
    out.startDate = row.start_date ? iso(row.start_date) : null;
    out.endDate = row.end_date ? iso(row.end_date) : null;
    out.isCurrent = row.is_current === 1;
  }
  out.createdAt = iso(row.created_at) ?? new Date().toISOString();
  out.updatedAt = iso(row.updated_at);
  return out;
}

function normalizeValue(collection, field, value) {
  if (value === null || value === undefined) return null;
  if (field === 'visibility') {
    return value === 'private' ? 'private' : 'public';
  }
  if (field === 'eventDate' || field === 'startDate' || field === 'endDate') {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    return field === 'eventDate'
      ? d.toISOString().slice(0, 19).replace('T', ' ')
      : d.toISOString().slice(0, 10);
  }
  if (field === 'isCurrent') return value ? 1 : 0;
  if (field === 'workSetup') {
    const v = String(value).toLowerCase().replace(/[-_\s]/g, '');
    return v === 'remote' ? 'remote' : v === 'hybrid' ? 'hybrid' : 'on_site';
  }
  if (typeof value === 'string') {
    const t = value.trim();
    return t === '' ? null : t;
  }
  return value;
}

function columnName(collection, field) {
  const def = COLLECTIONS[collection];
  if (def.column && def.column[field]) return def.column[field];
  return field.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
}

router.use(authenticate);

// GET /api/content/:collection?visibility=public
router.get('/:collection', async (req, res, next) => {
  try {
    const def = COLLECTIONS[req.params.collection];
    if (!def) {
      return res.status(404).json({
        error: 'unknown_collection',
        message: 'Unknown content collection.',
      });
    }
    let sql = `SELECT * FROM \`${def.table}\` WHERE is_deleted = 0`;
    const params = [];
    if (req.query.visibility === 'public' && def.fields.includes('visibility')) {
      sql += ' AND visibility = ?';
      params.push('public');
    }
    const orderCol = def.table === 'jobs' ? 'created_at' : 'created_at';
    sql += ` ORDER BY \`${orderCol}\` DESC LIMIT 500`;
    const rows = await mysql.query(sql, params);
    return res.json(rows.map((r) => toItem(req.params.collection, r)));
  } catch (err) {
    return next(err);
  }
});

// POST /api/content/:collection  (admin; body.notify=true fans out a bell)
router.post('/:collection', requireAdmin, async (req, res, next) => {
  try {
    const def = COLLECTIONS[req.params.collection];
    if (!def) {
      return res.status(404).json({
        error: 'unknown_collection',
        message: 'Unknown content collection.',
      });
    }
    const body = req.body ?? {};
    const id = crypto.randomUUID();
    const cols = ['id'];
    const placeholders = ['?'];
    const params = [id];
    for (const field of def.fields) {
      if (body[field] === undefined) continue;
      cols.push(`\`${columnName(req.params.collection, field)}\``);
      placeholders.push('?');
      params.push(
        normalizeValue(req.params.collection, field, body[field]),
      );
    }
    cols.push('created_by');
    placeholders.push('?');
    params.push(req.user.uid);
    await mysql.query(
      `INSERT INTO \`${def.table}\` (${cols.join(', ')}) VALUES (${placeholders.join(', ')})`,
      params,
    );

    if (body.notify === true && req.params.collection !== 'reports') {
      try {
        const alumni = await mysql.query(
          "SELECT id FROM users WHERE role = 'alumni' AND is_deleted = 0 AND (disabled IS NULL OR disabled = 0)",
        );
        if (alumni.length > 0) {
          const values = alumni.map(() => '(?, ?, ?, ?, ?)').join(', ');
          const nparams = [];
          for (const a of alumni) {
            nparams.push(
              crypto.randomUUID(),
              a.id,
              req.params.collection === 'events' ? 'event' : 'announcement',
              body.title ? String(body.title) : 'New update',
              body.description ? String(body.description) : '',
            );
          }
          await mysql.query(
            `INSERT INTO notifications (id, user_id, type, title, description)
             VALUES ${values}`,
            nparams,
          );
        }
      } catch (_) {
        // best-effort only
      }
    }

    const rows = await mysql.query(
      `SELECT * FROM \`${def.table}\` WHERE id = ? LIMIT 1`,
      [id],
    );
    return res.status(201).json(toItem(req.params.collection, rows[0]));
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/content/:collection/:id (admin)
router.patch('/:collection/:id', requireAdmin, async (req, res, next) => {
  try {
    const def = COLLECTIONS[req.params.collection];
    if (!def) {
      return res.status(404).json({
        error: 'unknown_collection',
        message: 'Unknown content collection.',
      });
    }
    const sets = [];
    const params = [];
    for (const field of def.fields) {
      if (req.body?.[field] === undefined) continue;
      sets.push(
        `\`${columnName(req.params.collection, field)}\` = ?`,
      );
      params.push(
        normalizeValue(req.params.collection, field, req.body[field]),
      );
    }
    if (sets.length === 0) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable fields.',
      });
    }
    params.push(req.params.id);
    const result = await mysql.query(
      `UPDATE \`${def.table}\` SET ${sets.join(', ')} WHERE id = ? AND is_deleted = 0`,
      params,
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No item exists with that id.',
      });
    }
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/content/:collection/:id (admin)
router.delete('/:collection/:id', requireAdmin, async (req, res, next) => {
  try {
    const def = COLLECTIONS[req.params.collection];
    if (!def) {
      return res.status(404).json({
        error: 'unknown_collection',
        message: 'Unknown content collection.',
      });
    }
    const result = await mysql.query(
      `UPDATE \`${def.table}\` SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1`,
      [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No item exists with that id.',
      });
    }
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
