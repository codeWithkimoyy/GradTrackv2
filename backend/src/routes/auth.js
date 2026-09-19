const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin, toPublicUser } = authenticate;
const env = require('../config/env');
const mysql = require('../config/mysql');
const passwords = require('../config/passwords');
const { hasSmtpCredentials, sendCodeEmail } = require('../config/email');

const router = express.Router();

// Must match AppStrings.alumniEmailSuffix in the Flutter app.
const ALUMNI_EMAIL_SUFFIX = '@gradtrack.bisu.edu.ph';
const ALUMNI_ID_PATTERN = /^[A-Za-z0-9_-]+$/;
const CODE_TTL_MS = 10 * 60 * 1000;

function generateCode() {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function alumniEmailFromId(alumniId) {
  return `${alumniId}${ALUMNI_EMAIL_SUFFIX}`;
}

function alumniIdFromEmail(email) {
  const lower = String(email).toLowerCase();
  if (!lower.endsWith(ALUMNI_EMAIL_SUFFIX)) return null;
  const local = email.slice(0, email.length - ALUMNI_EMAIL_SUFFIX.length);
  return local || null;
}

async function fetchUserById(id) {
  const rows = await mysql.query(
    'SELECT * FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}

async function createSession(userId) {
  const token = passwords.newSessionToken();
  await mysql.query(
    'INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
    [
      crypto.randomUUID(),
      userId,
      passwords.sha256Hex(token),
      passwords.expiresAtSql(),
    ],
  );
  return token;
}

async function touchLogin(user) {
  const updates = ['has_logged_in = 1', 'last_login_at = ?'];
  const params = [passwords.utcNowSql()];
  // Backfill the graduation batch from the alumni registry when the profile
  // never stored it (mirrors the legacy client bootstrap behaviour).
  if (user.alumni_id) {
    const regs = await mysql.query(
      'SELECT academic_year_graduated, graduation_year FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [user.alumni_id],
    );
    const reg = regs[0];
    if (reg) {
      if (!user.academic_year_graduated && reg.academic_year_graduated) {
        updates.push('academic_year_graduated = ?');
        params.push(reg.academic_year_graduated);
      }
      if (user.graduation_year == null && reg.graduation_year != null) {
        updates.push('graduation_year = ?');
        params.push(reg.graduation_year);
      }
    }
  }
  params.push(user.id);
  await mysql.query(
    `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
    params,
  );
  return fetchUserById(user.id);
}

// ---------------------------------------------------------------------------
// POST /api/auth/register
// Alumni-ID flow (registry gated) when `alumniId` is present, otherwise a
// generic email registration. Returns a session token + public user.
// ---------------------------------------------------------------------------
router.post('/register', async (request, response, next) => {
  try {
    const body = request.body ?? {};
    const alumniId =
      typeof body.alumniId === 'string' ? body.alumniId.trim() : '';
    const email =
      typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const fullName =
      typeof body.fullName === 'string' ? body.fullName.trim() : '';
    const graduationYear =
      body.graduationYear === null || body.graduationYear === undefined
        ? null
        : Number(body.graduationYear);
    const course =
      typeof body.course === 'string' && body.course.trim()
        ? body.course.trim()
        : 'BS Computer Science';

    if (password.length < 6) {
      return response.status(400).json({
        error: 'weak_password',
        message: 'The password must be at least 6 characters.',
      });
    }

    if (alumniId) {
      if (!ALUMNI_ID_PATTERN.test(alumniId)) {
        return response.status(400).json({
          error: 'invalid_alumni_id',
          message:
            'Alumni ID may only contain letters, numbers, hyphens and underscores.',
        });
      }
      // Alumni supply their own identity at registration: the office
      // pre-registers bare IDs, and the name appears once they sign up.
      const regFullName = fullName;
      const contactEmail =
        typeof body.contactEmail === 'string'
          ? body.contactEmail.trim().toLowerCase()
          : '';
      const phoneNumber =
        typeof body.phoneNumber === 'string' ? body.phoneNumber.trim() : '';
      const birthdate =
        typeof body.birthdate === 'string' ? body.birthdate.trim() : '';
      if (!regFullName) {
        return response.status(400).json({
          error: 'missing_name',
          message: 'Your full name is required (format: Lastname, Firstname).',
        });
      }
      if (!contactEmail && !phoneNumber) {
        return response.status(400).json({
          error: 'contact_required',
          message: 'Provide an email address or a phone number.',
        });
      }
      if (contactEmail && !isValidEmail(contactEmail)) {
        return response.status(400).json({
          error: 'invalid_contact_email',
          message: 'That email address does not look valid.',
        });
      }
      if (phoneNumber && !/^[+\d][\d\s\-()]{5,19}$/.test(phoneNumber)) {
        return response.status(400).json({
          error: 'invalid_phone',
          message: 'That phone number does not look valid.',
        });
      }
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(birthdate) ||
        Number.isNaN(Date.parse(`${birthdate}T00:00:00Z`)) ||
        new Date(`${birthdate}T00:00:00Z`) > new Date()
      ) {
        return response.status(400).json({
          error: 'invalid_birthdate',
          message:
            'Enter a valid date of birth (YYYY-MM-DD) that is not in the future.',
        });
      }
      const regs = await mysql.query(
        'SELECT * FROM alumni_registry WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [alumniId],
      );
      const entry = regs[0];
      if (!entry) {
        return response.status(404).json({
          error: 'alumni_id_not_found',
          message:
            'Alumni ID not found. Please contact the Tracer Study Administrator.',
        });
      }
      if (entry.status === 'active') {
        return response.status(409).json({
          error: 'already_registered',
          message: 'This Alumni ID is already registered. Please sign in.',
        });
      }
      if (entry.status === 'disabled') {
        return response.status(403).json({
          error: 'alumni_id_disabled',
          message:
            'This Alumni ID has been disabled. Please contact the Tracer Study Administrator.',
        });
      }

      const loginEmail = alumniEmailFromId(alumniId).toLowerCase();
      const existing = await mysql.query(
        'SELECT id, is_deleted FROM users WHERE email = ? OR alumni_id = ? LIMIT 1',
        [loginEmail, alumniId],
      );
      if (existing.length > 0 && existing[0].is_deleted !== 1) {
        return response.status(409).json({
          error: 'already_registered',
          message: 'This Alumni ID is already registered. Please sign in.',
        });
      }

      const passwordHash = await passwords.hashPassword(password);
      let id;
      if (existing.length > 0) {
        // A soft-deleted row holds the unique email: overwrite and restore it.
        id = existing[0].id;
        await mysql.query(
          `UPDATE users SET email = ?, password_hash = ?, full_name = ?,
             role = 'alumni', alumni_id = ?, course_name = ?,
             graduation_year = ?, academic_year_graduated = ?,
             phone_number = ?, contact_email = ?, birthdate = ?,
             is_approved = 1, email_verified = 1, disabled = 0,
             has_logged_in = 1, last_login_at = ?,
             is_deleted = 0, deleted_at = NULL
           WHERE id = ?`,
          [
            loginEmail,
            passwordHash,
            regFullName,
            alumniId,
            entry.course || course,
            entry.graduation_year ?? (Number.isFinite(graduationYear) ? graduationYear : null),
            entry.academic_year_graduated,
            phoneNumber || null,
            contactEmail || null,
            birthdate,
            passwords.utcNowSql(),
            id,
          ],
        );
      } else {
        id = crypto.randomUUID();
        await mysql.query(
          `INSERT INTO users
             (id, email, password_hash, full_name, role, alumni_id, course_name,
              graduation_year, academic_year_graduated, phone_number,
              contact_email, birthdate, is_approved, email_verified,
              has_logged_in, last_login_at)
           VALUES (?, ?, ?, ?, 'alumni', ?, ?, ?, ?, ?, ?, ?, 1, 1, 1, ?)`,
          [
            id,
            loginEmail,
            passwordHash,
            regFullName,
            alumniId,
            entry.course || course,
            entry.graduation_year ?? (Number.isFinite(graduationYear) ? graduationYear : null),
            entry.academic_year_graduated,
            phoneNumber || null,
            contactEmail || null,
            birthdate,
            passwords.utcNowSql(),
          ],
        );
      }
      // The registrant's name lands on the registry entry here, so the
      // office sees who each pre-registered ID belongs to after signup.
      await mysql.query(
        'UPDATE alumni_registry SET status = ?, activated_at = ?, full_name = ? WHERE id = ?',
        ['active', passwords.utcNowSql(), regFullName, alumniId],
      );
      const user = await fetchUserById(id);
      const token = await createSession(id);
      return response
        .status(201)
        .json({ token, user: toPublicUser(user) });
    }

    if (!isValidEmail(email)) {
      return response.status(400).json({
        error: 'invalid_email',
        message: 'A valid email address is required.',
      });
    }
    if (!fullName) {
      return response.status(400).json({
        error: 'missing_name',
        message: 'Full name is required.',
      });
    }
    const existing = await mysql.query(
      'SELECT id, is_deleted FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (existing.length > 0 && existing[0].is_deleted !== 1) {
      return response.status(409).json({
        error: 'email_in_use',
        message: 'An account already exists for this email.',
      });
    }

    const passwordHash = await passwords.hashPassword(password);
    let id;
    if (existing.length > 0) {
      id = existing[0].id;
      await mysql.query(
        `UPDATE users SET password_hash = ?, full_name = ?, role = 'alumni',
           graduation_year = ?, course_name = ?, alumni_id = ?,
           is_approved = 1, email_verified = 1, disabled = 0,
           has_logged_in = 1, last_login_at = ?,
           is_deleted = 0, deleted_at = NULL
         WHERE id = ?`,
        [
          passwordHash,
          fullName,
          Number.isFinite(graduationYear) ? graduationYear : null,
          course,
          alumniIdFromEmail(email),
          passwords.utcNowSql(),
          id,
        ],
      );
    } else {
      id = crypto.randomUUID();
      await mysql.query(
        `INSERT INTO users
           (id, email, password_hash, full_name, role, graduation_year,
            course_name, alumni_id, is_approved, email_verified,
            has_logged_in, last_login_at)
         VALUES (?, ?, ?, ?, 'alumni', ?, ?, ?, 1, 1, 1, ?)`,
        [
          id,
          email,
          passwordHash,
          fullName,
          Number.isFinite(graduationYear) ? graduationYear : null,
          course,
          alumniIdFromEmail(email),
          passwords.utcNowSql(),
        ],
      );
    }
    const user = await fetchUserById(id);
    const token = await createSession(id);
    return response.status(201).json({ token, user: toPublicUser(user) });
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// POST /api/auth/login  { identifier, password } -> { token, user }
// identifier is an email address or an Alumni ID.
// ---------------------------------------------------------------------------
router.post('/login', async (request, response, next) => {
  try {
    const body = request.body ?? {};
    const identifier =
      typeof body.identifier === 'string' ? body.identifier.trim() : '';
    const password = typeof body.password === 'string' ? body.password : '';

    if (!identifier || !password) {
      return response.status(400).json({
        error: 'missing_credentials',
        message: 'Email/Alumni ID and password are required.',
      });
    }

    let rows;
    if (identifier.includes('@')) {
      rows = await mysql.query(
        'SELECT * FROM users WHERE email = ? AND is_deleted = 0 LIMIT 1',
        [identifier.toLowerCase()],
      );
    } else {
      rows = await mysql.query(
        'SELECT * FROM users WHERE alumni_id = ? AND is_deleted = 0 LIMIT 1',
        [identifier],
      );
    }
    const user = rows[0];
    if (!user) {
      return response.status(401).json({
        error: 'invalid_credentials',
        message: 'Invalid email or password.',
      });
    }
    if (!(await passwords.verifyPassword(password, user.password_hash))) {
      return response.status(401).json({
        error: 'invalid_credentials',
        message: 'Invalid email or password.',
      });
    }
    if (user.disabled === 1) {
      return response.status(403).json({
        error: 'account_disabled',
        message:
          'This account has been disabled. Please contact the Tracer Study Administrator.',
      });
    }

    const refreshed = await touchLogin(user);
    const token = await createSession(user.id);
    return response.json({ token, user: toPublicUser(refreshed) });
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// POST /api/auth/google  { idToken } -> { token, user }
// Google Sign-In with the MySQL database: the Google ID token is verified
// against Google's tokeninfo endpoint, then the account is looked up by
// verified email (or created as an alumni profile on first sign-in).
// ---------------------------------------------------------------------------
router.post('/google', async (request, response, next) => {
  try {
    const idToken =
      typeof request.body?.idToken === 'string'
        ? request.body.idToken.trim()
        : '';
    if (!idToken) {
      return response.status(400).json({
        error: 'missing_token',
        message: 'A Google ID token is required.',
      });
    }
    if (!env.google.clientId) {
      return response.status(503).json({
        error: 'google_not_configured',
        message:
          'Google Sign-In is not configured on the server (GOOGLE_SIGN_IN_CLIENT_ID).',
      });
    }

    let info;
    try {
      const verify = await fetch(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
      );
      if (!verify.ok) {
        return response.status(401).json({
          error: 'invalid_token',
          message: 'Google sign-in failed. Please try again.',
        });
      }
      info = await verify.json();
    } catch (_) {
      return response.status(502).json({
        error: 'google_unreachable',
        message: 'Could not reach Google to verify the sign-in. Try again.',
      });
    }

    if (info.aud !== env.google.clientId) {
      return response.status(401).json({
        error: 'invalid_token',
        message: 'Google sign-in failed. Please try again.',
      });
    }
    const email = String(info.email ?? '').trim().toLowerCase();
    if (!isValidEmail(email) || info.email_verified !== 'true') {
      return response.status(401).json({
        error: 'email_not_verified',
        message: 'Your Google account email is not verified.',
      });
    }

    let rows = await mysql.query(
      'SELECT * FROM users WHERE email = ? AND is_deleted = 0 LIMIT 1',
      [email],
    );
    let user = rows[0];
    if (!user) {
      const id = crypto.randomUUID();
      const displayName =
        String(info.name ?? '').trim() || email.split('@')[0];
      await mysql.query(
        `INSERT INTO users
           (id, email, full_name, role, photo_url, alumni_id,
            is_approved, email_verified, has_logged_in, last_login_at)
         VALUES (?, ?, ?, 'alumni', ?, ?, 1, 1, 1, ?)`,
        [
          id,
          email,
          displayName,
          info.picture ? String(info.picture) : null,
          alumniIdFromEmail(email),
          passwords.utcNowSql(),
        ],
      );
      rows = await mysql.query(
        'SELECT * FROM users WHERE id = ? LIMIT 1',
        [id],
      );
      user = rows[0];
    }
    if (user.disabled === 1) {
      return response.status(403).json({
        error: 'account_disabled',
        message:
          'This account has been disabled. Please contact the Tracer Study Administrator.',
      });
    }

    const refreshed = await touchLogin(user);
    const token = await createSession(user.id);
    return response.json({ token, user: toPublicUser(refreshed) });
  } catch (err) {
    return next(err);
  }
});

router.post('/logout', authenticate, async (request, response, next) => {
  try {
    await mysql.query(
      'UPDATE auth_sessions SET revoked = 1 WHERE token_hash = ?',
      [request.sessionHash],
    );
    return response.json({ message: 'signed_out' });
  } catch (err) {
    return next(err);
  }
});

router.get('/me', authenticate, (request, response) => {
  return response.json({ user: request.user });
});

// ---------------------------------------------------------------------------
// POST /api/auth/change-password  { currentPassword, newPassword }
// ---------------------------------------------------------------------------
router.post('/change-password', authenticate, async (request, response, next) => {
  try {
    const body = request.body ?? {};
    const currentPassword =
      typeof body.currentPassword === 'string' ? body.currentPassword : '';
    const newPassword =
      typeof body.newPassword === 'string' ? body.newPassword : '';
    if (newPassword.length < 6) {
      return response.status(400).json({
        error: 'weak_password',
        message: 'The new password must be at least 6 characters.',
      });
    }
    const rows = await mysql.query(
      'SELECT password_hash FROM users WHERE id = ? LIMIT 1',
      [request.user.uid],
    );
    if (
      !rows[0] ||
      !(await passwords.verifyPassword(currentPassword, rows[0].password_hash))
    ) {
      return response.status(401).json({
        error: 'wrong_password',
        message: 'The current password is incorrect.',
      });
    }
    await mysql.query('UPDATE users SET password_hash = ? WHERE id = ?', [
      await passwords.hashPassword(newPassword),
      request.user.uid,
    ]);
    // Revoke every other session; keep the current one alive.
    await mysql.query(
      'UPDATE auth_sessions SET revoked = 1 WHERE user_id = ? AND token_hash <> ?',
      [request.user.uid, request.sessionHash],
    );
    return response.json({ message: 'password_updated' });
  } catch (err) {
    return next(err);
  }
});

// ---------------------------------------------------------------------------
// Password-reset code flow (MySQL password_resets + SMTP email).
// ---------------------------------------------------------------------------
function resetConfigured(response) {
  if (!hasSmtpCredentials) {
    response.status(503).json({
      error: 'email_not_configured',
      message: 'SMTP email credentials are not configured on the server.',
    });
    return false;
  }
  return true;
}

router.post('/forgot-password', async (request, response, next) => {
  try {
    const email =
      typeof request.body?.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';

    if (!isValidEmail(email)) {
      return response.status(400).json({
        error: 'invalid_email',
        message: 'A valid email address is required.',
      });
    }

    if (!resetConfigured(response)) return;

    const users = await mysql.query(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (users.length === 0) {
      return response.status(404).json({
        error: 'no_account',
        message: 'No GradTrack account exists for this email.',
      });
    }

    const code = generateCode();
    const expiresAt = new Date(Date.now() + CODE_TTL_MS)
      .toISOString()
      .slice(0, 19)
      .replace('T', ' ');
    await mysql.query(
      'INSERT INTO password_resets (email, user_id, code, expires_at) VALUES (?, ?, ?, ?)',
      [email, users[0].id, code, expiresAt],
    );

    await sendCodeEmail({ to: email, code });

    return response.json({ message: 'code_sent' });
  } catch (error) {
    if (error.code === 'smtp_not_configured') {
      return response.status(503).json({
        error: 'email_not_configured',
        message: 'SMTP email credentials are not configured on the server.',
      });
    }
    return next(error);
  }
});

async function latestReset(email) {
  const rows = await mysql.query(
    'SELECT * FROM password_resets WHERE email = ? ORDER BY id DESC LIMIT 1',
    [email],
  );
  return rows[0] ?? null;
}

function resetRecordProblem(record, code) {
  if (!record) return ['no_code', 404, 'No reset request was found for this email. Request a new code.'];
  if (record.used === 1) return ['code_used', 400, 'This code has already been used. Request a new code.'];
  if (new Date(record.expires_at) < new Date()) return ['code_expired', 400, 'This code has expired. Request a new code.'];
  if (record.code !== code) return ['invalid_code', 400, 'That code is incorrect. Please check and try again.'];
  return null;
}

router.post('/verify-code', async (request, response, next) => {
  try {
    const email =
      typeof request.body?.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';
    const code =
      typeof request.body?.code === 'string' ? request.body.code.trim() : '';

    if (!email || !/^\d{6}$/.test(code)) {
      return response.status(400).json({
        error: 'invalid_code',
        message: 'Enter the 6-digit code we emailed you.',
      });
    }

    if (!resetConfigured(response)) return;

    const problem = resetRecordProblem(await latestReset(email), code);
    if (problem) {
      const [error, status, message] = problem;
      return response.status(status).json({ error, message });
    }

    return response.json({ message: 'code_valid' });
  } catch (error) {
    return next(error);
  }
});

router.post('/reset-password', async (request, response, next) => {
  try {
    const email =
      typeof request.body?.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';
    const code =
      typeof request.body?.code === 'string' ? request.body.code.trim() : '';
    const newPassword =
      typeof request.body?.newPassword === 'string'
        ? request.body.newPassword
        : '';

    if (!email || !/^\d{6}$/.test(code)) {
      return response.status(400).json({
        error: 'invalid_code',
        message: 'Enter the 6-digit code we emailed you.',
      });
    }
    if (newPassword.length < 6) {
      return response.status(400).json({
        error: 'weak_password',
        message: 'The new password must be at least 6 characters.',
      });
    }

    if (!resetConfigured(response)) return;

    const record = await latestReset(email);
    const problem = resetRecordProblem(record, code);
    if (problem) {
      const [error, status, message] = problem;
      return response.status(status).json({ error, message });
    }

    await mysql.query('UPDATE users SET password_hash = ? WHERE id = ?', [
      await passwords.hashPassword(newPassword),
      record.user_id,
    ]);
    await mysql.query(
      'UPDATE password_resets SET used = 1, used_at = ? WHERE id = ?',
      [passwords.utcNowSql(), record.id],
    );

    return response.json({ message: 'password_updated' });
  } catch (error) {
    return next(error);
  }
});

// ---------------------------------------------------------------------------
// Admin user management (replaces Identity Toolkit REST + Cloud Function).
// ---------------------------------------------------------------------------
router.post('/admin/users', authenticate, requireAdmin, async (request, response, next) => {
  try {
    const body = request.body ?? {};
    const email =
      typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const fullName =
      typeof body.fullName === 'string' ? body.fullName.trim() : '';
    const role = body.role === 'admin' ? 'admin' : 'alumni';

    if (!isValidEmail(email)) {
      return response.status(400).json({
        error: 'invalid_email',
        message: 'A valid email address is required.',
      });
    }
    if (password.length < 6) {
      return response.status(400).json({
        error: 'weak_password',
        message: 'The password must be at least 6 characters.',
      });
    }
    if (!fullName) {
      return response.status(400).json({
        error: 'missing_name',
        message: 'Full name is required.',
      });
    }

    const existing = await mysql.query(
      'SELECT id, is_deleted FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (existing.length > 0 && existing[0].is_deleted !== 1) {
      return response.status(409).json({
        error: 'email_in_use',
        message: 'An account already exists for this email.',
      });
    }

    const passwordHash = await passwords.hashPassword(password);
    let id;
    if (existing.length > 0) {
      id = existing[0].id;
      await mysql.query(
        `UPDATE users SET password_hash = ?, full_name = ?, role = ?,
           graduation_year = ?, course_name = ?, is_approved = 1,
           email_verified = 1, disabled = 0, is_deleted = 0, deleted_at = NULL
         WHERE id = ?`,
        [
          passwordHash,
          fullName,
          role,
          body.graduationYear === undefined || body.graduationYear === null
            ? null
            : Number(body.graduationYear),
          typeof body.course === 'string' && body.course.trim()
            ? body.course.trim()
            : null,
          id,
        ],
      );
    } else {
      id = crypto.randomUUID();
      await mysql.query(
        `INSERT INTO users
           (id, email, password_hash, full_name, role, graduation_year,
            course_name, is_approved, email_verified)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)`,
        [
          id,
          email,
          passwordHash,
          fullName,
          role,
          body.graduationYear === undefined || body.graduationYear === null
            ? null
            : Number(body.graduationYear),
          typeof body.course === 'string' && body.course.trim()
            ? body.course.trim()
            : null,
        ],
      );
    }
    return response.status(201).json({ user: toPublicUser(await fetchUserById(id)) });
  } catch (err) {
    return next(err);
  }
});

router.post(
  '/admin/users/:id/reset-password',
  authenticate,
  requireAdmin,
  async (request, response, next) => {
    try {
      const newPassword =
        typeof request.body?.newPassword === 'string'
          ? request.body.newPassword
          : '';
      if (newPassword.length < 6) {
        return response.status(400).json({
          error: 'weak_password',
          message: 'The new password must be at least 6 characters.',
        });
      }
      const user = await fetchUserById(request.params.id);
      if (!user) {
        return response.status(404).json({
          error: 'user_not_found',
          message: 'No user exists with that id.',
        });
      }
      await mysql.query('UPDATE users SET password_hash = ? WHERE id = ?', [
        await passwords.hashPassword(newPassword),
        request.params.id,
      ]);
      await mysql.query(
        'UPDATE auth_sessions SET revoked = 1 WHERE user_id = ?',
        [request.params.id],
      );
      return response.json({ message: 'password_updated' });
    } catch (err) {
      return next(err);
    }
  },
);

module.exports = router;
