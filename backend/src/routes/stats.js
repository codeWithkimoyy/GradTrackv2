const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');

const router = express.Router();

function iso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

router.use(authenticate);

async function count(sql, params = []) {
  const rows = await mysql.query(sql, params);
  return Number(rows[0]?.c ?? 0);
}

// GET /api/stats/staff?adminScope=true
router.get('/staff', requireAdmin, async (req, res, next) => {
  try {
    const adminScope = req.query.adminScope !== 'false';
    const userScope = adminScope ? '' : " AND role = 'alumni'";
    const live = 'is_deleted = 0';
    const [
      totalUsers,
      admins,
      alumni,
      verifiedAlumni,
      employed,
      selfEmployed,
      freelance,
      unemployed,
      studying,
      surveyCount,
      responseCount,
      eventCount,
      announcementCount,
      createdDates,
      submittedDates,
      yearRows,
    ] = await Promise.all([
      count(`SELECT COUNT(*) AS c FROM users WHERE ${live}${userScope}`),
      count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'admin'`),
      count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni'`),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni' AND is_verified = 1`,
      ),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'employed'`,
      ),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'selfEmployed'`,
      ),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'freelance'`,
      ),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'unemployed'`,
      ),
      count(
        `SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'studying'`,
      ),
      count('SELECT COUNT(*) AS c FROM surveys WHERE is_deleted = 0'),
      count('SELECT COUNT(*) AS c FROM survey_responses WHERE is_deleted = 0'),
      count('SELECT COUNT(*) AS c FROM events WHERE is_deleted = 0'),
      count('SELECT COUNT(*) AS c FROM announcements WHERE is_deleted = 0'),
      mysql.query(`SELECT created_at FROM users WHERE ${live}`),
      mysql.query(
        'SELECT submitted_at FROM survey_responses WHERE is_deleted = 0',
      ),
      mysql.query(
        `SELECT graduation_year AS y, employment_status AS s, COUNT(*) AS c
         FROM users WHERE ${live} AND role = 'alumni' AND graduation_year IS NOT NULL
         GROUP BY graduation_year, employment_status`,
      ),
    ]);

    const byYear = new Map();
    for (const r of yearRows) {
      const year = Number(r.y);
      if (!Number.isFinite(year)) continue;
      const entry = byYear.get(year) ?? { employed: 0, total: 0 };
      const working =
        r.s === 'employed' || r.s === 'selfEmployed' || r.s === 'freelance';
      entry.total += Number(r.c);
      if (working) entry.employed += Number(r.c);
      byYear.set(year, entry);
    }

    res.json({
      totalUsers,
      admins,
      alumni,
      verifiedAlumni,
      pendingAlumni: Math.max(0, Math.min(alumni, alumni - verifiedAlumni)),
      employed,
      selfEmployed,
      freelance,
      unemployed,
      studying,
      surveyCount,
      responseCount,
      eventCount,
      announcementCount,
      signupTrend: monthlyTrend(createdDates.map((r) => r.created_at)),
      responseTrend: monthlyTrend(submittedDates.map((r) => r.submitted_at)),
      employmentByYear: [...byYear.entries()]
        .sort((a, b) => a[0] - b[0])
        .map(([year, v]) => ({
          year,
          employedCount: v.employed,
          total: v.total,
        })),
    });
  } catch (err) {
    return next(err);
  }
});

function monthlyTrend(dates) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - 11, 1);
  const months = Array.from({ length: 12 }, (_, i) => ({
    month: new Date(start.getFullYear(), start.getMonth() + i, 1).toISOString(),
    count: 0,
  }));
  for (const value of dates) {
    const d = value ? new Date(value) : null;
    if (!d || Number.isNaN(d.getTime())) continue;
    const idx =
      (d.getFullYear() * 12 + d.getMonth()) -
      (start.getFullYear() * 12 + start.getMonth());
    if (idx < 0 || idx > 11) continue;
    months[idx].count += 1;
  }
  return months;
}

// GET /api/stats/batches (admin)
router.get('/batches', requireAdmin, async (req, res, next) => {
  try {
    const rows = await mysql.query(
      `SELECT academic_year_graduated AS ay, graduation_year AS gy, COUNT(*) AS c
       FROM users WHERE role = 'alumni' AND is_deleted = 0
       GROUP BY academic_year_graduated, graduation_year`,
    );
    const counts = new Map();
    for (const r of rows) {
      const key =
        r.ay && String(r.ay).trim()
          ? String(r.ay).trim()
          : r.gy !== null && r.gy !== undefined
            ? `gy:${r.gy}`
            : '';
      counts.set(key, (counts.get(key) ?? 0) + Number(r.c));
    }
    res.json(
      [...counts.entries()].map(([academicYear, batchCount]) => ({
        academicYear,
        count: batchCount,
      })),
    );
  } catch (err) {
    return next(err);
  }
});

// GET /api/stats/pending-approvals?limit=20 (admin)
router.get('/pending-approvals', requireAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 20, 100);
    const rows = await mysql.query(
      `SELECT * FROM users WHERE is_approved = 0 AND is_deleted = 0 ORDER BY created_at DESC LIMIT ${limit}`,
    );
    const { toPublicUser } = authenticate;
    res.json(rows.map(toPublicUser));
  } catch (err) {
    return next(err);
  }
});

// GET /api/stats/survey-progress?userId=...
router.get('/survey-progress', async (req, res, next) => {
  try {
    const userId =
      req.user.role === 'admin' && req.query.userId
        ? String(req.query.userId)
        : req.user.uid;
    // Alumni are scoped by batch, so the total only counts the surveys
    // that user is actually able to see and answer.
    const userRows = await mysql.query(
      'SELECT role, graduation_year FROM users WHERE id = ? LIMIT 1',
      [userId],
    );
    const user = userRows[0];
    let surveySql =
      'SELECT COUNT(*) AS c FROM surveys WHERE is_deleted = 0';
    const surveyParams = [];
    if (user && user.role === 'alumni') {
      if (user.graduation_year === null || user.graduation_year === undefined) {
        surveySql +=
          ' AND (visible_batches_json IS NULL OR JSON_LENGTH(visible_batches_json) = 0)';
      } else {
        surveySql +=
          ' AND (visible_batches_json IS NULL' +
          ' OR JSON_LENGTH(visible_batches_json) = 0' +
          ' OR JSON_CONTAINS(visible_batches_json, CAST(? AS JSON)))';
        surveyParams.push(user.graduation_year);
      }
    }
    const [surveys, responses] = await Promise.all([
      count(surveySql, surveyParams),
      count(
        'SELECT COUNT(*) AS c FROM survey_responses WHERE user_id = ? AND is_deleted = 0',
        [userId],
      ),
    ]);
    res.json({ completed: responses, total: surveys });
  } catch (err) {
    return next(err);
  }
});

// GET /api/stats/announcements?publicOnly=true
router.get('/announcements', async (req, res, next) => {
  try {
    const publicOnly =
      req.query.publicOnly === 'true' || req.query.publicOnly === '1';
    const rows = await mysql.query(
      publicOnly
        ? "SELECT * FROM announcements WHERE is_deleted = 0 AND visibility = 'public' ORDER BY created_at DESC"
        : 'SELECT * FROM announcements WHERE is_deleted = 0 ORDER BY created_at DESC',
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        title: r.title ?? '',
        description: r.description ?? null,
        visibility: r.visibility ?? 'public',
        createdBy: r.created_by ?? null,
        createdAt: iso(r.created_at) ?? new Date().toISOString(),
        updatedAt: iso(r.updated_at),
      })),
    );
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
