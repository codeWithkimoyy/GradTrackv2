const express = require('express');
const authenticate = require('../middleware/authenticate');

const { requireAdmin } = authenticate;
const mysql = require('../config/mysql');
const db = require('../db/procedures');

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

// GET /api/stats/staff?adminScope=true — prefers SP sp_stats_* with fallback to raw SQL
router.get('/staff', requireAdmin, async (req, res, next) => {
  try {
    const adminScope = req.query.adminScope !== 'false';
    const userScope = adminScope ? '' : " AND role = 'alumni'";
    const live = 'is_deleted = 0';
    // Try SP path for full admin scope (sp_stats_staff covers exact counts)
    let totalUsers, admins, alumni, verifiedAlumni, employed, selfEmployed, freelance, unemployed, studying, surveyCount, responseCount, eventCount, announcementCount;
    let createdDates, submittedDates, yearRows, courseRows;
    let usedSp = false;
    if (adminScope) {
      try {
        const staffRows = await db.stats.staff();
        const r = staffRows[0] || {};
        totalUsers = Number(r.totalUsers ?? r.total_users ?? 0);
        admins = Number(r.admins ?? 0);
        alumni = Number(r.alumni ?? 0);
        verifiedAlumni = Number(r.verifiedAlumni ?? r.verified_alumni ?? 0);
        employed = Number(r.employed ?? 0);
        selfEmployed = Number(r.selfEmployed ?? r.self_employed ?? 0);
        freelance = Number(r.freelance ?? 0);
        unemployed = Number(r.unemployed ?? 0);
        studying = Number(r.studying ?? 0);
        surveyCount = Number(r.surveyCount ?? r.survey_count ?? 0);
        responseCount = Number(r.responseCount ?? r.response_count ?? 0);
        eventCount = Number(r.eventCount ?? r.event_count ?? 0);
        announcementCount = Number(r.announcementCount ?? r.announcement_count ?? 0);
        // trends via SP helpers
        createdDates = await db.stats.signupTrend();
        submittedDates = await db.stats.responseTrend();
        yearRows = await db.stats.employmentByYear();
        courseRows = await db.stats.employmentByCourse();
        usedSp = true;
      } catch (_) {
        usedSp = false;
      }
    }
    if (!usedSp) {
      [totalUsers, admins, alumni, verifiedAlumni, employed, selfEmployed, freelance, unemployed, studying, surveyCount, responseCount, eventCount, announcementCount, createdDates, submittedDates, yearRows, courseRows] = await Promise.all([
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live}${userScope}`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'admin'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni' AND is_verified = 1`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'employed'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'selfEmployed'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'freelance'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'unemployed'`),
        count(`SELECT COUNT(*) AS c FROM users WHERE ${live} AND employment_status = 'studying'`),
        count('SELECT COUNT(*) AS c FROM surveys WHERE is_deleted = 0'),
        count('SELECT COUNT(*) AS c FROM survey_responses WHERE is_deleted = 0'),
        count('SELECT COUNT(*) AS c FROM events WHERE is_deleted = 0'),
        count('SELECT COUNT(*) AS c FROM announcements WHERE is_deleted = 0'),
        mysql.query(`SELECT created_at FROM users WHERE ${live}`),
        mysql.query('SELECT submitted_at FROM survey_responses WHERE is_deleted = 0'),
        mysql.query(`SELECT graduation_year AS y, employment_status AS s, COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni' AND graduation_year IS NOT NULL GROUP BY graduation_year, employment_status`),
        mysql.query(`SELECT course_name AS course, employment_status AS s, COUNT(*) AS c FROM users WHERE ${live} AND role = 'alumni' AND course_name IS NOT NULL GROUP BY course_name, employment_status`),
      ]);
    }

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

    const byCourse = new Map();
    for (const r of courseRows) {
      const course = String(r.course || '').trim();
      if (!course) continue;
      const entry = byCourse.get(course) ?? { employed: 0, total: 0 };
      const working =
        r.s === 'employed' || r.s === 'selfEmployed' || r.s === 'freelance';
      entry.total += Number(r.c);
      if (working) entry.employed += Number(r.c);
      byCourse.set(course, entry);
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
      employmentByCourse: [...byCourse.entries()]
        .sort((a, b) => b[1].total - a[1].total)
        .map(([course, v]) => ({
          course,
          employedCount: v.employed,
          total: v.total,
          rate: v.total > 0 ? Math.round((v.employed / v.total) * 100) : 0,
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

// GET /api/stats/batches (admin) — prefers SP sp_stats_batches
router.get('/batches', requireAdmin, async (req, res, next) => {
  try {
    let rows;
    try {
      rows = await db.stats.batches();
    } catch (_) {
      rows = await mysql.query(
        `SELECT academic_year_graduated AS ay, graduation_year AS gy, COUNT(*) AS c
         FROM users WHERE role = 'alumni' AND is_deleted = 0
         GROUP BY academic_year_graduated, graduation_year`,
      );
    }
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

// GET /api/stats/pending-approvals?limit=20 (admin) — prefers SP sp_users_pending_approvals
router.get('/pending-approvals', requireAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 20, 100);
    let rows;
    try {
      rows = await db.users.pendingApprovals(limit);
    } catch (_) {
      rows = await mysql.query(
        `SELECT * FROM users WHERE is_approved = 0 AND is_deleted = 0 ORDER BY created_at DESC LIMIT ${limit}`,
      );
    }
    const { toPublicUser } = authenticate;
    res.json(rows.map(toPublicUser));
  } catch (err) {
    return next(err);
  }
});

// GET /api/stats/survey-progress?userId=... — prefers SP sp_stats_survey_progress_count
router.get('/survey-progress', async (req, res, next) => {
  try {
    const userId =
      req.user.role === 'admin' && req.query.userId
        ? String(req.query.userId)
        : req.user.uid;
    // Alumni are scoped by batch, so the total only counts the surveys that user can see.
    let userRows;
    try {
      userRows = await db.users.getById(userId);
    } catch (_) {
      userRows = await mysql.query('SELECT role, graduation_year FROM users WHERE id = ? LIMIT 1', [userId]);
    }
    const user = userRows[0];
    let surveys, responses;
    try {
      const sRows = await db.stats.surveyProgressCount(user?.graduation_year ?? null, user?.role ?? null);
      surveys = Number(sRows[0]?.c ?? sRows[0]?.count ?? 0);
      const rRows = await mysql.call('sp_survey_responses_count_by_survey', [null]).catch(() =>
        mysql.query('SELECT COUNT(*) AS c FROM survey_responses WHERE user_id = ? AND is_deleted = 0', [userId]).then((r) => r),
      );
      // Simpler: count responses via direct helper
      responses = await count('SELECT COUNT(*) AS c FROM survey_responses WHERE user_id = ? AND is_deleted = 0', [userId]);
    } catch (_) {
      let surveySql = 'SELECT COUNT(*) AS c FROM surveys WHERE is_deleted = 0';
      const surveyParams = [];
      if (user && user.role === 'alumni') {
        if (user.graduation_year === null || user.graduation_year === undefined) {
          surveySql += ' AND (visible_batches_json IS NULL OR JSON_LENGTH(visible_batches_json) = 0)';
        } else {
          surveySql += ' AND (visible_batches_json IS NULL' + ' OR JSON_LENGTH(visible_batches_json) = 0' + ' OR JSON_CONTAINS(visible_batches_json, CAST(? AS JSON)))';
          surveyParams.push(user.graduation_year);
        }
      }
      [surveys, responses] = await Promise.all([
        count(surveySql, surveyParams),
        count('SELECT COUNT(*) AS c FROM survey_responses WHERE user_id = ? AND is_deleted = 0', [userId]),
      ]);
    }
    res.json({ completed: responses, total: surveys });
  } catch (err) {
    return next(err);
  }
});

// GET /api/stats/announcements?publicOnly=true — prefers SP sp_announcements_list
router.get('/announcements', async (req, res, next) => {
  try {
    const publicOnly = req.query.publicOnly === 'true' || req.query.publicOnly === '1';
    let rows;
    try {
      rows = await db.announcements.list(publicOnly ? 'public' : null, 500);
    } catch (_) {
      rows = await mysql.query(
        publicOnly
          ? "SELECT * FROM announcements WHERE is_deleted = 0 AND visibility = 'public' ORDER BY created_at DESC"
          : 'SELECT * FROM announcements WHERE is_deleted = 0 ORDER BY created_at DESC',
      );
    }
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
