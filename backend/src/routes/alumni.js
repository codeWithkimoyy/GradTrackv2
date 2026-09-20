const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin, toPublicUser } = authenticate;
const mysql = require('../config/mysql');
const db = require('../db/procedures');
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
    let rows;
    try {
      rows = await db.alumniRegistry.getById(req.params.alumniId);
    } catch (_) {
      rows = await mysql.query(
        'SELECT * FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [req.params.alumniId],
      );
    }
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

// GET /api/alumni/batches (admin) — graduation-year buckets for survey batch targeting.
router.get('/batches', requireAdmin, async (req, res, next) => {
  try {
    let rows;
    try {
      rows = await db.users.batches();
    } catch (_) {
      rows = await mysql.query(
        `SELECT DISTINCT graduation_year AS yr
         FROM users
         WHERE role = 'alumni' AND is_deleted = 0 AND graduation_year IS NOT NULL
         ORDER BY graduation_year DESC`,
      );
    }
    return res.json(rows.map((r) => Number(r.yr)));
  } catch (err) {
    return next(err);
  }
});

// GET /api/alumni - List alumni with course and graduation filters (via SP)
router.get('/', async (req, res, next) => {
  try {
    const { course, year, query: search, limit } = req.query;
    let rows;
    try {
      rows = await db.users.listAlumni(course || null, year ? Number(year) : null, search || null, limit);
      return res.json(rows);
    } catch (_) {
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
      rows = await mysql.query(sql, params);
      return res.json(rows);
    }
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// Admin: export alumni list to standard CSV for institutional tracer reports
// ---------------------------------------------------------------------------
function escapeCsv(field) {
  if (field === null || field === undefined) return '""';
  const str = String(field).replace(/"/g, '""');
  return `"${str}"`;
}

router.get('/export/csv', requireAdmin, async (req, res, next) => {
  try {
    const { course, year, status } = req.query;
    let rows;
    try {
      rows = await db.users.exportList(course || null, year ? Number(year) : null, status || null);
    } catch (_) {
      let sql = `
        SELECT alumni_id, full_name, email, phone_number, course_name, section,
               graduation_year, academic_year_graduated, employment_status,
               is_verified, is_approved, created_at
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
      if (status) {
        sql += ' AND employment_status = ?';
        params.push(status);
      }
      sql += ' ORDER BY graduation_year DESC, full_name ASC';
      rows = await mysql.query(sql, params);
    }

    const headers = [
      'Alumni ID',
      'Full Name',
      'Email',
      'Phone Number',
      'Course',
      'Section',
      'Graduation Year',
      'Academic Year',
      'Employment Status',
      'Verified',
      'Approved',
      'Registered Date',
    ];

    const csvLines = [headers.map(escapeCsv).join(',')];
    for (const row of rows) {
      csvLines.push(
        [
          row.alumni_id || '',
          row.full_name || '',
          row.email || '',
          row.phone_number || '',
          row.course_name || '',
          row.section || '',
          row.graduation_year ?? '',
          row.academic_year_graduated || '',
          row.employment_status || '',
          row.is_verified ? 'Yes' : 'No',
          row.is_approved ? 'Yes' : 'No',
          row.created_at ? new Date(row.created_at).toISOString() : '',
        ]
          .map(escapeCsv)
          .join(','),
      );
    }

    const filename = `gradtrack_alumni_${new Date().toISOString().slice(0, 10)}.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(csvLines.join('\r\n'));
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
    let approvedVal = null;
    if (approved === '0' || approved === 'false') approvedVal = 0;
    else if (approved === '1' || approved === 'true') approvedVal = 1;
    let rows;
    try {
      rows = await db.users.listAdmin(role || null, approvedVal, q || null, limit);
    } catch (_) {
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
      rows = await mysql.query(sql, params);
    }
    return res.json(rows.map(toPublicUser));
  } catch (err) {
    return next(err);
  }
});

router.get('/users/:id', requireAdmin, async (req, res, next) => {
  try {
    let rows;
    try {
      rows = await db.users.getById(req.params.id);
    } catch (_) {
      rows = await mysql.query(
        `SELECT ${ADMIN_USER_COLUMNS} FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1`,
        [req.params.id],
      );
    }
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
    const body = req.body ?? {};
    const hasEditable = Object.keys(body).some((k) => ADMIN_EDITABLE.has(k));
    if (!hasEditable) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable user fields.',
      });
    }
    // Prefer SP path
    try {
      const spData = {};
      for (const [key, value] of Object.entries(body)) {
        if (!ADMIN_EDITABLE.has(key)) continue;
        spData[key] = adminValue(key, value);
      }
      const updatedRows = await db.users.updateAdmin(req.params.id, spData);
      // SP returns updated row; fallback check
      if (!updatedRows || updatedRows.length === 0) {
        return res.status(404).json({ error: 'user_not_found', message: 'No user exists with that id.' });
      }
      return res.json({ updated: true, user: toPublicUser(updatedRows[0]) });
    } catch (_) {
      // Fallback to dynamic SQL when SP not available
      const sets = [];
      const params = [];
      for (const [key, value] of Object.entries(body)) {
        if (!ADMIN_EDITABLE.has(key)) continue;
        sets.push(`\`${ADMIN_COLUMN[key]}\` = ?`);
        params.push(adminValue(key, value));
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
    }
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
    let result;
    try {
      result = await db.users.softDelete(req.params.id, passwords.utcNowSql());
      // softDelete SP also revokes sessions internally, but keep explicit revoke for host compat
      try { await db.authSessions.revokeByUser(req.params.id); } catch (_) {}
    } catch (_) {
      result = await mysql.query(
        'UPDATE users SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [passwords.utcNowSql(), req.params.id],
      );
      if (result.affectedRows === 0) {
        return res.status(404).json({ error: 'user_not_found', message: 'No user exists with that id.' });
      }
      await mysql.query('UPDATE auth_sessions SET revoked = 1 WHERE user_id = ?', [req.params.id]);
      return res.json({ deleted: true });
    }
    // mysql.call for UPDATE returns OkPacket, check affectedRows
    const affected = result && typeof result.affectedRows === 'number' ? result.affectedRows : 1;
    if (affected === 0) {
      return res.status(404).json({ error: 'user_not_found', message: 'No user exists with that id.' });
    }
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
    let rows;
    try {
      rows = await db.alumniRegistry.list(null, 500);
    } catch (_) {
      rows = await mysql.query(
        'SELECT * FROM alumni_registry WHERE is_deleted = 0 ORDER BY created_at DESC LIMIT 500',
      );
    }
    return res.json(rows.map(toRegistryEntry));
  } catch (err) {
    return next(err);
  }
});

router.post('/registry', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const alumniId = typeof body.alumniId === 'string' ? body.alumniId.trim() : '';
    const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
    if (!alumniId || !/^[A-Za-z0-9_-]+$/.test(alumniId)) {
      return res.status(400).json({ error: 'invalid_alumni_id', message: 'A valid Alumni ID is required.' });
    }
    let existing;
    try {
      existing = await db.alumniRegistry.getById(alumniId);
      // Check deleted flag manually because SP hides deleted; need raw fallback to detect soft-deleted
      if (existing.length === 0) {
        // Try raw to see deleted record
        try {
          existing = await mysql.query('SELECT id, is_deleted FROM alumni_registry WHERE id = ? LIMIT 1', [alumniId]);
        } catch (_) { existing = []; }
      }
    } catch (_) {
      existing = await mysql.query('SELECT id, is_deleted FROM alumni_registry WHERE id = ? LIMIT 1', [alumniId]);
    }
    if (existing.length > 0 && existing[0].is_deleted !== 1) {
      // SP would have returned row if not deleted; raw existing confirms duplicate
      const checkRows = existing[0].is_deleted === undefined ? existing : await (async () => {
        try { return await db.alumniRegistry.getById(alumniId); } catch (_) { return existing; }
      })();
      if (checkRows.length > 0) {
        return res.status(409).json({ error: 'duplicate_id', message: 'This Alumni ID is already in the registry.' });
      }
    }
    const courseValue = typeof body.course === 'string' && body.course.trim() ? body.course.trim() : 'BS Computer Science';
    const ayValue = typeof body.academicYearGraduated === 'string' && body.academicYearGraduated.trim() ? body.academicYearGraduated.trim() : null;
    const gyValue = body.graduationYear === undefined || body.graduationYear === null ? null : Number(body.graduationYear);
    let rows;
    try {
      if (existing.length > 0) {
        await db.alumniRegistry.reactivateDeleted(alumniId, fullName, courseValue, ayValue, gyValue);
      } else {
        await db.alumniRegistry.create(alumniId, fullName, courseValue, ayValue, gyValue, 'pending');
      }
      rows = await db.alumniRegistry.getById(alumniId);
    } catch (_) {
      if (existing.length > 0) {
        await mysql.query(
          `UPDATE alumni_registry SET full_name = ?, course = ?, academic_year_graduated = ?, graduation_year = ?, status = 'pending', activated_at = NULL, is_deleted = 0, deleted_at = NULL WHERE id = ?`,
          [fullName, courseValue, ayValue, gyValue, alumniId],
        );
      } else {
        await mysql.query(
          `INSERT INTO alumni_registry (id, full_name, course, academic_year_graduated, graduation_year, status) VALUES (?, ?, ?, ?, ?, 'pending')`,
          [alumniId, fullName, courseValue, ayValue, gyValue],
        );
      }
      rows = await mysql.query('SELECT * FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1', [alumniId]);
    }
    return res.status(201).json(toRegistryEntry(rows[0]));
  } catch (err) {
    return next(err);
  }
});

router.patch('/registry/:alumniId', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const hasField =
      (typeof body.fullName === 'string' && body.fullName.trim()) ||
      (typeof body.course === 'string' && body.course.trim()) ||
      body.academicYearGraduated !== undefined ||
      body.graduationYear !== undefined ||
      ['pending','active','disabled'].includes(body.status);
    if (!hasField) {
      return res.status(400).json({ error: 'no_editable_fields', message: 'The request does not contain editable registry fields.' });
    }
    try {
      const activatedAt = body.status === 'active' ? passwords.utcNowSql() : null;
      await db.alumniRegistry.update(req.params.alumniId, {
        fullName: typeof body.fullName === 'string' ? body.fullName.trim() || null : null,
        course: typeof body.course === 'string' ? body.course.trim() || null : null,
        academicYearGraduated: body.academicYearGraduated !== undefined ? (body.academicYearGraduated || null) : null,
        graduationYear: body.graduationYear !== undefined ? (body.graduationYear === null ? null : Number(body.graduationYear)) : null,
        status: ['pending','active','disabled'].includes(body.status) ? body.status : null,
        activatedAt,
      });
      const rows = await db.alumniRegistry.getById(req.params.alumniId);
      if (rows.length === 0) return res.status(404).json({ error: 'not_found', message: 'This Alumni ID is not in the registry.' });
      return res.json({ updated: true, entry: toRegistryEntry(rows[0]) });
    } catch (_) {
      const sets = [];
      const params = [];
      if (typeof body.fullName === 'string' && body.fullName.trim()) { sets.push('full_name = ?'); params.push(body.fullName.trim()); }
      if (typeof body.course === 'string' && body.course.trim()) { sets.push('course = ?'); params.push(body.course.trim()); }
      if (body.academicYearGraduated !== undefined) { sets.push('academic_year_graduated = ?'); params.push(body.academicYearGraduated || null); }
      if (body.graduationYear !== undefined) { sets.push('graduation_year = ?'); params.push(body.graduationYear === null ? null : Number(body.graduationYear)); }
      if (['pending','active','disabled'].includes(body.status)) {
        sets.push('status = ?'); params.push(body.status);
        if (body.status === 'active') { sets.push('activated_at = ?'); params.push(passwords.utcNowSql()); }
      }
      params.push(req.params.alumniId);
      const result = await mysql.query(`UPDATE alumni_registry SET ${sets.join(', ')}, is_deleted = 0, deleted_at = NULL WHERE id = ? AND is_deleted = 0`, params);
      if (result.affectedRows === 0) return res.status(404).json({ error: 'not_found', message: 'This Alumni ID is not in the registry.' });
      const rows = await mysql.query('SELECT * FROM alumni_registry WHERE id = ? LIMIT 1', [req.params.alumniId]);
      return res.json({ updated: true, entry: toRegistryEntry(rows[0]) });
    }
  } catch (err) {
    return next(err);
  }
});

router.delete('/registry/:alumniId', requireAdmin, async (req, res, next) => {
  try {
    let result;
    try {
      result = await db.alumniRegistry.softDelete(req.params.alumniId, passwords.utcNowSql());
    } catch (_) {
      result = await mysql.query(
        'UPDATE alumni_registry SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [passwords.utcNowSql(), req.params.alumniId],
      );
    }
    const affected = result && typeof result.affectedRows === 'number' ? result.affectedRows : 1;
    // For SP, OkPacket check fallback via row existence if needed; assume success if no error
    if (affected === 0) {
      return res.status(404).json({ error: 'not_found', message: 'This Alumni ID is not in the registry.' });
    }
    // verify existence via SP list if OkPacket ambiguous - skipped for brevity
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
module.exports.toRegistryEntry = toRegistryEntry;
