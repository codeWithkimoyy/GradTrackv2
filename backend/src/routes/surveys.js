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

function sanitizeText(value, max = 2000) {
  if (value === null || value === undefined) return '';
  let s = String(value).trim();
  // basic HTML tag strip
  s = s.replace(/<[^>]*>/g, '');
  if (s.length > max) s = s.slice(0, max);
  return s;
}

const QUESTION_TYPES = new Set([
  'short_text',
  'long_text',
  'single_select',
  'multi_select',
  'yes_no',
  'number',
  'date',
]);

// Map legacy frontend types
function normalizeType(t) {
  if (!t) return 'short_text';
  const v = String(t).toLowerCase();
  if (v === 'text') return 'short_text';
  if (v === 'choice') return 'single_select';
  if (QUESTION_TYPES.has(v)) return v;
  return 'short_text';
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
    targetBatchYear:
      row.target_batch_year === null || row.target_batch_year === undefined
        ? row.target_graduation_year === null ? null : Number(row.target_graduation_year)
        : Number(row.target_batch_year),
    openingDate: iso(row.opening_date),
    closingDate: iso(row.closing_date),
    status: row.status ?? (row.is_active === 0 ? 'draft' : 'published'),
    allowUpdate: row.allow_update === 1,
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
    updatedAt: iso(row.updated_at),
    isArchived: row.is_archived === 1,
    status: row.status ?? 'submitted',
  };
}

async function fetchQuestions(surveyId) {
  const rows = await mysql.query(
    'SELECT * FROM survey_questions WHERE survey_id = ? AND is_deleted = 0 ORDER BY sort_order ASC, created_at ASC',
    [surveyId]
  );
  const out = [];
  for (const r of rows) {
    const opts = await mysql.query(
      'SELECT * FROM survey_question_options WHERE question_id = ? AND is_deleted = 0 ORDER BY sort_order ASC',
      [r.id]
    );
    out.push({
      id: r.id,
      surveyId: r.survey_id,
      text: r.question_text,
      type: r.question_type,
      placeholder: r.placeholder,
      characterLimit: r.character_limit === null ? null : Number(r.character_limit),
      isRequired: r.is_required === 1,
      isPublished: r.is_published === 1,
      sortOrder: Number(r.sort_order),
      conditionalParentId: r.conditional_parent_id,
      conditionalTriggerValue: r.conditional_trigger_value,
      allowOther: r.allow_other === 1,
      options: opts.map((o) => ({
        id: o.id,
        text: o.option_text,
        sortOrder: Number(o.sort_order),
        isOther: o.is_other === 1,
      })),
    });
  }
  return out;
}

async function syncQuestions(surveyId, questions) {
  // soft-delete existing
  await mysql.query('UPDATE survey_questions SET is_deleted = 1, deleted_at = NOW() WHERE survey_id = ? AND is_deleted = 0', [surveyId]);
  // also soft-delete options via cascade? need explicit
  // insert new
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    const qid = q.id || crypto.randomUUID();
    const type = normalizeType(q.type);
    await mysql.query(
      `INSERT INTO survey_questions
        (id, survey_id, question_text, question_type, placeholder, character_limit, is_required, is_published, sort_order, conditional_parent_id, conditional_trigger_value, allow_other)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        qid,
        surveyId,
        sanitizeText(q.text || q.question_text || `Question ${i + 1}`, 2000),
        type,
        q.placeholder ? sanitizeText(q.placeholder, 300) : null,
        q.characterLimit != null && Number.isFinite(Number(q.characterLimit)) ? Number(q.characterLimit) : null,
        q.isRequired || q.required ? 1 : 0,
        q.isPublished === false || q.is_published === false ? 0 : 1,
        q.sortOrder != null ? Number(q.sortOrder) : i,
        q.conditionalParentId || q.conditional_parent_id || null,
        q.conditionalTriggerValue || q.conditional_trigger_value || null,
        q.allowOther || q.allow_other ? 1 : 0,
      ]
    );
    const opts = Array.isArray(q.options) ? q.options : [];
    for (let j = 0; j < opts.length; j++) {
      const opt = opts[j];
      const text = typeof opt === 'string' ? opt : (opt.text || opt.option_text || '');
      if (!text || !String(text).trim()) continue;
      const isOther = typeof opt === 'object' ? !!opt.isOther : String(text).toLowerCase() === 'other';
      await mysql.query(
        `INSERT INTO survey_question_options (id, question_id, option_text, sort_order, is_other) VALUES (?, ?, ?, ?, ?)`,
        [opt.id || crypto.randomUUID(), qid, sanitizeText(text, 300), opt.sortOrder != null ? Number(opt.sortOrder) : j, isOther ? 1 : 0]
      );
    }
    // if allowOther and no Other option exists, add it
    if ((q.allowOther || q.allow_other) && !opts.some((o) => {
      const t = typeof o === 'string' ? o : (o.text || o.option_text || '');
      return String(t).toLowerCase() === 'other';
    }) && (type === 'single_select' || type === 'multi_select')) {
      await mysql.query(
        `INSERT INTO survey_question_options (id, question_id, option_text, sort_order, is_other) VALUES (?, ?, ?, ?, 1)`,
        [crypto.randomUUID(), qid, 'Other', opts.length]
      );
    }
  }
}

function validateSurveyBody(body) {
  const errors = [];
  const title = sanitizeText(body.title, 300);
  if (!title) errors.push('Survey title is required.');
  if (body.targetBatchYear != null && body.targetGraduationYear != null) {
    // allow both, prefer targetBatchYear
  }
  let opening = null, closing = null;
  if (body.openingDate) {
    opening = new Date(body.openingDate);
    if (Number.isNaN(opening.getTime())) errors.push('Opening date is invalid.');
  }
  if (body.closingDate) {
    closing = new Date(body.closingDate);
    if (Number.isNaN(closing.getTime())) errors.push('Closing date is invalid.');
  }
  if (opening && closing && opening > closing) errors.push('Opening date must be before closing date.');
  const status = body.status ? String(body.status).toLowerCase() : null;
  if (status && !['draft','published','closed'].includes(status)) errors.push('Status must be draft, published, or closed.');
  const questions = body.questions || body.questions_json;
  if (questions != null && !Array.isArray(questions)) errors.push('Questions must be an array.');
  if (Array.isArray(questions)) {
    const seen = new Set();
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      const text = sanitizeText(q.text || q.question_text, 2000);
      if (!text) errors.push(`Question ${i + 1}: text is required.`);
      const type = normalizeType(q.type || q.question_type);
      if (!QUESTION_TYPES.has(type)) errors.push(`Question ${i + 1}: invalid type.`);
      if (q.characterLimit != null && (Number(q.characterLimit) < 1 || Number(q.characterLimit) > 5000)) errors.push(`Question ${i + 1}: character limit 1-5000.`);
      if ((type === 'single_select' || type === 'multi_select')) {
        const opts = q.options || [];
        if (!Array.isArray(opts)) errors.push(`Question ${i + 1}: options must be array.`);
        else {
          const texts = opts.map((o) => typeof o === 'string' ? String(o).trim() : String(o.text || o.option_text || '').trim()).filter(Boolean);
          const uniq = new Set(texts.map((t) => t.toLowerCase()));
          if (uniq.size !== texts.length) errors.push(`Question ${i + 1}: duplicate choices not allowed.`);
          if (texts.some((t) => !t)) errors.push(`Question ${i + 1}: empty choice not allowed.`);
          if (q.allowOther && texts.map((t) => t.toLowerCase()).includes('other') && texts.filter((t) => t.toLowerCase() === 'other').length > 1) errors.push(`Question ${i + 1}: Other duplicated.`);
        }
      }
      if (q.id) {
        if (seen.has(q.id)) errors.push(`Question ${i + 1}: duplicate id.`);
        seen.add(q.id);
      }
      if (q.conditionalParentId || q.conditional_parent_id) {
        const pid = q.conditionalParentId || q.conditional_parent_id;
        // parent must exist earlier in array
        const parentExists = questions.slice(0, i).some((qq) => (qq.id || '') === pid);
        if (!parentExists) errors.push(`Question ${i + 1}: conditional parent not found among earlier questions.`);
        if (!(q.conditionalTriggerValue || q.conditional_trigger_value)) errors.push(`Question ${i + 1}: conditional trigger value required.`);
      }
    }
  }
  return { errors, title, opening, closing, status };
}

router.use(authenticate);

// GET /api/surveys?visibility=public&status=published
router.get('/', async (req, res, next) => {
  try {
    let sql = 'SELECT * FROM surveys WHERE is_deleted = 0';
    const params = [];
    if (req.query.visibility === 'public' || req.query.visibility === 'private') {
      sql += ' AND visibility = ?';
      params.push(req.query.visibility);
    }
    if (req.query.status && ['draft','published','closed'].includes(String(req.query.status))) {
      sql += ' AND status = ?';
      params.push(String(req.query.status));
    }
    // alumni only see published and within dates
    const isAlumni = req.user && req.user.role === 'alumni';
    if (isAlumni) {
      sql += " AND status = 'published' AND visibility = 'public'";
      sql += ' AND (opening_date IS NULL OR opening_date <= NOW())';
      sql += ' AND (closing_date IS NULL OR closing_date >= NOW())';
      sql += ' AND is_active = 1';
    }
    sql += ' ORDER BY updated_at DESC, created_at DESC';
    const rows = await mysql.query(sql, params);
    const surveys = rows.map(toSurvey);
    // attach normalized questions if requested
    if (req.query.include === 'questions') {
      for (const s of surveys) {
        s.questionsDetailed = await fetchQuestions(s.id);
      }
    }
    return res.json(surveys);
  } catch (err) {
    return next(err);
  }
});

// GET /api/surveys/:id
router.get('/:id', async (req, res, next) => {
  try {
    const rows = await mysql.query('SELECT * FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'not_found', message: 'No survey exists with that id.' });
    const survey = toSurvey(rows[0]);
    // check visibility for alumni
    if (req.user.role === 'alumni') {
      if (survey.status !== 'published' || survey.visibility !== 'public') return res.status(403).json({ error: 'forbidden', message: 'Survey not available.' });
      if (survey.openingDate && new Date(survey.openingDate) > new Date()) return res.status(403).json({ error: 'not_open', message: 'Survey has not opened yet.' });
      if (survey.closingDate && new Date(survey.closingDate) < new Date()) return res.status(403).json({ error: 'closed', message: 'Survey is closed.' });
    }
    const detailed = await fetchQuestions(survey.id);
    // filter unpublished for alumni
    if (req.user.role === 'alumni') {
      survey.questionsDetailed = detailed.filter((q) => q.isPublished);
    } else {
      survey.questionsDetailed = detailed;
    }
    // keep legacy questions_json for frontend fallback
    return res.json(survey);
  } catch (err) {
    return next(err);
  }
});

// POST /api/surveys (admin)
router.post('/', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const { errors, title, opening, closing, status } = validateSurveyBody(body);
    if (errors.length) return res.status(400).json({ error: 'validation', message: errors.join(' '), details: errors });
    const id = crypto.randomUUID();
    const questions = Array.isArray(body.questions) ? body.questions : Array.isArray(body.questions_json) ? body.questions_json : [];
    const targetBatch = body.targetBatchYear != null ? Number(body.targetBatchYear) : (body.targetGraduationYear != null ? Number(body.targetGraduationYear) : null);
    await mysql.query(
      `INSERT INTO surveys
         (id, title, description, target_graduation_year, target_batch_year, opening_date, closing_date, status, allow_update,
          questions_json, visibility, is_active, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        title,
        body.description ? sanitizeText(body.description, 5000) : null,
        targetBatch,
        targetBatch,
        opening ? opening.toISOString().slice(0,19).replace('T',' ') : null,
        closing ? closing.toISOString().slice(0,19).replace('T',' ') : null,
        status || 'draft',
        body.allowUpdate ? 1 : 0,
        JSON.stringify(questions),
        body.visibility === 'private' ? 'private' : 'public',
        body.isActive === false ? 0 : 1,
        req.user.uid,
      ],
    );
    if (questions.length) await syncQuestions(id, questions);
    const rows = await mysql.query('SELECT * FROM surveys WHERE id = ? LIMIT 1', [id]);
    const survey = toSurvey(rows[0]);
    survey.questionsDetailed = await fetchQuestions(id);
    return res.status(201).json(survey);
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/surveys/:id (admin) - supports partial + full questions reorder
router.patch('/:id', requireAdmin, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const sets = [];
    const params = [];
    if (typeof body.title === 'string' && body.title.trim()) {
      sets.push('title = ?');
      params.push(sanitizeText(body.title, 300));
    }
    if (body.description !== undefined) {
      sets.push('description = ?');
      params.push(body.description ? sanitizeText(body.description, 5000) : null);
    }
    if (body.visibility === 'public' || body.visibility === 'private') {
      sets.push('visibility = ?');
      params.push(body.visibility);
    }
    if (body.status && ['draft','published','closed'].includes(String(body.status).toLowerCase())) {
      sets.push('status = ?');
      params.push(String(body.status).toLowerCase());
    }
    if (body.targetBatchYear !== undefined || body.targetGraduationYear !== undefined) {
      const v = body.targetBatchYear != null ? Number(body.targetBatchYear) : (body.targetGraduationYear != null ? Number(body.targetGraduationYear) : null);
      sets.push('target_batch_year = ?');
      params.push(v);
      sets.push('target_graduation_year = ?');
      params.push(v);
    }
    if (body.openingDate !== undefined) {
      sets.push('opening_date = ?');
      params.push(body.openingDate ? new Date(body.openingDate).toISOString().slice(0,19).replace('T',' ') : null);
    }
    if (body.closingDate !== undefined) {
      sets.push('closing_date = ?');
      params.push(body.closingDate ? new Date(body.closingDate).toISOString().slice(0,19).replace('T',' ') : null);
    }
    if (body.allowUpdate !== undefined) {
      sets.push('allow_update = ?');
      params.push(body.allowUpdate ? 1 : 0);
    }
    if (Array.isArray(body.questions) || Array.isArray(body.questions_json)) {
      const qs = body.questions ?? body.questions_json;
      const v = validateSurveyBody({ ...body, questions: qs, title: 'tmp' });
      if (v.errors.length) {
        // filter out title error fake
        const filtered = v.errors.filter(e => !e.includes('Survey title'));
        if (filtered.length) return res.status(400).json({ error: 'validation', message: filtered.join(' '), details: filtered });
      }
      sets.push('questions_json = ?');
      params.push(JSON.stringify(qs));
    }
    if (body.isActive !== undefined) {
      sets.push('is_active = ?');
      params.push(body.isActive === false ? 0 : 1);
    }
    if (sets.length === 0 && !body.questions && !body.questions_json) {
      return res.status(400).json({ error: 'no_editable_fields', message: 'No editable fields.' });
    }
    if (sets.length) {
      params.push(req.params.id);
      const result = await mysql.query(`UPDATE surveys SET ${sets.join(', ')} WHERE id = ? AND is_deleted = 0`, params);
      if (result.affectedRows === 0) return res.status(404).json({ error: 'not_found', message: 'No survey exists with that id.' });
    }
    if (Array.isArray(body.questions) || Array.isArray(body.questions_json)) {
      const qs = body.questions ?? body.questions_json;
      await syncQuestions(req.params.id, qs);
    }
    const rows = await mysql.query('SELECT * FROM surveys WHERE id = ? LIMIT 1', [req.params.id]);
    const survey = toSurvey(rows[0]);
    survey.questionsDetailed = await fetchQuestions(req.params.id);
    return res.json({ updated: true, survey });
  } catch (err) {
    return next(err);
  }
});

// PUT /api/surveys/:id/questions/reorder
router.put('/:id/questions/reorder', requireAdmin, async (req, res, next) => {
  try {
    const order = req.body?.order;
    if (!Array.isArray(order)) return res.status(400).json({ error: 'validation', message: 'order must be array of question ids.' });
    for (let i = 0; i < order.length; i++) {
      await mysql.query('UPDATE survey_questions SET sort_order = ? WHERE id = ? AND survey_id = ? AND is_deleted = 0', [i, order[i], req.params.id]);
    }
    // also update JSON order
    const rows = await mysql.query('SELECT questions_json FROM surveys WHERE id = ? LIMIT 1', [req.params.id]);
    if (rows.length) {
      const qs = parseJson(rows[0].questions_json, []);
      const map = new Map(qs.map((q) => [q.id, q]));
      const reordered = order.map((id) => map.get(id)).filter(Boolean);
      // append any missing
      for (const q of qs) if (!order.includes(q.id)) reordered.push(q);
      await mysql.query('UPDATE surveys SET questions_json = ? WHERE id = ?', [JSON.stringify(reordered), req.params.id]);
    }
    return res.json({ updated: true });
  } catch (err) { return next(err); }
});

// DELETE /api/surveys/:id (admin)
router.delete('/:id', requireAdmin, async (req, res, next) => {
  try {
    const now = new Date().toISOString().slice(0,19).replace('T',' ');
    const result = await mysql.query('UPDATE surveys SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1', [now, req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'not_found', message: 'No survey exists with that id.' });
    await mysql.query('UPDATE survey_responses SET is_deleted = 1, deleted_at = ? WHERE survey_id = ?', [now, req.params.id]);
    await mysql.query('UPDATE survey_questions SET is_deleted = 1, deleted_at = ? WHERE survey_id = ?', [now, req.params.id]);
    return res.json({ deleted: true });
  } catch (err) { return next(err); }
});

// GET /api/surveys/:id/responses (admin)
router.get('/:id/responses', requireAdmin, async (req, res, next) => {
  try {
    const { batch, employment, courseRelevance, q, dateFrom, dateTo, archived } = req.query;
    let sql = `
      SELECT r.*, u.full_name AS respondent_name, u.email AS respondent_email,
             u.graduation_year, u.academic_year_graduated, u.course_name, u.employment_status, u.birthdate
      FROM survey_responses r
      LEFT JOIN users u ON u.id = r.user_id
      WHERE r.survey_id = ? AND r.is_deleted = 0
    `;
    const params = [req.params.id];
    if (archived === '1') sql += ' AND r.is_archived = 1';
    else if (archived === '0') sql += ' AND r.is_archived = 0';
    // batch filter
    if (batch) {
      // support S.Y. 2020-2021 or gy:2020 or year 2021
      const y = String(batch).replace('S.Y.','').trim();
      const start = parseInt(y.split(/[–-]/)[0],10);
      if (!Number.isNaN(start)) {
        sql += ' AND (u.academic_year_graduated LIKE ? OR u.graduation_year = ?)';
        params.push(`%${start}%`, start+1);
      }
    }
    if (employment) {
      sql += ' AND u.employment_status = ?';
      params.push(String(employment));
    }
    if (q) {
      sql += ' AND (u.full_name LIKE ? OR r.answers_json LIKE ?)';
      params.push(`%${q}%`, `%${q}%`);
    }
    if (dateFrom) {
      sql += ' AND r.submitted_at >= ?';
      params.push(new Date(String(dateFrom)).toISOString().slice(0,19).replace('T',' '));
    }
    if (dateTo) {
      sql += ' AND r.submitted_at <= ?';
      params.push(new Date(String(dateTo)).toISOString().slice(0,19).replace('T',' '));
    }
    sql += ' ORDER BY r.submitted_at DESC';
    const rows = await mysql.query(sql, params);
    // courseRelevance filter requires answer inspection
    let filtered = rows;
    if (courseRelevance) {
      // e.g. courseRelevance=yes -> question about relatedness answer contains "Yes"
      filtered = rows.filter((r) => {
        const ans = parseJson(r.answers_json, {});
        const vals = Object.values(ans).join(' ').toLowerCase();
        if (String(courseRelevance).toLowerCase() === 'yes') return vals.includes('directly related') || vals.includes('somewhat related');
        if (String(courseRelevance).toLowerCase() === 'no') return vals.includes('not related');
        return true;
      });
    }
    // fetch normalized answers for each
    const out = [];
    for (const r of filtered) {
      const answers = await mysql.query('SELECT * FROM survey_answers WHERE submission_id = ? AND is_deleted = 0', [r.id]);
      out.push({
        ...toResponse(r),
        respondentName: r.respondent_name ?? null,
        respondentEmail: r.respondent_email ?? null,
        graduationYear: r.graduation_year ?? null,
        academicYearGraduated: r.academic_year_graduated ?? null,
        course: r.course_name ?? null,
        employmentStatus: r.employment_status ?? null,
        answersDetailed: answers.map((a) => ({
          questionId: a.question_id,
          answerText: a.answer_text,
          answerJson: parseJson(a.answer_json, null),
          customOtherText: a.custom_other_text,
        })),
      });
    }
    return res.json(out);
  } catch (err) { return next(err); }
});

// GET /api/surveys/:id/export
router.get('/:id/export', requireAdmin, async (req, res, next) => {
  try {
    const format = (req.query.format || 'csv').toString().toLowerCase();
    const surveyRows = await mysql.query('SELECT * FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1', [req.params.id]);
    if (surveyRows.length === 0) return res.status(404).json({ error: 'not_found', message: 'Survey not found.' });
    const questions = await fetchQuestions(req.params.id);
    const responses = await mysql.query(
      `SELECT r.*, u.full_name, u.email, u.graduation_year, u.academic_year_graduated, u.course_name
       FROM survey_responses r LEFT JOIN users u ON u.id = r.user_id
       WHERE r.survey_id = ? AND r.is_deleted = 0 AND r.is_archived = 0 ORDER BY r.submitted_at DESC`,
      [req.params.id]
    );
    // Build CSV
    const headers = ['Submission ID','Alumni Name','Email','Batch','Course','Submitted At', ...questions.map((q) => q.question_text.replace(/"/g,'""')), 'Custom Other'];
    const escape = (v) => `"${String(v ?? '').replace(/"/g,'""')}"`;
    const lines = [headers.map(escape).join(',')];
    for (const r of responses) {
      const ansMap = new Map();
      const ansRows = await mysql.query('SELECT * FROM survey_answers WHERE submission_id = ? AND is_deleted = 0', [r.id]);
      for (const a of ansRows) ansMap.set(a.question_id, a);
      const row = [
        r.id, r.full_name ?? '', r.email ?? '', r.academic_year_graduated || r.graduation_year || '', r.course_name || '', iso(r.submitted_at) ?? '',
        ...questions.map((q) => {
          const a = ansMap.get(q.id);
          if (!a) return '';
          if (a.answer_json) {
            try { const arr = JSON.parse(a.answer_json); if (Array.isArray(arr)) return arr.join('; '); } catch(_){}
            return a.answer_json;
          }
          return a.answer_text || '';
        }),
        // collect custom others
        (() => {
          const others = [];
          for (const a of ansRows) if (a.custom_other_text) others.push(`${a.question_id}:${a.custom_other_text}`);
          return others.join(' | ');
        })()
      ];
      lines.push(row.map(escape).join(','));
    }
    const csv = lines.join('\r\n');
    if (format === 'json') return res.json({ headers, rows: responses.length, csv });
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="survey_${req.params.id}_export.csv"`);
    return res.send(csv);
  } catch (err) { return next(err); }
});

// PATCH /api/surveys/responses/:id/archive
router.patch('/responses/:id/archive', requireAdmin, async (req, res, next) => {
  try {
    const archived = req.body?.archived ? 1 : 0;
    await mysql.query('UPDATE survey_responses SET is_archived = ? WHERE id = ? AND is_deleted = 0', [archived, req.params.id]);
    return res.json({ updated: true });
  } catch (err) { return next(err); }
});

// GET /api/surveys/:id/summary
router.get('/:id/summary', requireAdmin, async (req, res, next) => {
  try {
    const questions = await fetchQuestions(req.params.id);
    const submissions = await mysql.query('SELECT id FROM survey_responses WHERE survey_id = ? AND is_deleted = 0 AND is_archived = 0 AND status = ?', [req.params.id, 'submitted']);
    const total = submissions.length;
    const summary = [];
    for (const q of questions) {
      if (!q.isPublished) continue;
      const answers = await mysql.query('SELECT answer_text, answer_json, custom_other_text FROM survey_answers WHERE question_id = ? AND is_deleted = 0', [q.id]);
      const counts = {};
      const others = [];
      for (const a of answers) {
        let vals = [];
        if (a.answer_json) {
          try { const arr = JSON.parse(a.answer_json); vals = Array.isArray(arr) ? arr : [a.answer_json]; } catch(_){ vals = [a.answer_json]; }
        } else if (a.answer_text) vals = [a.answer_text];
        for (const v of vals) {
          const key = String(v).trim();
          if (!key) continue;
          counts[key] = (counts[key] || 0) + 1;
        }
        if (a.custom_other_text) others.push(a.custom_other_text);
      }
      const opts = Object.entries(counts).map(([text, count]) => ({ text, count, percent: total ? Math.round((count/total)*1000)/10 : 0 }));
      summary.push({ questionId: q.id, questionText: q.question_text, type: q.question_type, totalResponses: answers.length, options: opts, otherAnswers: others });
    }
    return res.json({ totalSubmissions: total, questions: summary });
  } catch (err) { return next(err); }
});

// GET /api/surveys/responses/mine
router.get('/responses/mine', async (req, res, next) => {
  try {
    const rows = await mysql.query('SELECT * FROM survey_responses WHERE user_id = ? AND is_deleted = 0', [req.user.uid]);
    return res.json(rows.map(toResponse));
  } catch (err) { return next(err); }
});

// POST /api/surveys/responses (alumni submit; one row per survey+user)
router.post('/responses', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    if (!body.surveyId) return res.status(400).json({ error: 'missing_fields', message: 'surveyId is required.' });
    const surveys = await mysql.query('SELECT * FROM surveys WHERE id = ? AND is_deleted = 0 LIMIT 1', [body.surveyId]);
    if (surveys.length === 0) return res.status(404).json({ error: 'survey_not_found', message: 'No survey exists with that id.' });
    const survey = toSurvey(surveys[0]);
    if (survey.status !== 'published') return res.status(403).json({ error: 'not_published', message: 'Survey is not published.' });
    if (survey.closingDate && new Date(survey.closingDate) < new Date()) return res.status(403).json({ error: 'closed', message: 'Survey is closed.' });
    if (survey.openingDate && new Date(survey.openingDate) > new Date()) return res.status(403).json({ error: 'not_open', message: 'Survey has not opened yet.' });
    // check allowUpdate
    const allowUpdate = surveys[0].allow_update === 1;
    const existing = await mysql.query('SELECT id, status FROM survey_responses WHERE survey_id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1', [body.surveyId, req.user.uid]);
    if (existing.length > 0 && existing[0].status === 'submitted' && !allowUpdate) {
      return res.status(409).json({ error: 'already_submitted', message: 'You have already submitted this survey.' });
    }
    const answers = body.answers !== undefined && body.answers !== null ? body.answers : {};
    const customOthers = body.customOthers || {};
    // Validate required + conditional
    const questions = await fetchQuestions(body.surveyId);
    const answerMap = typeof answers === 'object' && !Array.isArray(answers) ? answers : {};
    for (const q of questions) {
      if (!q.isPublished) continue;
      // conditional check
      if (q.conditionalParentId) {
        const parentVal = answerMap[q.conditionalParentId];
        const trigger = q.conditionalTriggerValue;
        let visible = false;
        if (Array.isArray(parentVal)) visible = parentVal.includes(trigger);
        else visible = String(parentVal ?? '') === String(trigger);
        if (!visible) continue;
      }
      if (q.isRequired) {
        const val = answerMap[q.id];
        const isEmpty = val === undefined || val === null || (typeof val === 'string' && !val.trim()) || (Array.isArray(val) && val.length === 0);
        if (isEmpty) return res.status(400).json({ error: 'validation', message: `Question "${q.question_text}" is required.` });
        // Other requires custom text
        if (q.allowOther) {
          const strVal = String(val);
          const arrVal = Array.isArray(val) ? val : [strVal];
          if (arrVal.includes('Other')) {
            const otherText = customOthers[q.id] || answerMap[`${q.id}_other`] || '';
            if (!String(otherText).trim()) return res.status(400).json({ error: 'validation', message: `Please specify for "${q.question_text}".` });
          }
        }
      }
      // character limit
      if (q.characterLimit && typeof answerMap[q.id] === 'string' && String(answerMap[q.id]).length > q.characterLimit) {
        return res.status(400).json({ error: 'validation', message: `Answer for "${q.question_text}" exceeds ${q.characterLimit} characters.` });
      }
      // sanitize
      if (typeof answerMap[q.id] === 'string') answerMap[q.id] = sanitizeText(answerMap[q.id], q.characterLimit || 5000);
    }
    const sanitizedAnswers = answerMap;
    let submissionId;
    if (existing.length > 0) {
      submissionId = existing[0].id;
      await mysql.query('UPDATE survey_responses SET answers_json = ?, status = ?, updated_at = NOW(), is_deleted = 0, deleted_at = NULL WHERE id = ?', [JSON.stringify(sanitizedAnswers), body.status === 'draft' ? 'draft' : 'submitted', submissionId]);
      await mysql.query('UPDATE survey_answers SET is_deleted = 1 WHERE submission_id = ?', [submissionId]);
    } else {
      submissionId = crypto.randomUUID();
      await mysql.query('INSERT INTO survey_responses (id, survey_id, user_id, answers_json, status) VALUES (?, ?, ?, ?, ?)', [submissionId, body.surveyId, req.user.uid, JSON.stringify(sanitizedAnswers), body.status === 'draft' ? 'draft' : 'submitted']);
    }
    // insert normalized answers
    for (const q of questions) {
      const val = sanitizedAnswers[q.id];
      if (val === undefined) continue;
      // check conditional again to skip hidden
      if (q.conditionalParentId) {
        const parentVal = sanitizedAnswers[q.conditionalParentId];
        const trigger = q.conditionalTriggerValue;
        let visible = false;
        if (Array.isArray(parentVal)) visible = parentVal.includes(trigger);
        else visible = String(parentVal ?? '') === String(trigger);
        if (!visible) continue;
      }
      const otherText = customOthers[q.id] || sanitizedAnswers[`${q.id}_other`] || null;
      let answerText = null, answerJson = null;
      if (Array.isArray(val)) {
        answerJson = JSON.stringify(val);
      } else if (typeof val === 'string' && (q.question_type === 'single_select' || q.question_type === 'multi_select' || q.question_type === 'yes_no')) {
        answerText = val;
      } else {
        answerText = String(val);
      }
      await mysql.query(
        'INSERT INTO survey_answers (id, submission_id, question_id, answer_text, answer_json, custom_other_text) VALUES (?, ?, ?, ?, ?, ?)',
        [crypto.randomUUID(), submissionId, q.id, answerText, answerJson, otherText ? sanitizeText(otherText, 500) : null]
      );
    }
    const rows = await mysql.query('SELECT * FROM survey_responses WHERE id = ? LIMIT 1', [submissionId]);
    return res.status(existing.length ? 200 : 201).json(toResponse(rows[0]));
  } catch (err) { return next(err); }
});

module.exports = router;
