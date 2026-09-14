const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

function parseJson(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function toSurvey(row) {
  return {
    id: row.id,
    title: row.title ?? '',
    description: row.description ?? null,
    targetGraduationYear:
      row.target_graduation_year === null ||
      row.target_graduation_year === undefined
        ? null
        : Number(row.target_graduation_year),
    questions: parseJson(row.questions_json, []),
    visibility: row.visibility ?? 'public',
    isActive: row.is_active === 1,
    createdBy: row.created_by ?? null,
    createdAt: iso(row.created_at) ?? new Date().toISOString(),
    updatedAt: iso(row.updated_at),
  };
}

function toResponse(row) {
  return {
    id: row.id,
    surveyId: row.survey_id,
    userId: row.user_id,
    answers: parseJson(row.answers_json, {}),
    completedAt: iso(row.submitted_at) ?? new Date().toISOString(),
  };
}

router.use(authenticate);

// GET /api/surveys?visibility=public
router.get('/', async (req, res, next) => {
  try {
    let sql = 'SELECT * FROM surveys WHERE is_deleted = 0';
    const params = [];
    if (req.query.visibility === 'public') {
      sql += ' AND visibility = ?';
      params.push('public');
    }
    sql += ' ORDER BY created_at DESC';
    const rows = await mysql.query(sql, params);
    return res.json(rows.map(toSurvey));
  } catch (err) {
    return next(err);
  }
});

// POST /api/surveys (admin)
router.post('/', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.title || !String(body.title).trim()) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'Survey title is required.',
      });
    }
    const id = crypto.randomUUID();
    const questions = Array.isArray(body.questions)
      ? body.questions
      : Array.isArray(body.questions_json)
        ? body.questions_json
        : [];
    await mysql.query(
      `INSERT INTO surveys
         (id, title, description, target_graduation_year, questions_json,
          visibility, is_active, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        String(body.title).trim(),
        body.description ? String(body.description) : null,
        body.targetGraduationYear === undefined ||
        body.targetGraduationYear === null
          ? null
          : Number(body.targetGraduationYear),
        JSON.stringify(questions),
        body.visibility === 'private' ? 'private' : 'public',
        body.isActive === false ? 0 : 1,
        req.user.uid,
      ],
    );
    const rows = await mysql.query('SELECT * FROM surveys WHERE id = ? LIMIT 1', [
      id,
    ]);
    return res.status(201).json(toSurvey(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/surveys/:id (admin)
router.patch('/:id', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const sets = [];
    const params = [];
    if (typeof body.title === 'string' && body.title.trim()) {
      sets.push('title = ?');
      params.push(body.title.trim());
    }
    if (body.description !== undefined) {
      sets.push('description = ?');
      params.push(body.description ? String(body.description) : null);
    }
    if (body.visibility === 'public' || body.visibility === 'private') {
      sets.push('visibility = ?');
      params.push(body.visibility);
    }
    if (Array.isArray(body.questions) || Array.isArray(body.questions_json)) {
      sets.push('questions_json = ?');
      params.push(
        JSON.stringify(body.questions ?? body.questions_json),
      );
    }
    if (body.isActive !== undefined) {
      sets.push('is_active = ?');
      params.push(body.isActive === false ? 0 : 1);
    }
    if (body.targetGraduationYear !== undefined) {
      sets.push('target_graduation_year = ?');
      params.push(
        body.targetGraduationYear === null
          ? null
          : Number(body.targetGraduationYear),
      );
    }
    if (sets.length === 0) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable survey fields.',
      });
    }
    params.push(req.params.id);
    const result = await mysql.query(
      `UPDATE surveys SET ${sets.join(', ')} WHERE id = ? AND is_deleted = 0`,
      params,
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No survey exists with that id.',
      });
    }
    const rows = await mysql.query('SELECT * FROM surveys WHERE id = ? LIMIT 1', [
      req.params.id,
    ]);
    return res.json({ updated: true, survey: toSurvey(rows[0]) });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/surveys/:id (admin, soft-delete + hide its responses)
router.delete('/:id', requireAdmin, async (req, res, next) => {
  try {
    const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
    const result = await mysql.query(
      'UPDATE surveys SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [now, req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No survey exists with that id.',
      });
    }
    await mysql.query(
      'UPDATE survey_responses SET is_deleted = 1, deleted_at = ? WHERE survey_id = ?',
      [now, req.params.id],
    );
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

// GET /api/surveys/:id/responses (admin) with user names for the review UI
router.get('/:id/responses', requireAdmin, async (req, res, next) => {
  try {
    const rows = await mysql.query(
      `SELECT r.*, u.full_name AS respondent_name, u.email AS respondent_email
       FROM survey_responses r
       LEFT JOIN users u ON u.id = r.user_id
       WHERE r.survey_id = ? AND r.is_deleted = 0
       ORDER BY r.submitted_at DESC`,
      [req.params.id],
    );
    return res.json(
      rows.map((r) => ({
        ...toResponse(r),
        respondentName: r.respondent_name ?? null,
        respondentEmail: r.respondent_email ?? null,
      })),
    );
  } catch (err) {
    return next(err);
  }
});

// GET /api/surveys/responses/mine
router.get('/responses/mine', async (req, res, next) => {
  try {
    const rows = await mysql.query(
      'SELECT * FROM survey_responses WHERE user_id = ? AND is_deleted = 0',
      [req.user.uid],
    );
    return res.json(rows.map(toResponse));
  } catch (err) {
    return next(err);
  }
});

// POST /api/surveys/responses (alumni submit; one row per survey+user)
router.post('/responses', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.surveyId) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'surveyId is required.',
      });
    }
    const surveys = await mysql.query(
      'SELECT id FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [body.surveyId],
    );
    if (surveys.length === 0) {
      return res.status(404).json({
        error: 'survey_not_found',
        message: 'No survey exists with that id.',
      });
    }
    const answers =
      body.answers !== undefined && body.answers !== null ? body.answers : {};
    const existing = await mysql.query(
      'SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1',
      [body.surveyId, req.user.uid],
    );
    if (existing.length > 0) {
      await mysql.query(
        'UPDATE survey_responses SET answers_json = ?, is_deleted = 0, deleted_at = NULL WHERE id = ?',
        [JSON.stringify(answers), existing[0].id],
      );
      const rows = await mysql.query(
        'SELECT * FROM survey_responses WHERE id = ? LIMIT 1',
        [existing[0].id],
      );
      return res.json(toResponse(rows[0]));
    }
    const id = crypto.randomUUID();
    await mysql.query(
      'INSERT INTO survey_responses (id, survey_id, user_id, answers_json) VALUES (?, ?, ?, ?)',
      [id, body.surveyId, req.user.uid, JSON.stringify(answers)],
    );
    const rows = await mysql.query(
      'SELECT * FROM survey_responses WHERE id = ? LIMIT 1',
      [id],
    );
    return res.status(201).json(toResponse(rows[0]));
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
