const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');
const passwords = require('../config/passwords');
const cipher = require('../config/messageCipher');

const router = express.Router();

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function toConversation(row) {
  return {
    id: row.id,
    alumniId: row.alumni_id ?? '',
    alumniName: row.alumni_name ?? 'Alumni',
    alumniEmail: row.alumni_email ?? '',
    alumniCourse: row.alumni_course ?? null,
    participantIds:
      row.participant_ids_json == null
        ? []
        : typeof row.participant_ids_json === 'object'
          ? row.participant_ids_json
          : JSON.parse(row.participant_ids_json),
    lastMessage: cipher.decrypt(row.last_message ?? ''),
    lastMessageTime: iso(row.last_message_time) ?? new Date().toISOString(),
    lastSenderId: row.last_sender_id ?? '',
    unreadCountForAdmin: Number(row.unread_admin ?? 0),
    unreadCountForAlumni: Number(row.unread_alumni ?? 0),
    createdAt: iso(row.created_at) ?? new Date().toISOString(),
  };
}

function toMessage(row) {
  return {
    id: row.id,
    conversationId: row.conversation_id ?? '',
    senderId: row.sender_id ?? '',
    senderName: row.sender_name ?? 'User',
    senderRole: row.sender_role ?? 'alumni',
<<<<<<< HEAD
    text: row.text ?? '',
    imageUrl: row.image_url ?? null,
=======
    text: cipher.decrypt(row.text ?? ''),
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
    timestamp: iso(row.created_at) ?? new Date().toISOString(),
    isRead: row.is_read === 1,
  };
}

router.use(authenticate);

// Canonical thread for an alumni account. Alumni may only ever touch this
// single id, so one conversation can never leak into another account.
function ownConversationId(user) {
  return `conv_${user.alumniId ?? user.uid}`;
}

function isOwnConversation(user, conversationId) {
  if (user.role === 'admin') return true;
  return conversationId === ownConversationId(user);
}

// GET /api/conversations (admin: all; alumni: own thread or empty)
router.get('/', async (req, res, next) => {
  try {
    if (req.user.role === 'admin') {
      const rows = await mysql.query(
        'SELECT * FROM conversations WHERE is_deleted = 0 ORDER BY last_message_time DESC, updated_at DESC LIMIT 200',
      );
      return res.json(rows.map(toConversation));
    }
    const rows = await mysql.query(
      'SELECT * FROM conversations WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [ownConversationId(req.user)],
    );
    return res.json(rows.map(toConversation));
  } catch (err) {
    return next(err);
  }
});

// A participant may only ever touch their own thread (conv_<alumniId>).
// Admins may access every thread.
function canAccessConversation(user, conversationId) {
  if (!user) return false;
  if (user.role === 'admin') return true;
  const alumniId = user.alumniId;
  return Boolean(alumniId) && conversationId === `conv_${alumniId}`;
}

// GET /api/conversations/:id
router.get('/:id', async (req, res, next) => {
  try {
<<<<<<< HEAD
    if (!isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You can only read your own conversation.',
=======
    if (!canAccessConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
      });
    }
    const rows = await mysql.query(
      'SELECT * FROM conversations WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [req.params.id],
    );
    if (rows.length === 0) return res.json(null);
    return res.json(toConversation(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// GET /api/conversations/:id/messages
router.get('/:id/messages', async (req, res, next) => {
  try {
<<<<<<< HEAD
    if (!isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You can only read your own conversation.',
=======
    if (!canAccessConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
      });
    }
    const rows = await mysql.query(
      'SELECT * FROM messages WHERE conversation_id = ? AND is_deleted = 0 ORDER BY created_at ASC LIMIT 500',
      [req.params.id],
    );
    return res.json(rows.map(toMessage));
  } catch (err) {
    return next(err);
  }
});

// POST /api/conversations/:id/messages
// Alumni post to their own thread; admins post to any thread.
router.post('/:id/messages', async (req, res, next) => {
  try {
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const imageUrl =
      typeof req.body?.imageUrl === 'string' ? req.body.imageUrl.trim() : '';
    if (!text && !imageUrl) {
      return res.status(400).json({
        error: 'empty_message',
        message: 'Message text or an image is required.',
      });
    }
    if (imageUrl && imageUrl.length > 60000) {
      return res.status(400).json({
        error: 'image_too_large',
        message: 'The attached image reference is too large.',
      });
    }
    const isAdmin = req.user.role === 'admin';
    const conversationId = req.params.id;

    let alumniId;
    let alumniName;
    let alumniEmail;
    let alumniCourse = null;
    if (isAdmin) {
      alumniId =
        typeof req.body?.alumniId === 'string' && req.body.alumniId
          ? req.body.alumniId
          : conversationId.replace(/^conv_/, '');
      alumniName =
        typeof req.body?.alumniName === 'string' && req.body.alumniName
          ? req.body.alumniName
          : 'Alumni';
      alumniEmail =
        typeof req.body?.alumniEmail === 'string' ? req.body.alumniEmail : '';
      alumniCourse =
        typeof req.body?.alumniCourse === 'string' && req.body.alumniCourse
          ? req.body.alumniCourse
          : null;
    } else {
      alumniId = req.user.alumniId ?? req.user.uid;
      alumniName = req.user.fullName;
      alumniEmail = req.user.email;
      alumniCourse = req.user.course;
      if (conversationId !== `conv_${alumniId}`) {
        return res.status(403).json({
          error: 'forbidden',
          message: 'You can only write to your own conversation.',
        });
      }
    }

    const participantIds = isAdmin
      ? [alumniId, 'admin', req.user.uid]
      : [alumniId, 'admin'];

    const now = passwords.utcNowSql();
    const encryptedText = cipher.encrypt(text);
    // Upsert the conversation header FIRST: messages carry a foreign key
    // to it, so the header must exist before the message row is written.
    await mysql.query(
      `INSERT INTO conversations
         (id, alumni_id, alumni_name, alumni_email, alumni_course,
          participant_ids_json, last_message, last_message_time,
          last_sender_id, unread_admin, unread_alumni)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         alumni_name = VALUES(alumni_name),
         alumni_email = VALUES(alumni_email),
         alumni_course = VALUES(alumni_course),
         participant_ids_json = VALUES(participant_ids_json),
         last_message = VALUES(last_message),
         last_message_time = VALUES(last_message_time),
         last_sender_id = VALUES(last_sender_id),
         unread_admin = unread_admin + VALUES(unread_admin),
         unread_alumni = unread_alumni + VALUES(unread_alumni),
         is_deleted = 0,
         deleted_at = NULL`,
      [
        conversationId,
        alumniId,
        alumniName,
        alumniEmail,
        alumniCourse,
        JSON.stringify(participantIds),
<<<<<<< HEAD
        previewText,
=======
        encryptedText,
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
        now,
        req.user.uid,
        isAdmin ? 0 : 1,
        isAdmin ? 1 : 0,
      ],
    );
    if (isAdmin) {
      await mysql.query(
        'UPDATE conversations SET unread_admin = 0 WHERE id = ?',
        [conversationId],
      );
    } else {
      await mysql.query(
        'UPDATE conversations SET unread_alumni = 0 WHERE id = ?',
        [conversationId],
      );
    }

    const messageId = crypto.randomUUID();
    const previewText = text || (imageUrl ? '📷 Photo' : '');
    await mysql.query(
      `INSERT INTO messages
         (id, conversation_id, sender_id, sender_name, sender_role,
          recipient_id, user_id, participant_ids_json, text, image_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        messageId,
        conversationId,
        req.user.uid,
        req.user.fullName,
        req.user.role,
        isAdmin ? alumniId : 'admin',
        req.user.uid,
        JSON.stringify(participantIds),
<<<<<<< HEAD
        previewText,
        imageUrl || null,
=======
        encryptedText,
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
      ],
    );

    // Best-effort bell alert for the other party (never fails the send).
    try {
      if (isAdmin) {
        const targets = await mysql.query(
          'SELECT id FROM users WHERE alumni_id = ? AND is_deleted = 0 LIMIT 1',
          [alumniId],
        );
        if (targets[0]) {
          await mysql.query(
            `INSERT INTO notifications
               (id, user_id, recipient_role, type, title, description, priority, link)
<<<<<<< HEAD
             VALUES (?, ?, 'alumni', 'system', 'New message from the Alumni Office', ?, 'medium', '/alumni/messages')`,
            [crypto.randomUUID(), targets[0].id, previewText],
=======
             VALUES (?, ?, 'alumni', 'system', 'New message from the Alumni Office', 'You have a new message. Open the Messages tab to read it.', 'medium', '/alumni/messages')`,
            [crypto.randomUUID(), targets[0].id],
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
          );
        }
      } else {
        await mysql.query(
          `INSERT INTO notifications
             (id, user_id, recipient_role, type, title, description, priority, link)
           VALUES (?, NULL, 'admin', 'system', ?, 'You have a new message. Open the Messages tab to read it.', 'medium', ?)`,
          [
            crypto.randomUUID(),
            `New message from ${alumniName}`,
<<<<<<< HEAD
            previewText,
=======
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
            `/admin/messages?alumniId=${encodeURIComponent(alumniId)}&name=${encodeURIComponent(alumniName)}&email=${encodeURIComponent(alumniEmail)}&course=${encodeURIComponent(alumniCourse ?? '')}`,
          ],
        );
      }
    } catch (_) {
      // best-effort only
    }

    const rows = await mysql.query(
      'SELECT * FROM messages WHERE id = ? LIMIT 1',
      [messageId],
    );
    return res.status(201).json(toMessage(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/conversations/:id/read (admin clears either side; alumni only
// clear their own thread — the flag is derived from the role, never the body)
router.patch('/:id/read', async (req, res, next) => {
  try {
<<<<<<< HEAD
    const isAdmin = req.user.role === 'admin';
    if (!isAdmin && !isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You can only read your own conversation.',
      });
    }
=======
    if (!canAccessConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
      });
    }
    const isAdmin =
      req.body?.isAdmin === true || req.user.role === 'admin';
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
    await mysql.query(
      isAdmin
        ? 'UPDATE conversations SET unread_admin = 0 WHERE id = ?'
        : 'UPDATE conversations SET unread_alumni = 0 WHERE id = ?',
      [req.params.id],
    );
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
module.exports.requireAdminList = requireAdmin;
