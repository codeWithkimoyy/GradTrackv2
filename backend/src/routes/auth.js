const crypto = require('node:crypto');
const express = require('express');
const { auth, db, hasFirebaseCredentials } = require('../config/firebase');
const { hasSmtpCredentials, sendCodeEmail } = require('../config/email');

const router = express.Router();

const CODE_TTL_MS = 10 * 60 * 1000;

function generateCode() {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function isConfigured(response) {
  if (!hasFirebaseCredentials || auth == null || db == null) {
    response.status(503).json({
      error: 'firebase_not_configured',
      message: 'Firebase Admin credentials are not configured on the server.',
    });
    return false;
  }
  if (!hasSmtpCredentials) {
    response.status(503).json({
      error: 'email_not_configured',
      message: 'SMTP email credentials are not configured on the server.',
    });
    return false;
  }
  return true;
}

async function resetRecord(email) {
  return db.collection('password_resets').doc(email.toLowerCase().trim());
}

router.post('/forgot-password', async (request, response, next) => {
  try {
    const email = typeof request.body?.email === 'string'
      ? request.body.email.trim().toLowerCase()
      : '';

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return response.status(400).json({
        error: 'invalid_email',
        message: 'A valid email address is required.',
      });
    }

    if (!isConfigured(response)) return;

    let uid;
    try {
      const userRecord = await auth.getUserByEmail(email);
      uid = userRecord.uid;
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        return response.status(404).json({
          error: 'no_account',
          message: 'No GradTrack account exists for this email.',
        });
      }
      throw error;
    }

    const code = generateCode();
    const now = new Date();
    await resetRecord(email).set({
      uid,
      email,
      code,
      expiresAt: new Date(now.getTime() + CODE_TTL_MS),
      used: false,
      createdAt: now,
    });

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

router.post('/verify-code', async (request, response, next) => {
  try {
    const email = typeof request.body?.email === 'string'
      ? request.body.email.trim().toLowerCase()
      : '';
    const code = typeof request.body?.code === 'string'
      ? request.body.code.trim()
      : '';

    if (!email || !/^\d{6}$/.test(code)) {
      return response.status(400).json({
        error: 'invalid_code',
        message: 'Enter the 6-digit code we emailed you.',
      });
    }

    if (!isConfigured(response)) return;

    const record = await resetRecord(email).get();
    if (!record.exists) {
      return response.status(404).json({
        error: 'no_code',
        message: 'No reset request was found for this email. Request a new code.',
      });
    }

    const data = record.data();
    if (data.used) {
      return response.status(400).json({
        error: 'code_used',
        message: 'This code has already been used. Request a new code.',
      });
    }
    if (new Date(data.expiresAt.toDate?.() ?? data.expiresAt) < new Date()) {
      return response.status(400).json({
        error: 'code_expired',
        message: 'This code has expired. Request a new code.',
      });
    }
    if (data.code !== code) {
      return response.status(400).json({
        error: 'invalid_code',
        message: 'That code is incorrect. Please check and try again.',
      });
    }

    return response.json({ message: 'code_valid' });
  } catch (error) {
    return next(error);
  }
});

router.post('/reset-password', async (request, response, next) => {
  try {
    const email = typeof request.body?.email === 'string'
      ? request.body.email.trim().toLowerCase()
      : '';
    const code = typeof request.body?.code === 'string'
      ? request.body.code.trim()
      : '';
    const newPassword = typeof request.body?.newPassword === 'string'
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

    if (!isConfigured(response)) return;

    const record = await resetRecord(email).get();
    if (!record.exists) {
      return response.status(404).json({
        error: 'no_code',
        message: 'No reset request was found for this email. Request a new code.',
      });
    }

    const data = record.data();
    if (data.used) {
      return response.status(400).json({
        error: 'code_used',
        message: 'This code has already been used. Request a new code.',
      });
    }
    if (new Date(data.expiresAt.toDate?.() ?? data.expiresAt) < new Date()) {
      return response.status(400).json({
        error: 'code_expired',
        message: 'This code has expired. Request a new code.',
      });
    }
    if (data.code !== code) {
      return response.status(400).json({
        error: 'invalid_code',
        message: 'That code is incorrect. Please check and try again.',
      });
    }

    await auth.updateUser(data.uid, { password: newPassword });
    await record.update({ used: true, usedAt: new Date() });

    return response.json({ message: 'password_updated' });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;