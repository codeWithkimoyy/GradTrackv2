const express = require('express');
const authenticate = require('../middleware/authenticate');

const { toPublicUser } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

// Fields an alumni may edit on their own profile (mirrors the legacy
// client-side editable set; role/disabled/approved stay admin-only).
const editableFields = new Set([
  'fullName',
  'photoUrl',
  'studentNumber',
  'gender',
  'birthdate',
  'phoneNumber',
  'currentAddress',
  'permanentAddress',
  'graduationYear',
  'course',
  'section',
  'biography',
  'socialLinks',
  'employmentStatus',
  'academicYearGraduated',
]);

const columnFor = {
  fullName: 'full_name',
  photoUrl: 'photo_url',
  studentNumber: 'student_number',
  gender: 'gender',
  birthdate: 'birthdate',
  phoneNumber: 'phone_number',
  currentAddress: 'current_address',
  permanentAddress: 'permanent_address',
  graduationYear: 'graduation_year',
  course: 'course_name',
  section: 'section',
  biography: 'biography',
  socialLinks: 'social_links_json',
  employmentStatus: 'employment_status',
  academicYearGraduated: 'academic_year_graduated',
};

function toColumnValue(key, value) {
  if (value === null || value === undefined) return null;
  if (key === 'graduationYear') {
    const n = Number(value);
    return Number.isFinite(n) ? Math.trunc(n) : null;
  }
  if (key === 'socialLinks') {
    if (typeof value === 'string') return value;
    return JSON.stringify(value ?? {});
  }
  if (key === 'birthdate') {
    if (typeof value !== 'string' || !value) return null;
    return value.slice(0, 10);
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed === '' ? null : trimmed;
  }
  return value;
}

router.use(authenticate);

router.get('/', async (request, response, next) => {
  try {
    const rows = await mysql.query('SELECT * FROM users WHERE id = ? LIMIT 1', [
      request.user.uid,
    ]);
    if (rows.length === 0) {
      return response.status(404).json({
        error: 'profile_not_found',
        message: 'No GradTrack profile exists for this account.',
      });
    }
    return response.json(toPublicUser(rows[0]));
  } catch (error) {
    return next(error);
  }
});

router.patch('/', async (request, response, next) => {
  try {
    const changes = Object.fromEntries(
      Object.entries(request.body ?? {}).filter(([key]) =>
        editableFields.has(key),
      ),
    );

    if (Object.keys(changes).length === 0) {
      return response.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable profile fields.',
      });
    }

    const sets = [];
    const params = [];
    for (const [key, value] of Object.entries(changes)) {
      sets.push(`\`${columnFor[key]}\` = ?`);
      params.push(toColumnValue(key, value));
    }
    if (changes.fullName === undefined && changes.course === undefined) {
      // Recompute a rough completion score server-side when core fields move.
      const rows = await mysql.query(
        'SELECT * FROM users WHERE id = ? LIMIT 1',
        [request.user.uid],
      );
      if (rows[0]) {
        const merged = { ...toPublicUser(rows[0]), ...changes };
        const fields = [
          merged.photoUrl,
          merged.studentNumber,
          merged.gender,
          merged.birthdate,
          merged.phoneNumber,
          merged.currentAddress,
          merged.permanentAddress,
          merged.graduationYear,
          merged.course,
          merged.academicYearGraduated,
          merged.biography,
          merged.socialLinks && merged.socialLinks.linkedIn,
        ];
        const filled = fields.filter(
          (f) => f !== null && f !== undefined && f !== '',
        ).length;
        sets.push('`profile_completion` = ?');
        params.push((filled / fields.length) * 100);
      }
    }
    params.push(request.user.uid);
    await mysql.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = ?`,
      params,
    );
    const rows = await mysql.query('SELECT * FROM users WHERE id = ? LIMIT 1', [
      request.user.uid,
    ]);
    return response.json({ updated: true, user: toPublicUser(rows[0]) });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
module.exports.columnFor = columnFor;
module.exports.toColumnValue = toColumnValue;
