/**
 * GradTrack Stored Procedure call wrappers
 * Every table has a CALL sp_* counterpart defined in stored_procedures.sql
 * Usage:
 *   const db = require('../db/procedures');
 *   const rows = await db.users.getById(id);
 *   const created = await db.surveys.create({...});
 *
 * All helpers delegate to mysql.call(procedure, params) which uses pool.query("CALL ...")
 * and normalizes the first resultset.
 */
const mysql = require('../config/mysql');

function toJson(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string') return value;
  try {
    return JSON.stringify(value);
  } catch (_) {
    return null;
  }
}

function coalesceLimit(value, fallback, max) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return Math.min(Math.trunc(n), max);
}

// ---------------------------------------------------------------------------
// departments & courses (no soft-delete)
// ---------------------------------------------------------------------------
const departments = {
  create: (id, code, name) => mysql.call('sp_departments_create', [id, code, name]),
  getById: (id) => mysql.call('sp_departments_get_by_id', [id]),
  getByCode: (code) => mysql.call('sp_departments_get_by_code', [code]),
  list: () => mysql.call('sp_departments_list', []),
  update: (id, code, name) => mysql.call('sp_departments_update', [id, code, name]),
  delete: (id) => mysql.call('sp_departments_delete', [id]),
};

const courses = {
  create: (id, departmentId, code, name) => mysql.call('sp_courses_create', [id, departmentId, code, name]),
  getById: (id) => mysql.call('sp_courses_get_by_id', [id]),
  list: (departmentId = null) => mysql.call('sp_courses_list', [departmentId]),
  update: (id, departmentId, code, name) => mysql.call('sp_courses_update', [id, departmentId, code, name]),
  delete: (id) => mysql.call('sp_courses_delete', [id]),
};

// ---------------------------------------------------------------------------
// users
// ---------------------------------------------------------------------------
const users = {
  create: (data) =>
    mysql.call('sp_users_create', [
      data.id,
      data.email,
      data.password_hash ?? data.passwordHash ?? null,
      data.full_name ?? data.fullName,
      data.role ?? 'alumni',
      data.student_number ?? data.studentNumber ?? null,
      data.alumni_id ?? data.alumniId ?? null,
      data.course_id ?? data.courseId ?? null,
      data.course_name ?? data.courseName ?? null,
      data.section ?? null,
      data.graduation_year ?? data.graduationYear ?? null,
      data.academic_year_graduated ?? data.academicYearGraduated ?? null,
      data.gender ?? 'PreferNotToSay',
      data.birthdate ?? null,
      data.phone_number ?? data.phoneNumber ?? null,
      data.contact_email ?? data.contactEmail ?? null,
      data.current_address ?? data.currentAddress ?? null,
      data.permanent_address ?? data.permanentAddress ?? null,
      data.biography ?? null,
      data.photo_url ?? data.photoUrl ?? null,
      toJson(data.social_links_json ?? data.socialLinks ?? null),
      toJson(data.resume_json ?? data.resume ?? null),
      data.employment_status ?? data.employmentStatus ?? 'unemployed',
      data.is_verified ?? data.isVerified ?? 0,
      data.email_verified ?? data.emailVerified ?? 0,
      data.disabled ?? 0,
      data.is_approved ?? data.isApproved ?? 0,
    ]),
  getById: (id) => mysql.call('sp_users_get_by_id', [id]),
  getByEmail: (email) => mysql.call('sp_users_get_by_email', [email]),
  getByAlumniId: (alumniId) => mysql.call('sp_users_get_by_alumni_id', [alumniId]),
  getByStudentNumber: (sn) => mysql.call('sp_users_get_by_student_number', [sn]),
  listAdmin: (role, approved, search, limit) =>
    mysql.call('sp_users_list_admin', [role || null, approved ?? null, search || null, coalesceLimit(limit, 200, 500)]),
  listAlumni: (course, year, search, limit) =>
    mysql.call('sp_users_list_alumni', [course || null, year ?? null, search || null, coalesceLimit(limit, 50, 200)]),
  exportList: (course, year, status) =>
    mysql.call('sp_users_export', [course || null, year ?? null, status || null]),
  batches: () => mysql.call('sp_users_batches', []),
  updateAdmin: (id, data) =>
    mysql.call('sp_users_update_admin', [
      id,
      data.fullName ?? data.full_name ?? null,
      data.course ?? data.courseName ?? null,
      data.graduationYear ?? data.graduation_year ?? null,
      data.academicYearGraduated ?? data.academic_year_graduated ?? null,
      data.employmentStatus ?? data.employment_status ?? null,
      data.isVerified ?? data.is_verified ?? null,
      data.approved ?? data.is_approved ?? null,
      data.disabled ?? null,
      data.role ?? null,
      data.studentNumber ?? data.student_number ?? null,
      data.section ?? null,
      data.phoneNumber ?? data.phone_number ?? null,
    ]),
  updateProfile: (id, data) =>
    mysql.call('sp_users_update_profile', [
      id,
      data.fullName ?? data.full_name ?? null,
      data.phoneNumber ?? data.phone_number ?? null,
      data.currentAddress ?? data.current_address ?? null,
      data.permanentAddress ?? data.permanent_address ?? null,
      data.biography ?? null,
      data.photoUrl ?? data.photo_url ?? null,
      toJson(data.socialLinks ?? data.social_links_json ?? null),
      data.birthdate ?? null,
      data.gender ?? null,
      data.courseName ?? data.course ?? null,
      data.graduationYear ?? data.graduation_year ?? null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_users_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_users_restore', [id]),
  setEmploymentStatus: (id, status) => mysql.call('sp_users_set_employment_status', [id, status]),
  setResume: (id, resumeJson) => mysql.call('sp_users_set_resume', [id, toJson(resumeJson)]),
  counts: () => mysql.call('sp_users_counts', []),
  pendingApprovals: (limit) => mysql.call('sp_users_pending_approvals', [coalesceLimit(limit, 20, 100)]),
  updateLastLogin: (id, lastLoginAt) => mysql.call('sp_users_update_last_login', [id, lastLoginAt]),
  updatePassword: (id, passwordHash) => mysql.call('sp_users_update_password', [id, passwordHash]),
};

// ---------------------------------------------------------------------------
// alumni_registry
// ---------------------------------------------------------------------------
const alumniRegistry = {
  create: (id, fullName, course, ay, gy, status) =>
    mysql.call('sp_alumni_registry_create', [id, fullName, course, ay, gy, status]),
  upsert: (id, fullName, course, ay, gy) =>
    mysql.call('sp_alumni_registry_upsert', [id, fullName, course, ay, gy]),
  getById: (id) => mysql.call('sp_alumni_registry_get_by_id', [id]),
  list: (status, limit) => mysql.call('sp_alumni_registry_list', [status || null, coalesceLimit(limit, 500, 1000)]),
  update: (id, data) =>
    mysql.call('sp_alumni_registry_update', [
      id,
      data.fullName ?? data.full_name ?? null,
      data.course ?? null,
      data.academicYearGraduated ?? data.academic_year_graduated ?? null,
      data.graduationYear ?? data.graduation_year ?? null,
      data.status ?? null,
      data.activatedAt ?? data.activated_at ?? null,
    ]),
  activate: (id, activatedAt) => mysql.call('sp_alumni_registry_activate', [id, activatedAt]),
  softDelete: (id, deletedAt) => mysql.call('sp_alumni_registry_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_alumni_registry_restore', [id]),
  reactivateDeleted: (id, fullName, course, ay, gy) =>
    mysql.call('sp_alumni_registry_reactivate_deleted', [id, fullName, course, ay, gy]),
};

// ---------------------------------------------------------------------------
// employment_records
// ---------------------------------------------------------------------------
const employmentRecords = {
  create: (data) =>
    mysql.call('sp_employment_create', [
      data.id,
      data.user_id ?? data.userId,
      data.company,
      data.position,
      data.industry ?? null,
      data.employment_type ?? data.employmentType ?? null,
      data.salary_range ?? data.salaryRange ?? null,
      data.date_hired ?? data.dateHired,
      data.end_date ?? data.endDate ?? null,
      data.country ?? null,
      data.province ?? null,
      data.city ?? null,
      data.work_setup ?? data.workSetup ?? 'on_site',
      data.job_description ?? data.jobDescription ?? null,
      data.is_current ?? data.isCurrent ?? 0,
    ]),
  getById: (id) => mysql.call('sp_employment_get_by_id', [id]),
  listByUser: (userId) => mysql.call('sp_employment_list_by_user', [userId]),
  listAll: () => mysql.call('sp_employment_list_all', []),
  update: (id, data) =>
    mysql.call('sp_employment_update', [
      id,
      data.company ?? null,
      data.position ?? null,
      data.industry ?? null,
      data.employment_type ?? data.employmentType ?? null,
      data.salary_range ?? data.salaryRange ?? null,
      data.date_hired ?? data.dateHired ?? null,
      data.end_date ?? data.endDate ?? null,
      data.country ?? null,
      data.province ?? null,
      data.city ?? null,
      data.work_setup ?? data.workSetup ?? null,
      data.job_description ?? data.jobDescription ?? null,
      data.is_current ?? data.isCurrent ?? null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_employment_soft_delete', [id, deletedAt]),
  clearCurrent: (userId, excludeId) => mysql.call('sp_employment_clear_current', [userId, excludeId]),
  restore: (id) => mysql.call('sp_employment_restore', [id]),
};

// ---------------------------------------------------------------------------
// career_milestones
// ---------------------------------------------------------------------------
const careerMilestones = {
  create: (data) =>
    mysql.call('sp_milestones_create', [
      data.id,
      data.user_id ?? data.userId,
      data.type ?? 'firstJob',
      data.title,
      data.description ?? null,
      data.milestone_date ?? data.milestoneDate ?? data.date,
    ]),
  getById: (id) => mysql.call('sp_milestones_get_by_id', [id]),
  listByUser: (userId) => mysql.call('sp_milestones_list_by_user', [userId]),
  softDelete: (id, deletedAt) => mysql.call('sp_milestones_soft_delete', [id, deletedAt]),
  hasAny: (userId) => mysql.call('sp_milestones_has_any', [userId]),
};

// ---------------------------------------------------------------------------
// jobs
// ---------------------------------------------------------------------------
const jobs = {
  create: (data) =>
    mysql.call('sp_jobs_create', [
      data.id,
      data.created_by ?? data.createdBy ?? null,
      data.company ?? '',
      data.job_title ?? data.jobTitle ?? null,
      data.title ?? null,
      data.industry ?? null,
      data.employment_type ?? data.employmentType ?? null,
      data.salary ?? data.salaryRange ?? null,
      data.location ?? data.city ?? null,
      data.work_setup ?? data.workSetup ?? 'on_site',
      data.description ?? data.jobDescription ?? null,
      data.start_date ?? data.startDate ?? data.date_hired ?? data.dateHired ?? null,
      data.end_date ?? data.endDate ?? null,
      data.is_current ?? data.isCurrent ?? 0,
      data.visibility ?? 'public',
    ]),
  getById: (id) => mysql.call('sp_jobs_get_by_id', [id]),
  list: (visibility, limit) => mysql.call('sp_jobs_list', [visibility || null, coalesceLimit(limit, 500, 1000)]),
  listByUser: (userId) => mysql.call('sp_jobs_list_by_user', [userId]),
  update: (id, data) =>
    mysql.call('sp_jobs_update', [
      id,
      data.company ?? null,
      data.job_title ?? data.jobTitle ?? null,
      data.title ?? null,
      data.industry ?? null,
      data.employment_type ?? data.employmentType ?? null,
      data.salary ?? data.salaryRange ?? null,
      data.location ?? data.city ?? null,
      data.work_setup ?? data.workSetup ?? null,
      data.description ?? data.jobDescription ?? null,
      data.start_date ?? data.startDate ?? null,
      data.end_date ?? data.endDate ?? null,
      data.is_current ?? data.isCurrent ?? null,
      data.visibility ?? null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_jobs_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_jobs_restore', [id]),
};

// ---------------------------------------------------------------------------
// surveys
// ---------------------------------------------------------------------------
const surveys = {
  create: (data) =>
    mysql.call('sp_surveys_create', [
      data.id,
      data.title,
      data.description ?? null,
      data.target_graduation_year ?? data.targetGraduationYear ?? data.target_batch_year ?? data.targetBatchYear ?? null,
      data.target_batch_year ?? data.targetBatchYear ?? data.target_graduation_year ?? data.targetGraduationYear ?? null,
      data.opening_date ?? data.openingDate ?? null,
      data.closing_date ?? data.closingDate ?? null,
      data.status ?? 'draft',
      data.allow_update ?? data.allowUpdate ?? 0,
      toJson(data.visible_batches_json ?? data.visibleBatches ?? null),
      toJson(data.questions_json ?? data.questions ?? []),
      data.visibility ?? 'public',
      data.is_active ?? data.isActive ?? 1,
      data.created_by ?? data.createdBy ?? null,
    ]),
  getById: (id) => mysql.call('sp_surveys_get_by_id', [id]),
  list: (visibility, status, isAlumni, graduationYear) =>
    mysql.call('sp_surveys_list', [visibility || null, status || null, isAlumni ? 1 : 0, graduationYear ?? null]),
  listAll: (limit) => mysql.call('sp_surveys_list_all', [coalesceLimit(limit, 500, 1000)]),
  update: (id, data) =>
    mysql.call('sp_surveys_update', [
      id,
      data.title ?? null,
      data.description ?? null,
      data.target_graduation_year ?? data.targetGraduationYear ?? null,
      data.target_batch_year ?? data.targetBatchYear ?? null,
      data.opening_date ?? data.openingDate ?? null,
      data.opening_date === null || data.openingDate === null ? 1 : 0,
      data.closing_date ?? data.closingDate ?? null,
      data.closing_date === null || data.closingDate === null ? 1 : 0,
      data.status ?? null,
      data.allow_update ?? data.allowUpdate ?? null,
      data.visible_batches_json !== undefined || data.visibleBatches !== undefined
        ? toJson(data.visible_batches_json ?? data.visibleBatches)
        : null,
      data.visible_batches_json === null || data.visibleBatches === null
        ? 1
        : 0,
      data.questions_json !== undefined || data.questions !== undefined
        ? toJson(data.questions_json ?? data.questions)
        : null,
      data.visibility ?? null,
      data.is_active ?? data.isActive ?? null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_surveys_soft_delete', [id, deletedAt]),
  updateQuestionsJson: (id, questionsJson) => mysql.call('sp_surveys_update_questions_json', [id, toJson(questionsJson)]),
  count: () => mysql.call('sp_surveys_count', []),
};

// ---------------------------------------------------------------------------
// survey_questions
// ---------------------------------------------------------------------------
const surveyQuestions = {
  create: (data) =>
    mysql.call('sp_survey_questions_create', [
      data.id,
      data.survey_id ?? data.surveyId,
      data.question_text ?? data.questionText ?? data.text,
      data.question_type ?? data.questionType ?? data.type ?? 'short_text',
      data.placeholder ?? null,
      data.character_limit ?? data.characterLimit ?? null,
      data.is_required ?? data.isRequired ?? data.required ?? 0,
      data.is_published ?? data.isPublished ?? 1,
      data.sort_order ?? data.sortOrder ?? 0,
      data.conditional_parent_id ?? data.conditionalParentId ?? null,
      data.conditional_trigger_value ?? data.conditionalTriggerValue ?? null,
      data.allow_other ?? data.allowOther ?? 0,
    ]),
  listBySurvey: (surveyId) => mysql.call('sp_survey_questions_list_by_survey', [surveyId]),
  getById: (id) => mysql.call('sp_survey_questions_get_by_id', [id]),
  softDeleteBySurvey: (surveyId) => mysql.call('sp_survey_questions_soft_delete_by_survey', [surveyId]),
  updateSort: (id, surveyId, sortOrder) => mysql.call('sp_survey_questions_update_sort', [id, surveyId, sortOrder]),
  restore: (id) => mysql.call('sp_survey_questions_restore', [id]),
};

// ---------------------------------------------------------------------------
// survey_question_options
// ---------------------------------------------------------------------------
const surveyQuestionOptions = {
  create: (data) =>
    mysql.call('sp_survey_question_options_create', [
      data.id,
      data.question_id ?? data.questionId,
      data.option_text ?? data.optionText ?? data.text,
      data.sort_order ?? data.sortOrder ?? 0,
      data.is_other ?? data.isOther ?? 0,
    ]),
  listByQuestion: (questionId) => mysql.call('sp_survey_question_options_list_by_question', [questionId]),
  softDeleteByQuestion: (questionId) =>
    mysql.call('sp_survey_question_options_soft_delete_by_question', [questionId]),
};

// ---------------------------------------------------------------------------
// survey_responses
// ---------------------------------------------------------------------------
const surveyResponses = {
  create: (data) =>
    mysql.call('sp_survey_responses_create', [
      data.id,
      data.survey_id ?? data.surveyId,
      data.user_id ?? data.userId,
      toJson(data.answers_json ?? data.answers ?? {}),
      data.status ?? 'submitted',
    ]),
  upsert: (data) =>
    mysql.call('sp_survey_responses_upsert', [
      data.id,
      data.survey_id ?? data.surveyId,
      data.user_id ?? data.userId,
      toJson(data.answers_json ?? data.answers ?? {}),
      data.status ?? 'submitted',
    ]),
  getById: (id) => mysql.call('sp_survey_responses_get_by_id', [id]),
  getBySurveyUser: (surveyId, userId) => mysql.call('sp_survey_responses_get_by_survey_user', [surveyId, userId]),
  listBySurvey: (surveyId, archived) => mysql.call('sp_survey_responses_list_by_survey', [surveyId, archived ?? null]),
  listByUser: (userId) => mysql.call('sp_survey_responses_list_by_user', [userId]),
  update: (id, answersJson, status) => mysql.call('sp_survey_responses_update', [id, toJson(answersJson), status ?? null]),
  setArchived: (id, archived) => mysql.call('sp_survey_responses_set_archived', [id, archived ? 1 : 0]),
  softDelete: (id, deletedAt) => mysql.call('sp_survey_responses_soft_delete', [id, deletedAt]),
  listForExport: (surveyId) => mysql.call('sp_survey_responses_list_for_export', [surveyId]),
  countBySurvey: (surveyId) => mysql.call('sp_survey_responses_count_by_survey', [surveyId]),
};

// ---------------------------------------------------------------------------
// survey_answers
// ---------------------------------------------------------------------------
const surveyAnswers = {
  create: (data) =>
    mysql.call('sp_survey_answers_create', [
      data.id,
      data.submission_id ?? data.submissionId,
      data.question_id ?? data.questionId,
      data.answer_text ?? data.answerText ?? null,
      toJson(data.answer_json ?? data.answerJson ?? null),
      data.custom_other_text ?? data.customOtherText ?? null,
    ]),
  listBySubmission: (submissionId) => mysql.call('sp_survey_answers_list_by_submission', [submissionId]),
  listByQuestion: (questionId) => mysql.call('sp_survey_answers_list_by_question', [questionId]),
  softDeleteBySubmission: (submissionId) => mysql.call('sp_survey_answers_soft_delete_by_submission', [submissionId]),
  upsert: (submissionId, questionId, answerText, answerJson, customOther) =>
    mysql.call('sp_survey_answers_upsert', [submissionId, questionId, answerText, toJson(answerJson), customOther ?? null]),
};

// ---------------------------------------------------------------------------
// announcements
// ---------------------------------------------------------------------------
const announcements = {
  create: (data) =>
    mysql.call('sp_announcements_create', [data.id, data.title, data.description ?? null, data.visibility ?? 'public', data.created_by ?? data.createdBy ?? null]),
  getById: (id) => mysql.call('sp_announcements_get_by_id', [id]),
  list: (visibility, limit) => mysql.call('sp_announcements_list', [visibility || null, coalesceLimit(limit, 500, 1000)]),
  update: (id, data) => mysql.call('sp_announcements_update', [id, data.title ?? null, data.description ?? null, data.visibility ?? null]),
  softDelete: (id, deletedAt) => mysql.call('sp_announcements_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_announcements_restore', [id]),
};

// ---------------------------------------------------------------------------
// events
// ---------------------------------------------------------------------------
const events = {
  create: (data) =>
    mysql.call('sp_events_create', [
      data.id,
      data.title,
      data.description ?? null,
      data.location ?? null,
      data.event_date ?? data.eventDate ?? null,
      data.visibility ?? 'public',
      toJson(data.extra_json ?? data.extraJson ?? null),
      data.created_by ?? data.createdBy ?? null,
    ]),
  getById: (id) => mysql.call('sp_events_get_by_id', [id]),
  list: (visibility, limit) => mysql.call('sp_events_list', [visibility || null, coalesceLimit(limit, 500, 1000)]),
  update: (id, data) =>
    mysql.call('sp_events_update', [
      id,
      data.title ?? null,
      data.description ?? null,
      data.location ?? null,
      data.event_date ?? data.eventDate ?? null,
      data.visibility ?? null,
      data.extra_json !== undefined || data.extraJson !== undefined ? toJson(data.extra_json ?? data.extraJson) : null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_events_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_events_restore', [id]),
};

// ---------------------------------------------------------------------------
// event_registrations
// ---------------------------------------------------------------------------
const eventRegistrations = {
  create: (data) =>
    mysql.call('sp_event_registrations_create', [data.id, data.event_id ?? data.eventId, data.user_id ?? data.userId, data.status ?? 'registered']),
  getById: (id) => mysql.call('sp_event_registrations_get_by_id', [id]),
  listByEvent: (eventId) => mysql.call('sp_event_registrations_list_by_event', [eventId]),
  listByUser: (userId) => mysql.call('sp_event_registrations_list_by_user', [userId]),
  exists: (eventId, userId) => mysql.call('sp_event_registrations_exists', [eventId, userId]),
  updateStatus: (id, status) => mysql.call('sp_event_registrations_update_status', [id, status]),
  softDelete: (id, deletedAt) => mysql.call('sp_event_registrations_soft_delete', [id, deletedAt]),
};

// ---------------------------------------------------------------------------
// reports
// ---------------------------------------------------------------------------
const reports = {
  create: (data) =>
    mysql.call('sp_reports_create', [
      data.id,
      data.type ?? 'general',
      data.title,
      data.period ?? null,
      data.description ?? null,
      toJson(data.data_json ?? data.dataJson ?? null),
      data.created_by ?? data.createdBy ?? null,
    ]),
  getById: (id) => mysql.call('sp_reports_get_by_id', [id]),
  list: (type, limit) => mysql.call('sp_reports_list', [type || null, coalesceLimit(limit, 500, 1000)]),
  update: (id, data) =>
    mysql.call('sp_reports_update', [
      id,
      data.type ?? null,
      data.title ?? null,
      data.period ?? null,
      data.description ?? null,
      data.data_json !== undefined || data.dataJson !== undefined ? toJson(data.data_json ?? data.dataJson) : null,
    ]),
  softDelete: (id, deletedAt) => mysql.call('sp_reports_soft_delete', [id, deletedAt]),
};

// ---------------------------------------------------------------------------
// conversations
// ---------------------------------------------------------------------------
const conversations = {
  upsert: (data) =>
    mysql.call('sp_conversations_upsert', [
      data.id,
      data.alumni_id ?? data.alumniId,
      data.alumni_name ?? data.alumniName ?? 'Alumni',
      data.alumni_email ?? data.alumniEmail ?? '',
      data.alumni_course ?? data.alumniCourse ?? null,
      toJson(data.participant_ids_json ?? data.participantIds ?? []),
      data.last_message ?? data.lastMessage ?? '',
      data.last_message_time ?? data.lastMessageTime ?? new Date().toISOString().slice(0, 19).replace('T', ' '),
      data.last_sender_id ?? data.lastSenderId ?? '',
      data.unread_admin ?? 0,
      data.unread_alumni ?? 0,
    ]),
  getById: (id) => mysql.call('sp_conversations_get_by_id', [id]),
  list: (limit) => mysql.call('sp_conversations_list', [coalesceLimit(limit, 200, 500)]),
  getOwn: (id) => mysql.call('sp_conversations_get_own', [id]),
  markReadAdmin: (id) => mysql.call('sp_conversations_mark_read_admin', [id]),
  markReadAlumni: (id) => mysql.call('sp_conversations_mark_read_alumni', [id]),
  softDelete: (id, deletedAt) => mysql.call('sp_conversations_soft_delete', [id, deletedAt]),
};

// ---------------------------------------------------------------------------
// messages
// ---------------------------------------------------------------------------
const messages = {
  create: (data) =>
    mysql.call('sp_messages_create', [
      data.id,
      data.conversation_id ?? data.conversationId,
      data.sender_id ?? data.senderId ?? '',
      data.sender_name ?? data.senderName ?? 'User',
      data.sender_role ?? data.senderRole ?? 'alumni',
      data.recipient_id ?? data.recipientId ?? null,
      data.user_id ?? data.userId ?? null,
      toJson(data.participant_ids_json ?? data.participantIds ?? null),
      data.text ?? '',
      data.image_url ?? data.imageUrl ?? null,
    ]),
  getById: (id) => mysql.call('sp_messages_get_by_id', [id]),
  listByConversation: (conversationId, limit) =>
    mysql.call('sp_messages_list_by_conversation', [conversationId, coalesceLimit(limit, 500, 1000)]),
  markRead: (conversationId) => mysql.call('sp_messages_mark_read', [conversationId]),
  softDelete: (id, deletedAt) => mysql.call('sp_messages_soft_delete', [id, deletedAt]),
  encryptUpdate: (id, text) => mysql.call('sp_messages_encrypt_update', [id, text]),
};

// ---------------------------------------------------------------------------
// notifications
// ---------------------------------------------------------------------------
const notifications = {
  create: (data) =>
    mysql.call('sp_notifications_create', [
      data.id,
      data.user_id ?? data.userId ?? null,
      data.recipient_role ?? data.recipientRole ?? null,
      data.type ?? 'system',
      data.title ?? '',
      data.description ?? null,
      data.priority ?? 'medium',
      data.link ?? null,
    ]),
  createForAlumniBulk: (type, title, description) =>
    mysql.call('sp_notifications_create_for_alumni_bulk', [type, title, description]),
  getById: (id) => mysql.call('sp_notifications_get_by_id', [id]),
  listByUser: (userId, limit) => mysql.call('sp_notifications_list_by_user', [userId, coalesceLimit(limit, 200, 500)]),
  listByRole: (role, isRead, limit) =>
    mysql.call('sp_notifications_list_by_role', [role || null, isRead ?? null, coalesceLimit(limit, 200, 500)]),
  listUnreadByUser: (userId) => mysql.call('sp_notifications_list_unread_by_user', [userId]),
  markRead: (id) => mysql.call('sp_notifications_mark_read', [id]),
  markAllReadByUser: (userId) => mysql.call('sp_notifications_mark_all_read_by_user', [userId]),
  markAllReadByRole: (role) => mysql.call('sp_notifications_mark_all_read_by_role', [role]),
  softDelete: (id, deletedAt) => mysql.call('sp_notifications_soft_delete', [id, deletedAt]),
  countUnread: (userId) => mysql.call('sp_notifications_count_unread', [userId]),
};

// ---------------------------------------------------------------------------
// certificates
// ---------------------------------------------------------------------------
const certificates = {
  create: (data) =>
    mysql.call('sp_certificates_create', [
      data.id,
      data.user_id ?? data.userId,
      data.title ?? '',
      data.provider ?? 'other',
      data.file_url ?? data.fileUrl,
      data.storage_path ?? data.storagePath,
      data.file_type ?? data.fileType ?? 'image',
      data.issued_date ?? data.issuedDate ?? null,
    ]),
  getById: (id) => mysql.call('sp_certificates_get_by_id', [id]),
  listByUser: (userId) => mysql.call('sp_certificates_list_by_user', [userId]),
  softDelete: (id, deletedAt) => mysql.call('sp_certificates_soft_delete', [id, deletedAt]),
  restore: (id) => mysql.call('sp_certificates_restore', [id]),
};

// ---------------------------------------------------------------------------
// system_settings
// ---------------------------------------------------------------------------
const systemSettings = {
  getByKey: (key) => mysql.call('sp_system_settings_get_by_key', [key]),
  list: () => mysql.call('sp_system_settings_list', []),
  upsert: (key, valueJson) => mysql.call('sp_system_settings_upsert', [key, toJson(valueJson)]),
  delete: (key) => mysql.call('sp_system_settings_delete', [key]),
};

// ---------------------------------------------------------------------------
// audit_logs
// ---------------------------------------------------------------------------
const auditLogs = {
  create: (data) =>
    mysql.call('sp_audit_logs_create', [
      data.id,
      data.user_id ?? data.userId ?? null,
      data.action,
      data.title ?? null,
      data.description ?? null,
      data.actor_id ?? data.actorId ?? null,
      data.actor_name ?? data.actorName ?? null,
      data.actor_role ?? data.actorRole ?? null,
      data.target_id ?? data.targetId ?? null,
      data.target_type ?? data.targetType ?? null,
      data.target_resource ?? data.targetResource ?? null,
      toJson(data.details_json ?? data.detailsJson ?? data.details ?? null),
      data.ip_address ?? data.ipAddress ?? null,
    ]),
  list: (limit, offset) => mysql.call('sp_audit_logs_list', [coalesceLimit(limit, 100, 500), offset ?? 0]),
  listByUser: (userId, limit) => mysql.call('sp_audit_logs_list_by_user', [userId, coalesceLimit(limit, 100, 500)]),
  listByAction: (action, limit) => mysql.call('sp_audit_logs_list_by_action', [action, coalesceLimit(limit, 100, 500)]),
  count: () => mysql.call('sp_audit_logs_count', []),
};

// ---------------------------------------------------------------------------
// password_resets
// ---------------------------------------------------------------------------
const passwordResets = {
  create: (email, userId, code, expiresAt) => mysql.call('sp_password_resets_create', [email, userId ?? null, code, expiresAt]),
  getValid: (email, code) => mysql.call('sp_password_resets_get_valid', [email, code]),
  getByEmail: (email, limit) => mysql.call('sp_password_resets_get_by_email', [email, coalesceLimit(limit, 10, 50)]),
  markUsed: (id) => mysql.call('sp_password_resets_mark_used', [id]),
  cleanupExpired: () => mysql.call('sp_password_resets_cleanup_expired', []),
};

// ---------------------------------------------------------------------------
// auth_sessions
// ---------------------------------------------------------------------------
const authSessions = {
  create: (id, userId, tokenHash, expiresAt) => mysql.call('sp_auth_sessions_create', [id, userId, tokenHash, expiresAt]),
  getByTokenHash: (tokenHash) => mysql.call('sp_auth_sessions_get_by_token_hash', [tokenHash]),
  getByUser: (userId) => mysql.call('sp_auth_sessions_get_by_user', [userId]),
  revokeByUser: (userId) => mysql.call('sp_auth_sessions_revoke_by_user', [userId]),
  revokeByToken: (tokenHash) => mysql.call('sp_auth_sessions_revoke_by_token', [tokenHash]),
  touch: (tokenHash) => mysql.call('sp_auth_sessions_touch', [tokenHash]),
  extend: (tokenHash, expiresAt) => mysql.call('sp_auth_sessions_extend', [tokenHash, expiresAt]),
  deleteExpired: () => mysql.call('sp_auth_sessions_delete_expired', []),
  getValid: (tokenHash) => mysql.call('sp_auth_sessions_get_valid', [tokenHash]),
};

// ---------------------------------------------------------------------------
// stats & content aggregator helpers
// ---------------------------------------------------------------------------
const stats = {
  staff: () => mysql.call('sp_stats_staff', []),
  signupTrend: () => mysql.call('sp_stats_signup_trend', []),
  responseTrend: () => mysql.call('sp_stats_response_trend', []),
  employmentByYear: () => mysql.call('sp_stats_employment_by_year', []),
  employmentByCourse: () => mysql.call('sp_stats_employment_by_course', []),
  batches: () => mysql.call('sp_stats_batches', []),
  surveyProgressCount: (graduationYear, role) => mysql.call('sp_stats_survey_progress_count', [graduationYear ?? null, role ?? null]),
};

// Generic content list via SP (dispatches internally)
const content = {
  list: (table, visibility, limit) => mysql.call('sp_content_list', [table, visibility || null, coalesceLimit(limit, 500, 1000)]),
};

module.exports = {
  mysql, // raw access for fallback queries
  toJson,
  departments,
  courses,
  users,
  alumniRegistry,
  employmentRecords,
  careerMilestones,
  jobs,
  surveys,
  surveyQuestions,
  surveyQuestionOptions,
  surveyResponses,
  surveyAnswers,
  announcements,
  events,
  eventRegistrations,
  reports,
  conversations,
  messages,
  notifications,
  certificates,
  systemSettings,
  auditLogs,
  passwordResets,
  authSessions,
  stats,
  content,
  // direct CALL helper for ad-hoc procedures
  call: (proc, params) => mysql.call(proc, params),
};
