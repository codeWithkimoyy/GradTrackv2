const crypto = require('node:crypto');
const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');
const db = require('../db/procedures');

const router = express.Router();

function isoDate(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

function isoDateTime(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function normalizeWorkSetup(value) {
  const v = String(value ?? '')
    .toLowerCase()
    .replace(/[-_\s]/g, '');
  if (v === 'remote') return 'remote';
  if (v === 'hybrid') return 'hybrid';
  return 'on_site';
}

function toRecord(row) {
  return {
    id: row.id,
    userId: row.user_id,
    company: row.company ?? '',
    position: row.position ?? '',
    industry: row.industry ?? '',
    employmentType: row.employment_type ?? '',
    salaryRange: row.salary_range ?? null,
    dateHired: isoDate(row.date_hired) ?? new Date().toISOString(),
    endDate: isoDate(row.end_date),
    country: row.country ?? '',
    province: row.province ?? null,
    city: row.city ?? '',
    workSetup:
      row.work_setup === 'remote'
        ? 'remote'
        : row.work_setup === 'hybrid'
          ? 'hybrid'
          : 'onSite',
    jobDescription: row.job_description ?? null,
    isCurrent: row.is_current === 1,
    createdAt: isoDateTime(row.created_at) ?? new Date().toISOString(),
  };
}

function toRecordFromJob(row) {
  const endDate = isoDate(row.end_date);
  return {
    id: row.id,
    userId: row.created_by ?? '',
    company: row.company ?? '',
    position: row.job_title ?? row.title ?? '',
    industry: row.industry ?? '',
    employmentType: row.employment_type ?? '',
    salaryRange: row.salary ?? null,
    dateHired: isoDate(row.start_date) ?? new Date().toISOString(),
    endDate,
    country: '',
    province: null,
    city: row.location ?? '',
    workSetup:
      row.work_setup === 'remote'
        ? 'remote'
        : row.work_setup === 'hybrid'
          ? 'hybrid'
          : 'onSite',
    jobDescription: row.description ?? null,
    isCurrent: row.is_current === 1,
    createdAt: isoDateTime(row.created_at) ?? new Date().toISOString(),
  };
}

function toMilestone(row) {
  return {
    id: row.id,
    userId: row.user_id,
    type: row.type,
    title: row.title ?? '',
    description: row.description ?? null,
    date: isoDate(row.milestone_date) ?? new Date().toISOString(),
  };
}

router.use(authenticate);

async function recordsFor(userId) {
  let records, jobs;
  try {
    [records, jobs] = await Promise.all([
      db.employmentRecords.listByUser(userId),
      db.jobs.listByUser(userId),
    ]);
  } catch (_) {
    [records, jobs] = await Promise.all([
      mysql.query('SELECT * FROM employment_records WHERE user_id = ? AND is_deleted = 0', [userId]),
      mysql.query('SELECT * FROM jobs WHERE created_by = ? AND is_deleted = 0', [userId]),
    ]);
  }
  const merged = [
    ...records.map(toRecord),
    ...jobs.map(toRecordFromJob),
  ].sort((a, b) => new Date(b.dateHired) - new Date(a.dateHired));
  return merged;
}

// GET /api/employment/mine
router.get('/mine', async (req, res, next) => {
  try {
    return res.json(await recordsFor(req.user.uid));
  } catch (err) {
    return next(err);
  }
});

// GET /api/employment/all (admin aggregate view)
router.get('/all', requireAdmin, async (req, res, next) => {
  try {
    const [records, jobs] = await Promise.all([
      mysql.query('SELECT * FROM employment_records WHERE is_deleted = 0'),
      mysql.query('SELECT * FROM jobs WHERE is_deleted = 0'),
    ]);
    const merged = [
      ...records.map(toRecord),
      ...jobs.map(toRecordFromJob),
    ].sort((a, b) => new Date(b.dateHired) - new Date(a.dateHired));
    return res.json(merged);
  } catch (err) {
    return next(err);
  }
});

// GET /api/employment/user/:userId (admin viewing one alumnus)
router.get('/user/:userId', requireAdmin, async (req, res, next) => {
  try {
    return res.json(await recordsFor(req.params.userId));
  } catch (err) {
    return next(err);
  }
});

// POST /api/employment
router.post('/', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const userId =
      req.user.role === 'admin' && typeof body.userId === 'string' && body.userId
        ? body.userId
        : req.user.uid;
    if (!body.company || !body.position) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'Company and position are required.',
      });
    }
    const id = crypto.randomUUID();
    const isCurrent = body.isCurrent !== false && !body.endDate;
    try {
      await db.employmentRecords.create({
        id, user_id: userId, company: String(body.company), position: String(body.position),
        industry: body.industry ? String(body.industry) : null,
        employment_type: body.employmentType ? String(body.employmentType) : null,
        salary_range: body.salaryRange ? String(body.salaryRange) : null,
        date_hired: isoDate(body.dateHired) ?? new Date().toISOString().slice(0, 10),
        end_date: isoDate(body.endDate),
        country: body.country ? String(body.country) : null,
        province: body.province ? String(body.province) : null,
        city: body.city ? String(body.city) : null,
        work_setup: normalizeWorkSetup(body.workSetup),
        job_description: body.jobDescription ? String(body.jobDescription) : null,
        is_current: isCurrent ? 1 : 0,
      });
    } catch (_) {
      await mysql.query(
        `INSERT INTO employment_records
           (id, user_id, company, position, industry, employment_type,
            salary_range, date_hired, end_date, country, province, city,
            work_setup, job_description, is_current)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [id, userId, String(body.company), String(body.position), body.industry ? String(body.industry) : null, body.employmentType ? String(body.employmentType) : null, body.salaryRange ? String(body.salaryRange) : null, isoDate(body.dateHired) ?? new Date().toISOString().slice(0, 10), isoDate(body.endDate), body.country ? String(body.country) : null, body.province ? String(body.province) : null, body.city ? String(body.city) : null, normalizeWorkSetup(body.workSetup), body.jobDescription ? String(body.jobDescription) : null, isCurrent ? 1 : 0],
      );
    }

    if (isCurrent) {
      try {
        await db.employmentRecords.clearCurrent(userId, id);
        await db.users.setEmploymentStatus(userId, 'employed');
      } catch (_) {
        await mysql.query('UPDATE employment_records SET is_current = 0 WHERE user_id = ? AND id <> ? AND is_deleted = 0', [userId, id]);
        await mysql.query('UPDATE jobs SET is_current = 0 WHERE created_by = ? AND id <> ? AND is_deleted = 0', [userId, id]);
        await mysql.query("UPDATE users SET employment_status = 'employed' WHERE id = ?", [userId]);
      }
      let existing;
      try { existing = await db.careerMilestones.hasAny(userId); const c = existing[0]?.c ?? existing.length ?? 0; existing = c === 0 ? [] : [{}]; } catch (_) { existing = await mysql.query('SELECT id FROM career_milestones WHERE user_id = ? AND is_deleted = 0 LIMIT 1', [userId]); }
      if (existing.length === 0) {
        try {
          await db.careerMilestones.create({ id: crypto.randomUUID(), user_id: userId, type: 'firstJob', title: `Started at ${body.company}`, description: body.position ? String(body.position) : null, milestone_date: isoDate(body.dateHired) ?? new Date().toISOString().slice(0, 10) });
        } catch (_) {
          await mysql.query(`INSERT INTO career_milestones (id, user_id, type, title, description, milestone_date) VALUES (?, ?, 'firstJob', ?, ?, ?)`, [crypto.randomUUID(), userId, `Started at ${body.company}`, body.position ? String(body.position) : null, isoDate(body.dateHired) ?? new Date().toISOString().slice(0, 10)]);
        }
      }
    }

    let rows;
    try { rows = await db.employmentRecords.getById(id); } catch (_) { rows = await mysql.query('SELECT * FROM employment_records WHERE id = ? LIMIT 1', [id]); }
    return res.status(201).json(toRecord(rows[0]));
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/employment/:id (employment_records first, then jobs)
router.patch('/:id', async (req, res, next) => {
  try {
    const map = {
      company: 'company',
      position: 'position',
      industry: 'industry',
      employmentType: 'employment_type',
      salaryRange: 'salary_range',
      dateHired: 'date_hired',
      endDate: 'end_date',
      country: 'country',
      province: 'province',
      city: 'city',
      workSetup: 'work_setup',
      jobDescription: 'job_description',
      isCurrent: 'is_current',
    };
    const sets = [];
    const params = [];
    for (const [key, value] of Object.entries(req.body ?? {})) {
      if (!map[key]) continue;
      let v = value;
      if (key === 'dateHired' || key === 'endDate') v = isoDate(value);
      if (key === 'workSetup') v = normalizeWorkSetup(value);
      if (key === 'isCurrent') v = value ? 1 : 0;
      sets.push(`\`${map[key]}\` = ?`);
      params.push(v ?? null);
    }
    if (sets.length === 0) {
      return res.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable employment fields.',
      });
    }
    params.push(req.params.id);
    let result = await mysql.query(
      `UPDATE employment_records SET ${sets.join(', ')} WHERE id = ?`,
      params,
    );
    if (result.affectedRows === 0) {
      const jobMap = {
        company: 'company',
        position: 'job_title',
        employmentType: 'employment_type',
        salaryRange: 'salary',
        dateHired: 'start_date',
        endDate: 'end_date',
        city: 'location',
        workSetup: 'work_setup',
        jobDescription: 'description',
        isCurrent: 'is_current',
      };
      const jobSets = [];
      const jobParams = [];
      for (const [key, value] of Object.entries(req.body ?? {})) {
        if (!jobMap[key]) continue;
        let v = value;
        if (key === 'dateHired' || key === 'endDate') v = isoDate(value);
        if (key === 'workSetup') v = normalizeWorkSetup(value);
        if (key === 'isCurrent') v = value ? 1 : 0;
        jobSets.push(`\`${jobMap[key]}\` = ?`);
        jobParams.push(v ?? null);
      }
      if (jobSets.length === 0) {
        return res.status(404).json({
          error: 'not_found',
          message: 'No employment record exists with that id.',
        });
      }
      jobParams.push(req.params.id);
      result = await mysql.query(
        `UPDATE jobs SET ${jobSets.join(', ')} WHERE id = ?`,
        jobParams,
      );
      if (result.affectedRows === 0) {
        return res.status(404).json({
          error: 'not_found',
          message: 'No employment record exists with that id.',
        });
      }
    }
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/employment/:id (soft-delete; no DELETE privilege on host DB)
router.delete('/:id', async (req, res, next) => {
  try {
    let result = await mysql.query(
      'UPDATE employment_records SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
    );
    if (result.affectedRows === 0) {
      result = await mysql.query(
        'UPDATE jobs SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
      );
    }
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No employment record exists with that id.',
      });
    }
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/employment/status { employmentStatus }
router.patch('/status/self', async (req, res, next) => {
  try {
    const allowed = new Set([
      'employed',
      'selfEmployed',
      'freelance',
      'unemployed',
      'studying',
    ]);
    const status = req.body?.employmentStatus;
    if (!allowed.has(status)) {
      return res.status(400).json({
        error: 'invalid_status',
        message: 'Unknown employment status.',
      });
    }
    await mysql.query('UPDATE users SET employment_status = ? WHERE id = ?', [
      status,
      req.user.uid,
    ]);
    return res.json({ updated: true });
  } catch (err) {
    return next(err);
  }
});

// Milestones ---------------------------------------------------------------
router.get('/milestones', async (req, res, next) => {
  try {
    const userId =
      req.user.role === 'admin' && typeof req.query.userId === 'string' && req.query.userId
        ? req.query.userId
        : req.user.uid;
    const rows = await mysql.query(
      'SELECT * FROM career_milestones WHERE user_id = ? AND is_deleted = 0 ORDER BY milestone_date DESC',
      [userId],
    );
    return res.json(rows.map(toMilestone));
  } catch (err) {
    return next(err);
  }
});

router.post('/milestones', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const userId =
      req.user.role === 'admin' && typeof body.userId === 'string' && body.userId
        ? body.userId
        : req.user.uid;
    if (!body.title) {
      return res.status(400).json({
        error: 'missing_fields',
        message: 'Milestone title is required.',
      });
    }
    const id =
      typeof body.id === 'string' && body.id ? body.id : crypto.randomUUID();
    const milestoneParams = [
      id,
      userId,
      typeof body.type === 'string' ? body.type : 'firstJob',
      String(body.title),
      body.description ? String(body.description) : null,
      isoDate(body.date) ?? new Date().toISOString().slice(0, 10),
    ];
    if (mysql.isPostgres) {
      await mysql.query(
        `INSERT INTO career_milestones (id, user_id, type, title, description, milestone_date)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT (id) DO UPDATE SET type = EXCLUDED.type, title = EXCLUDED.title,
           description = EXCLUDED.description, milestone_date = EXCLUDED.milestone_date`,
        milestoneParams,
      );
    } else {
      await mysql.query(
        `INSERT INTO career_milestones (id, user_id, type, title, description, milestone_date)
         VALUES (?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE type = VALUES(type), title = VALUES(title),
           description = VALUES(description), milestone_date = VALUES(milestone_date)`,
        milestoneParams,
      );
    }
    const rows = await mysql.query(
      'SELECT * FROM career_milestones WHERE id = ? LIMIT 1',
      [id],
    );
    return res.status(201).json(toMilestone(rows[0]));
  } catch (err) {
    return next(err);
  }
});

router.delete('/milestones/:id', async (req, res, next) => {
  try {
    const result = await mysql.query(
      'UPDATE career_milestones SET is_deleted = 1, deleted_at = ? WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [new Date().toISOString().slice(0, 19).replace('T', ' '), req.params.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'not_found',
        message: 'No milestone exists with that id.',
      });
    }
    return res.json({ deleted: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
