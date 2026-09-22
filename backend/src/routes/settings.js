const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

function parseValue(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return value;
  }
}

// GET /api/settings (any signed-in user; admin screen + public fallbacks)
router.get('/', authenticate, async (req, res, next) => {
  try {
    const rows = await mysql.query('SELECT * FROM system_settings');
    const out = {};
    for (const row of rows) {
      out[row.setting_key] = parseValue(row.value_json);
    }
    return res.json(out);
  } catch (err) {
    return next(err);
  }
});

// PUT /api/settings (admin upsert of the whole settings map)
router.put('/', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (typeof body !== 'object' || Array.isArray(body)) {
      return res.status(400).json({
        error: 'invalid_settings',
        message: 'Settings must be a JSON object.',
      });
    }
    for (const [key, value] of Object.entries(body)) {
      if (!/^[A-Za-z0-9_.-]{1,128}$/.test(key)) continue;
      const payload = JSON.stringify(value);
      // eslint-disable-next-line no-await-in-loop
      if (mysql.isPostgres) {
        await mysql.query(
          `INSERT INTO system_settings (setting_key, value_json)
           VALUES (?, ?)
           ON CONFLICT (setting_key) DO UPDATE SET value_json = EXCLUDED.value_json`,
          [key, payload],
        );
      } else {
        await mysql.query(
          `INSERT INTO system_settings (setting_key, value_json)
           VALUES (?, ?)
           ON DUPLICATE KEY UPDATE value_json = VALUES(value_json)`,
          [key, payload],
        );
      }
    }
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
