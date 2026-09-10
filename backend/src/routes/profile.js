const express = require('express');
const authenticate = require('../middleware/authenticate');
const { db } = require('../config/firebase');

const router = express.Router();

const editableFields = new Set([
  'fullName',
  'photoUrl',
  'studentNumber',
  'gender',
  'birthdate',
  'phoneNumber',
  'currentAddress',
  'permanentAddress',
  'graduationYear',
  'course',
  'section',
  'biography',
  'socialLinks',
  'employmentStatus',
  'academicYearGraduated',
]);

router.use(authenticate);

router.get('/', async (request, response, next) => {
  try {
    const snapshot = await db.collection('users').doc(request.user.uid).get();
    if (!snapshot.exists) {
      return response.status(404).json({
        error: 'profile_not_found',
        message: 'No GradTrack profile exists for this account.',
      });
    }
    return response.json({ id: snapshot.id, ...snapshot.data() });
  } catch (error) {
    return next(error);
  }
});

router.patch('/', async (request, response, next) => {
  try {
    const changes = Object.fromEntries(
      Object.entries(request.body ?? {}).filter(([key]) => editableFields.has(key)),
    );

    if (Object.keys(changes).length === 0) {
      return response.status(400).json({
        error: 'no_editable_fields',
        message: 'The request does not contain editable profile fields.',
      });
    }

    changes.updatedAt = new Date();
    await db.collection('users').doc(request.user.uid).set(changes, {
      merge: true,
    });
    return response.json({ updated: true });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
