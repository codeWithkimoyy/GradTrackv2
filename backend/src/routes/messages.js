const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');
const db = require('../db/procedures');
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
    text: cipher.decrypt(row.text ?? ''),
    imageUrl: row.image_url ?? null,
    timestamp: iso(row.created_at) ?? new Date().toISOString(),
    isRead: row.is_read === 1,
  };
}

router.use(authenticate);

function ownConversationId(user) {
  return `conv_${user.alumniId ?? user.uid}`;
}

function canAccessConversation(user, conversationId) {
  if (!user) return false;
  if (user.role === 'admin') return true;
  const alumniId = user.alumniId;
  return Boolean(alumniId) && conversationId === `conv_${alumniId}`;
}

function isOwnConversation(user, conversationId) {
  if (user.role === 'admin') return true;
  return conversationId === ownConversationId(user);
}

// GET /api/conversations (admin: all; alumni: own thread or empty)
router.get('/', async (req, res, next) => {
  try {
    if (req.user.role === 'admin') {
      let rows;
      try {
        rows = await db.conversations.list(200);
      } catch (_) {
        rows = await mysql.query(
          'SELECT * FROM conversations WHERE is_deleted = 0 ORDER BY last_message_time DESC, updated_at DESC LIMIT 200',
        );
      }
      return res.json(rows.map(toConversation));
    }
    let rows;
    try {
      rows = await db.conversations.getOwn(ownConversationId(req.user));
    } catch (_) {
      rows = await mysql.query(
        'SELECT * FROM conversations WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [ownConversationId(req.user)],
      );
    }
    return res.json(rows.map(toConversation));
  } catch (err) {
    return next(err);
  }
});

// GET /api/conversations/:id
router.get('/:id', async (req, res, next) => {
  try {
    if (!canAccessConversation(req.user, req.params.id) && !isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
      });
    }
    let rows;
    try {
      rows = await db.conversations.getById(req.params.id);
    } catch (_) {
      rows = await mysql.query(
        'SELECT * FROM conversations WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [req.params.id],
      );
    }
    if (rows.length === 0) return res.json(null);
    return res.json(toConversation(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// GET /api/conversations/:id/messages
router.get('/:id/messages', async (req, res, next) => {
  try {
    if (!canAccessConversation(req.user, req.params.id) && !isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
      });
    }
    let rows;
    try {
      rows = await db.messages.listByConversation(req.params.id, 500);
    } catch (_) {
      rows = await mysql.query(
        'SELECT * FROM messages WHERE conversation_id = ? AND is_deleted = 0 ORDER BY created_at ASC LIMIT 500',
        [req.params.id],
      );
    }
    return res.json(rows.map(toMessage));
  } catch (err) {
    return next(err);
  }
});

// POST /api/conversations/:id/messages
router.post('/:id/messages', async (req, res, next) => {
  try {
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const imageUrl = typeof req.body?.imageUrl === 'string' ? req.body.imageUrl.trim() : '';
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
    const previewText = text || (imageUrl ? '📷 Photo' : '');

    // Upsert conversation header FIRST via SP with fallback
    try {
      await db.conversations.upsert({
        id: conversationId,
        alumni_id: alumniId,
        alumni_name: alumniName,
        alumni_email: alumniEmail,
        alumni_course: alumniCourse,
        participant_ids_json: participantIds,
        last_message: encryptedText || previewText,
        last_message_time: now,
        last_sender_id: req.user.uid,
        unread_admin: isAdmin ? 0 : 1,
        unread_alumni: isAdmin ? 1 : 0,
      });
      // SP already increments unread; clear sender's own unread
      if (isAdmin) {
        try { await db.conversations.markReadAdmin(conversationId); } catch (_) {}
      } else {
        try { await db.conversations.markReadAlumni(conversationId); } catch (_) {}
      }
    } catch (_) {
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
          encryptedText || previewText,
          now,
          req.user.uid,
          isAdmin ? 0 : 1,
          isAdmin ? 1 : 0,
        ],
      );
      if (isAdmin) {
        await mysql.query('UPDATE conversations SET unread_admin = 0 WHERE id = ?', [conversationId]);
      } else {
        await mysql.query('UPDATE conversations SET unread_alumni = 0 WHERE id = ?', [conversationId]);
      }
    }

    const messageId = crypto.randomUUID();
    try {
      await db.messages.create({
        id: messageId,
        conversation_id: conversationId,
        sender_id: req.user.uid,
        sender_name: req.user.fullName,
        sender_role: req.user.role,
        recipient_id: isAdmin ? alumniId : 'admin',
        user_id: req.user.uid,
        participant_ids_json: participantIds,
        text: encryptedText || previewText,
        image_url: imageUrl || null,
      });
    } catch (_) {
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
          encryptedText || previewText,
          imageUrl || null,
        ],
      );
    }

    // Best-effort bell alert via SP with fallback
    try {
      if (isAdmin) {
        let targets;
        try {
          targets = await db.users.getByAlumniId(alumniId);
        } catch (_) {
          targets = await mysql.query('SELECT id FROM users WHERE alumni_id = ? AND is_deleted = 0 LIMIT 1', [alumniId]);
        }
        if (targets[0]) {
          try {
            await db.notifications.create({ id: crypto.randomUUID(), user_id: targets[0].id, recipient_role: 'alumni', type: 'system', title: 'New message from the Alumni Office', description: previewText || 'You have a new message. Open the Messages tab to read it.', priority: 'medium', link: '/alumni/messages' });
          } catch (_) {
            await mysql.query(`INSERT INTO notifications (id, user_id, recipient_role, type, title, description, priority, link) VALUES (?, ?, 'alumni', 'system', 'New message from the Alumni Office', ?, 'medium', '/alumni/messages')`, [crypto.randomUUID(), targets[0].id, previewText || 'You have a new message.']);
          }
        }
      } else {
        try {
          await db.notifications.create({ id: crypto.randomUUID(), user_id: null, recipient_role: 'admin', type: 'system', title: `New message from ${alumniName}`, description: 'You have a new message. Open the Messages tab to read it.', priority: 'medium', link: `/admin/messages?alumniId=${encodeURIComponent(alumniId)}&name=${encodeURIComponent(alumniName)}&email=${encodeURIComponent(alumniEmail)}&course=${encodeURIComponent(alumniCourse ?? '')}` });
        } catch (_) {
          await mysql.query(`INSERT INTO notifications (id, user_id, recipient_role, type, title, description, priority, link) VALUES (?, NULL, 'admin', 'system', ?, 'You have a new message. Open the Messages tab to read it.', 'medium', ?)`, [crypto.randomUUID(), `New message from ${alumniName}`, `/admin/messages?alumniId=${encodeURIComponent(alumniId)}&name=${encodeURIComponent(alumniName)}&email=${encodeURIComponent(alumniEmail)}&course=${encodeURIComponent(alumniCourse ?? '')}`]);
        }
      }
    } catch (_) {
      // best-effort only
    }

    let rows;
    try {
      rows = await db.messages.getById(messageId);
    } catch (_) {
      rows = await mysql.query('SELECT * FROM messages WHERE id = ? LIMIT 1', [messageId]);
    }
    return res.status(201).json(toMessage(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/conversations/:id/read
router.patch('/:id/read', async (req, res, next) => {
  try {
    if (!canAccessConversation(req.user, req.params.id) && !isOwnConversation(req.user, req.params.id)) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'You do not have access to this conversation.',
      });
    }
    const isAdmin = req.body?.isAdmin === true || req.user.role === 'admin';
    try {
      if (isAdmin) await db.conversations.markReadAdmin(req.params.id);
      else await db.conversations.markReadAlumni(req.params.id);
    } catch (_) {
      await mysql.query(
        isAdmin ? 'UPDATE conversations SET unread_admin = 0 WHERE id = ?' : 'UPDATE conversations SET unread_alumni = 0 WHERE id = ?',
        [req.params.id],
      );
    }
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
module.exports.requireAdminList = requireAdmin;
