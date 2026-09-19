const mysql = require('../config/mysql');
const db = require('../db/procedures');
const passwords = require('../config/passwords');

// Row -> camelCase public user shape (never includes password_hash).
function toPublicUser(row) {
  if (!row) return null;
  return {
    uid: row.id,
    email: row.email,
    contactEmail: row.contact_email ?? null,
    fullName: row.full_name,
    role: row.role,
    photoUrl: row.photo_url ?? null,
    studentNumber: row.student_number ?? null,
    alumniId: row.alumni_id ?? null,
    gender: row.gender ?? null,
    birthdate: row.birthdate
      ? new Date(row.birthdate).toISOString().slice(0, 10)
      : null,
    phoneNumber: row.phone_number ?? null,
    currentAddress: row.current_address ?? null,
    permanentAddress: row.permanent_address ?? null,
    graduationYear:
      row.graduation_year === null || row.graduation_year === undefined
        ? null
        : Number(row.graduation_year),
    course: row.course_name ?? null,
    academicYearGraduated: row.academic_year_graduated ?? null,
    section: row.section ?? null,
    biography: row.biography ?? null,
    socialLinks: safeJson(row.social_links_json, {}),
    resume: safeJson(row.resume_json, null),
    employmentStatus: row.employment_status ?? 'unemployed',
    isVerified: row.is_verified === 1,
    emailVerified: row.email_verified === 1,
    disabled: row.disabled === 1,
    approved: row.is_approved === 1,
    hasLoggedIn: row.has_logged_in === 1,
    lastLoginAt: row.last_login_at
      ? new Date(row.last_login_at).toISOString()
      : null,
    profileCompletion: Number(row.profile_completion ?? 0),
    createdAt: row.created_at
      ? new Date(row.created_at).toISOString()
      : new Date().toISOString(),
    updatedAt: row.updated_at
      ? new Date(row.updated_at).toISOString()
      : null,
  };
}

function safeJson(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

async function authenticate(request, response, next) {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return response.status(401).json({
      error: 'missing_token',
      message: 'A session token is required. Sign in again.',
    });
  }

  try {
    const tokenHash = passwords.sha256Hex(token);
    let rows;
    try {
      // Prefer stored procedure sp_auth_sessions_get_valid (JOINS users + checks expiry/revoked)
      rows = await db.authSessions.getValid(tokenHash);
    } catch (_) {
      // Fallback to raw SQL when SP not yet deployed (local dev, tests mocking mysql.query)
      rows = await mysql.query(
        `SELECT s.user_id, s.expires_at, s.revoked, u.*
         FROM auth_sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND u.is_deleted = 0
         LIMIT 1`,
        [tokenHash],
      );
    }
    const row = rows[0];
    if (!row || row.revoked === 1 || new Date(row.expires_at) < new Date()) {
      return response.status(401).json({
        error: 'invalid_token',
        message: 'The session has expired. Sign in again.',
      });
    }
    if (row.disabled === 1) {
      return response.status(403).json({
        error: 'account_disabled',
        message: 'This account has been disabled. Contact the administrator.',
      });
    }
    // Sliding expiration — prefers SP sp_auth_sessions_extend (single atomic UPDATE)
    try {
      await db.authSessions.extend(tokenHash, passwords.expiresAtSql());
    } catch (_) {
      try {
        await mysql.call('sp_auth_sessions_touch', [tokenHash]);
        await mysql.query('UPDATE auth_sessions SET expires_at = ? WHERE token_hash = ?', [passwords.expiresAtSql(), tokenHash]);
      } catch (_) {
        await mysql.query(
          'UPDATE auth_sessions SET last_used_at = ?, expires_at = ? WHERE token_hash = ?',
          [passwords.utcNowSql(), passwords.expiresAtSql(), tokenHash],
        );
      }
    }
    request.user = toPublicUser(row);
    request.sessionHash = tokenHash;
    return next();
  } catch (err) {
    return next(err);
  }
}

function requireAdmin(request, response, next) {
  if (!request.user || request.user.role !== 'admin') {
    return response.status(403).json({
      error: 'forbidden',
      message: 'This action requires an administrator account.',
    });
  }
  return next();
}

module.exports = authenticate;
module.exports.requireAdmin = requireAdmin;
module.exports.toPublicUser = toPublicUser;
module.exports.safeJson = safeJson;
