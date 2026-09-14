const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin, toPublicUser } = authenticate;
const mysql = require('../config/mysql');
const passwords = require('../config/passwords');

const router = express.Router();

function toRegistryEntry(row) {
  if (!row) return null;
  return {
    alumniId: row.id,
    fullName: row.full_name,
    course: row.course,
    academicYearGraduated: row.academic_year_graduated ?? null,
    graduationYear:
      row.graduation_year === null || row.graduation_year === undefined
        ? null
        : Number(row.graduation_year),
    status: row.status,
    activatedAt: row.activated_at
      ? new Date(row.activated_at).toISOString()
      : null,
    createdAt: row.created_at
      ? new Date(row.created_at).toISOString()
      : null,
    updatedAt: row.updated_at
      ? new Date(row.updated_at).toISOString()
      : null,
  };
}

const ADMIN_USER_COLUMNS =
  `id, email, full_name, role, student_number, alumni_id, course_name,
   section, graduation_year, academic_year_graduated, gender, birthdate,
   phone_number, current_address, permanent_address, biography, photo_url,
   social_links_json, resume_json, employment_status, is_verified,
   email_verified, disabled, is_approved, has_logged_in, last_login_at,
   profile_completion, created_at, updated_at`;

// ---------------------------------------------------------------------------
// Public: fetch one registry entry (used by the pre-login Alumni ID check).
// Only reveals name/course/batch for an already-known ID.
// ---------------------------------------------------------------------------
router.get('/registry/:alumniId', async (req, res, next) => {
  try {
    const rows = await mysql.query(
      'SELECT * FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [req.params.alumniId],
    );
    if (rows.length === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'This Alumni ID is not in the registry.',
      });
    }
    return res.json(toRegistryEntry(rows[0]));
  } catch (err) {
    return next(err);
  }
});

router.use(authenticate);

// GET /api/alumni - List alumni with course and graduation filters
router.get('/', async (req, res, next) => {
  try {
    const { course, year, query: search, limit } = req.query;

    let sql = `
      SELECT id, full_name, email, course_name, graduation_year,
             employment_status, is_verified, is_approved, disabled,
             academic_year_graduated, alumni_id, created_at
      FROM users
      WHERE role = 'alumni' AND is_deleted = 0
    `;
    const params = [];

    if (course) {
      sql += ' AND course_name = ?';
      params.push(course);
    }
    if (year) {
      sql += ' AND graduation_year = ?';
      params.push(Number(year));
    }
    if (search) {
      sql += ' AND (full_name LIKE ? OR email LIKE ? OR alumni_id LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    sql += ' ORDER BY graduation_year DESC, full_name ASC LIMIT ?';
    params.push(Math.min(Number(limit) || 50, 200));

    const rows = await mysql.query(sql, params);
    return res.json({ source: 'mysql', data: rows });
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// Admin: user management (replaces direct Firestore access from staff UI).
// ---------------------------------------------------------------------------
router.get('/users', requireAdmin, async (req, res, next) => {
  try {
    const { role, approved, q, limit } = req.query;
    let sql = `SELECT ${ADMIN_USER_COLUMNS} FROM users WHERE is_deleted = 0`;
    const params = [];
    if (role === 'admin' || role === 'alumni') {
      sql += ' AND role = ?';
      params.push(role);
    }
    if (approved === '0' || approved === 'false') {
      sql += ' AND is_approved = 0';
    } else if (approved === '1' || approved === 'true') {
      sql += ' AND is_approved = 1';
    }
    if (q) {
      sql += ' AND (full_name LIKE ? OR email LIKE ? OR alumni_id LIKE ?)';
      params.push(`%${q}%`, `%${q}%`, `%${q}%`);
    }
    sql += ' ORDER BY created_at DESC LIMIT ?';
    params.push(Math.min(Number(limit) || 200, 500));
    const rows = await mysql.query(sql, params);
    return res.json(rows.map(toPublicUser));
  } catch (err) {
    return next(err);
  }
});

router.get('/users/:id', requireAdmin, async (req, res, next) => {
  try {
    const rows = await mysql.query(
      `SELECT ${ADMIN_USER_COLUMNS} FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1`,
      [req.params.id],
    );
    if (rows.length === 0) {
      return res.status(404).json({
        error: 'user_not_found',
        message: 'No user exists with that id.',
      });
    }
    return res.json(toPublicUser(rows[0]));
  } catch (err) {
    return next(err);
  }
});

const ADMIN_EDITABLE = new Set([
  'fullName',
  'course',
  'graduationYear',
  'academicYearGraduated',
  'employmentStatus',
  'isVerified',
  'approved',
  'disabled',
  'role',
  'studentNumber',
  'section',
  'phoneNumber',
]);

const ADMIN_COLUMN = {
  fullName: 'full_name',
  course: 'course_name',
  graduationYear: 'graduation_year',
  academicYearGraduated: 'academic_year_graduated',
  employmentStatus: 'employment_status',
  isVerified: 'is_verified',
  approved: 'is_approved',
  disabled: 'disabled',
  role: 'role',
  studentNumber: 'student_number',
  section: 'section',
  phoneNumber: 'phone_number',
};

function adminValue(key, value) {
  if (value === null || value === undefined) return null;
  if (['isVerified', 'approved', 'disabled'].includes(key)) {
    return value === true || value === 1 || value === '1' ? 1 : 0;
  }
  if (key === 'graduationYear') {
    const n = Number(value);
    return Number.isFinite(n) ? Math.trunc(n) : null;
  }
  if (key === 'role') return value === 'admin' ? 'admin' : 'alumni';
  if (typeof value === 'string') {
    const t = value.trim();
    return t === '' ? null : t;
  }
  return value;
}

router.patch('/users/:id', requireAdmin, async (req, res, next) => {
  try {
    const sets = [];
    const params = [];
    for (const [key, value] of Object.entries(req.body ?? {})) {
      if (!ADMIN_EDITABLE.has(key)) continue;
      sets.push(`\`${ADMIN_COLUMN[key]}\` = ?`);
      params.push(adminValue(key, value));
    }
    if (sets.length === 0) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable user fields.',
      });
    }
    params.push(req.params.id);
    const result = await mysql.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = ? AND is_deleted = 0`,
      params,
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'user_not_found',
        message: 'No user exists with that id.',
      });
    }
    const rows = await mysql.query(
      `SELECT ${ADMIN_USER_COLUMNS} FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1`,
      [req.params.id],
    );
    return res.json({ updated: true, user: toPublicUser(rows[0]) });
  } catch (err) {
    return next(err);
  }
});

router.delete('/users/:id', requireAdmin, async (req, res, next) => {
  try {
    if (req.params.id === req.user.uid) {
      return res.status(400).json({
        error: 'cannot_delete_self',
        message: 'You cannot delete your own administrator account.',
      });
    }
    // Soft-delete: the hosting DB user has no DELETE privilege, and the
    // tracer-study audit trail prefers retained records anyway.
    const result = await mysql.query(
      'UPDATE users SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [passwords.utcNowSql(), req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'user_not_found',
        message: 'No user exists with that id.',
      });
    }
    await mysql.query('UPDATE auth_sessions SET revoked = 1 WHERE user_id = ?', [
      req.params.id,
    ]);
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// Admin: alumni registry management.
// ---------------------------------------------------------------------------
router.get('/registry', requireAdmin, async (req, res, next) => {
  try {
    const rows = await mysql.query(
      'SELECT * FROM alumni_registry WHERE is_deleted = 0 ORDER BY created_at DESC LIMIT 500',
    );
    return res.json(rows.map(toRegistryEntry));
  } catch (err) {
    return next(err);
  }
});

router.post('/registry', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const alumniId =
      typeof body.alumniId === 'string' ? body.alumniId.trim() : '';
    const fullName =
      typeof body.fullName === 'string' ? body.fullName.trim() : '';
    if (!alumniId || !/^[A-Za-z0-9_-]+$/.test(alumniId)) {
      return res.status(400).json({
        error: 'invalid_alumni_id',
        message: 'A valid Alumni ID is required.',
      });
    }
    if (!fullName) {
      return res.status(400).json({
        error: 'missing_name',
        message: 'Full name is required.',
      });
    }
    const existing = await mysql.query(
      'SELECT id, is_deleted FROM alumni_registry WHERE id = ? LIMIT 1',
      [alumniId],
    );
    if (existing.length > 0 && existing[0].is_deleted !== 1) {
      return res.status(409).json({
        error: 'duplicate_id',
        message: 'This Alumni ID is already in the registry.',
      });
    }
    const courseValue =
      typeof body.course === 'string' && body.course.trim()
        ? body.course.trim()
        : 'BS Computer Science';
    const ayValue =
      typeof body.academicYearGraduated === 'string' &&
      body.academicYearGraduated.trim()
        ? body.academicYearGraduated.trim()
        : null;
    const gyValue =
      body.graduationYear === undefined || body.graduationYear === null
        ? null
        : Number(body.graduationYear);
    if (existing.length > 0) {
      await mysql.query(
        `UPDATE alumni_registry SET full_name = ?, course = ?,
           academic_year_graduated = ?, graduation_year = ?,
           is_deleted = 0, deleted_at = NULL
         WHERE id = ?`,
        [fullName, courseValue, ayValue, gyValue, alumniId],
      );
    } else {
      await mysql.query(
        `INSERT INTO alumni_registry
           (id, full_name, course, academic_year_graduated, graduation_year, status)
         VALUES (?, ?, ?, ?, ?, 'pending')`,
        [alumniId, fullName, courseValue, ayValue, gyValue],
      );
    }
    const rows = await mysql.query(
      'SELECT * FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [alumniId],
    );
    return res.status(201).json(toRegistryEntry(rows[0]));
  } catch (err) {
    return next(err);
  }
});

router.patch('/registry/:alumniId', requireAdmin, async (req, res, next) => {
  try {
    const sets = [];
    const params = [];
    const body = req.body ?? {};
    if (typeof body.fullName === 'string' && body.fullName.trim()) {
      sets.push('full_name = ?');
      params.push(body.fullName.trim());
    }
    if (typeof body.course === 'string' && body.course.trim()) {
      sets.push('course = ?');
      params.push(body.course.trim());
    }
    if (body.academicYearGraduated !== undefined) {
      sets.push('academic_year_graduated = ?');
      params.push(body.academicYearGraduated || null);
    }
    if (body.graduationYear !== undefined) {
      sets.push('graduation_year = ?');
      params.push(
        body.graduationYear === null ? null : Number(body.graduationYear),
      );
    }
    if (
      body.status === 'pending' ||
      body.status === 'active' ||
      body.status === 'disabled'
    ) {
      sets.push('status = ?');
      params.push(body.status);
      if (body.status === 'active') {
        sets.push('activated_at = ?');
        params.push(passwords.utcNowSql());
      }
    }
    if (sets.length === 0) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable registry fields.',
      });
    }
    params.push(req.params.alumniId);
    const result = await mysql.query(
      `UPDATE alumni_registry SET ${sets.join(', ')}, is_deleted = 0, deleted_at = NULL WHERE id = ? AND is_deleted = 0`,
      params,
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'This Alumni ID is not in the registry.',
      });
    }
    const rows = await mysql.query(
      'SELECT * FROM alumni_registry WHERE id = ? LIMIT 1',
      [req.params.alumniId],
    );
    return res.json({ updated: true, entry: toRegistryEntry(rows[0]) });
  } catch (err) {
    return next(err);
  }
});

router.delete('/registry/:alumniId', requireAdmin, async (req, res, next) => {
  try {
    // Soft-delete (no DELETE privilege on the hosting database).
    const result = await mysql.query(
      'UPDATE alumni_registry SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [passwords.utcNowSql(), req.params.alumniId],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'This Alumni ID is not in the registry.',
      });
    }
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
module.exports.toRegistryEntry = toRegistryEntry;
