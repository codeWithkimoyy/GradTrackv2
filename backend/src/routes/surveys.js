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
    visibleBatches: parseJson(row.visible_batches_json, []),
    questions: parseJson(row.questions_json, []),
    visibility: row.visibility ?? 'public',
    isActive: row.is_active === 1,
    createdBy: row.created_by ?? null,
    createdAt: iso(row.created_at) ?? new Date().toISOString(),
    updatedAt: iso(row.updated_at),
  };
}

function parseBatches(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((v) => Number(v))
    .filter((n) => Number.isFinite(n) && Number.isInteger(n))
    .sort((a, b) => b - a);
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
    // Alumni are scoped by batch: a survey with no batch restriction is open
    // to everyone, otherwise only matching graduation years may answer it.
    if (req.user.role === 'alumni') {
      if (req.user.graduationYear) {
        sql +=
          ' AND (visible_batches_json IS NULL' +
          ' OR JSON_LENGTH(visible_batches_json) = 0' +
          ' OR JSON_CONTAINS(visible_batches_json, CAST(? AS JSON)))';
        params.push(req.user.graduationYear);
      } else {
        sql +=
          ' AND (visible_batches_json IS NULL' +
          ' OR JSON_LENGTH(visible_batches_json) = 0)';
      }
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
         (id, title, description, target_graduation_year, visible_batches_json,
          questions_json, visibility, is_active, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        String(body.title).trim(),
        body.description ? String(body.description) : null,
        body.targetGraduationYear === undefined ||
        body.targetGraduationYear === null
          ? null
          : Number(body.targetGraduationYear),
        JSON.stringify(parseBatches(body.visibleBatches)),
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
    if (Array.isArray(body.visibleBatches)) {
      sets.push('visible_batches_json = ?');
      params.push(JSON.stringify(parseBatches(body.visibleBatches)));
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

// GET /api/surveys/:id/reports (admin) — aggregated per-question analytics
router.get('/:id/reports', requireAdmin, async (req, res, next) => {
  try {
    const surveys = await mysql.query(
      'SELECT * FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [req.params.id],
    );
    if (surveys.length === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No survey exists with that id.',
      });
    }
    const survey = surveys[0];
    const questions = parseJson(survey.questions_json, []);

    const rows = await mysql.query(
      `SELECT r.answers_json, u.graduation_year
       FROM survey_responses r
       LEFT JOIN users u ON u.id = r.user_id
       WHERE r.survey_id = ? AND r.is_deleted = 0`,
      [req.params.id],
    );

    const totalResponses = rows.length;

    const questionReports = questions.map((q) => {
      const qId = (q.id ?? '').toString();
      const type = q.type ?? 'text';
      const text = q.text ?? '';

      if (type === 'choice') {
        const counts = new Map();
        for (const row of rows) {
          const answers = parseJson(row.answers_json, {});
          const val =
            typeof answers[qId] === 'string' ? answers[qId].trim() : '';
          if (!val) continue;
          counts.set(val, (counts.get(val) ?? 0) + 1);
        }
        const seen = new Set();
        const options = [];
        for (const opt of (Array.isArray(q.options) ? q.options : [])) {
          const key = String(opt).trim();
          const count = counts.get(key) ?? 0;
          seen.add(key);
          options.push({
            value: key,
            count,
            percentage:
              totalResponses === 0
                ? 0
                : Math.round((count / totalResponses) * 1000) / 10,
          });
        }
        for (const [key, count] of counts.entries()) {
          if (seen.has(key)) continue;
          options.push({
            value: key,
            count,
            percentage:
              totalResponses === 0
                ? 0
                : Math.round((count / totalResponses) * 1000) / 10,
          });
        }
        return { id: qId, text, type: 'choice', options };
      }

      // Text questions — collect non-empty answers.
      const answers = [];
      for (const row of rows) {
        const answersMap = parseJson(row.answers_json, {});
        const val = answersMap[qId];
        if (typeof val === 'string' && val.trim()) answers.push(val.trim());
      }
      const totalAnswered = answers.length;
      const capped = answers.length > 50 ? answers.slice(0, 50) : answers;
      return {
        id: qId,
        text,
        type: 'text',
        responses: capped,
        more: answers.length - capped.length,
        totalAnswered,
      };
    });

    // Batch breakdown — group responses by respondent graduation year.
    const batchMap = new Map();
    for (const row of rows) {
      const y =
        row.graduation_year === null || row.graduation_year === undefined
          ? null
          : Number(row.graduation_year);
      batchMap.set(y, (batchMap.get(y) ?? 0) + 1);
    }
    const batchBreakdown = [...batchMap.entries()]
      .map(([year, count]) => ({ year, count }))
      .sort((a, b) => (b.year ?? -1) - (a.year ?? -1));

    return res.json({
      surveyId: survey.id,
      title: survey.title,
      description: survey.description ?? null,
      totalResponses,
      questions: questionReports,
      batchBreakdown,
    });
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
      'SELECT id, visible_batches_json FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [body.surveyId],
    );
    if (surveys.length === 0) {
      return res.status(404).json({
        error: 'survey_not_found',
        message: 'No survey exists with that id.',
      });
    }
    if (req.user.role === 'alumni') {
      const restricted = parseBatches(parseJson(surveys[0].visible_batches_json, []));
      if (restricted.length > 0) {
        const inBatch =
          req.user.graduationYear !== null &&
          req.user.graduationYear !== undefined &&
          restricted.includes(Number(req.user.graduationYear));
        if (!inBatch) {
          return res.status(403).json({
            error: 'batch_restricted',
            message: 'This survey is only open to selected batches.',
          });
        }
      }
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
