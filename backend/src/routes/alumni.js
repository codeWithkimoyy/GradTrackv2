const express = require('express');
const authenticate = require('../middleware/authenticate');
const { isConnected, query } = require('../config/mysql');
const { db } = require('../config/firebase');

const router = express.Router();

router.use(authenticate);

// GET /api/alumni - List alumni with course and graduation filters
router.get('/', async (req, res, next) => {
  try {
    const { course, year, query: search } = req.query;

    if (isConnected) {
      let sql = `
        SELECT id, full_name, email, course_name, graduation_year, employment_status, is_verified
        FROM users
        WHERE role = 'alumni'
      `;
      const params = [];

      if (course) {
        sql += ' AND course_name = ?';
        params.push(course);
      }
      if (year) {
        sql += ' AND graduation_year = ?';
        params.push(Number(year));
      }
      if (search) {
        sql += ' AND (full_name LIKE ? OR email LIKE ?)';
        params.push(`%${search}%`, `%${search}%`);
      }

      sql += ' ORDER BY graduation_year DESC, full_name ASC LIMIT 50';

      const rows = await query(sql, params);
      return res.json({ source: 'mysql', data: rows });
    }

    // Fallback to Firestore if MySQL is not currently running locally
    if (db) {
      let firestoreQuery = db.collection('users').where('role', '==', 'alumni');
      if (year) {
        firestoreQuery = firestoreQuery.where('graduationYear', '==', Number(year));
      }
      const snapshot = await firestoreQuery.limit(50).get();
      const docs = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
      return res.json({ source: 'firestore_fallback', data: docs });
    }

    return res.status(503).json({
      error: 'database_unavailable',
      message: 'No database connection is currently available.',
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
