const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { toPublicUser } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

function isoDateTime(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function toCertificate(row) {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title ?? '',
    provider: row.provider ?? 'other',
    fileUrl: row.file_url ?? '',
    storagePath: row.storage_path ?? '',
    fileType: row.file_type ?? 'image',
    issuedDate: row.issued_date
      ? new Date(row.issued_date).toISOString().slice(0, 10)
      : null,
    uploadedAt: isoDateTime(row.uploaded_at) ?? new Date().toISOString(),
  };
}

router.use(authenticate);

// Resume metadata lives as a single nested object on the user row.
router.get('/resume', async (req, res, next) => {
  try {
    const userId =
      req.user.role === 'admin' &&
      typeof req.query.userId === 'string' &&
      req.query.userId
        ? req.query.userId
        : req.user.uid;
    const rows = await mysql.query(
      'SELECT resume_json FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [userId],
    );
    if (rows.length === 0 || !rows[0].resume_json) return res.json(null);
    const value = rows[0].resume_json;
    return res.json(typeof value === 'object' ? value : JSON.parse(value));
  } catch (err) {
    return next(err);
  }
});

router.put('/resume', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.fileUrl) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'fileUrl is required.',
      });
    }
    const resume = {
      fileUrl: String(body.fileUrl),
      storagePath: String(body.storagePath ?? ''),
      fileName: String(body.fileName ?? ''),
      sizeBytes: Number(body.sizeBytes) || 0,
      uploadedAt: new Date().toISOString(),
    };
    await mysql.query('UPDATE users SET resume_json = ? WHERE id = ?', [
      JSON.stringify(resume),
      req.user.uid,
    ]);
    const rows = await mysql.query('SELECT * FROM users WHERE id = ? LIMIT 1', [
      req.user.uid,
    ]);
    return res.json({ updated: true, resume, user: toPublicUser(rows[0]) });
  } catch (err) {
    return next(err);
  }
});

router.delete('/resume', async (req, res, next) => {
  try {
    await mysql.query('UPDATE users SET resume_json = NULL WHERE id = ?', [
      req.user.uid,
    ]);
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

router.get('/certificates', async (req, res, next) => {
  try {
    const userId =
      req.user.role === 'admin' &&
      typeof req.query.userId === 'string' &&
      req.query.userId
        ? req.query.userId
        : req.user.uid;
    const rows = await mysql.query(
      'SELECT * FROM certificates WHERE user_id = ? AND is_deleted = 0 ORDER BY uploaded_at DESC',
      [userId],
    );
    return res.json(rows.map(toCertificate));
  } catch (err) {
    return next(err);
  }
});

router.post('/certificates', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.fileUrl) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'fileUrl is required.',
      });
    }
    const allowed = new Set([
      'tesda',
      'google',
      'cisco',
      'aws',
      'microsoft',
      'oracle',
      'other',
    ]);
    const id = crypto.randomUUID();
    await mysql.query(
      `INSERT INTO certificates
         (id, user_id, title, provider, file_url, storage_path, file_type, issued_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        req.user.uid,
        body.title ? String(body.title) : '',
        allowed.has(body.provider) ? body.provider : 'other',
        String(body.fileUrl),
        body.storagePath ? String(body.storagePath) : '',
        body.fileType ? String(body.fileType) : 'image',
        body.issuedDate
          ? new Date(body.issuedDate).toISOString().slice(0, 10)
          : null,
      ],
    );
    const rows = await mysql.query(
      'SELECT * FROM certificates WHERE id = ? LIMIT 1',
      [id],
    );
    return res.status(201).json(toCertificate(rows[0]));
  } catch (err) {
    return next(err);
  }
});

router.delete('/certificates/:id', async (req, res, next) => {
  try {
    const result = await mysql.query(
      'UPDATE certificates SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No certificate exists with that id.',
      });
    }
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
