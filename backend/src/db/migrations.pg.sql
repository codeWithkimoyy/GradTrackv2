-- GradTrack Relational Schema (PostgreSQL / Neon)
-- Translated from src/db/migrations.sql (MySQL 5.7+).
--
-- Design choices for Neon compatibility with the existing Express routes:
--   * MySQL TINYINT(1) flags -> SMALLINT 0/1 (pg returns numbers, so the
--     `row.flag === 1` checks in routes keep working).
--   * MySQL ENUM -> TEXT + CHECK constraints.
--   * MySQL DATETIME -> TIMESTAMPTZ with NOW() defaults.
--   * MySQL JSON -> JSONB.
--   * `updated_at` auto-touch via trigger (replaces ON UPDATE CURRENT_TIMESTAMP).
-- Run with: npm run migrate:neon   (uses DATABASE_URL)

-- Auto-touch trigger for updated_at columns.
CREATE OR REPLACE FUNCTION gradtrack_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Departments
CREATE TABLE IF NOT EXISTS departments (
  id VARCHAR(36) PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Programs / Courses
CREATE TABLE IF NOT EXISTS courses (
  id VARCHAR(36) PRIMARY KEY,
  department_id VARCHAR(36) REFERENCES departments(id) ON DELETE SET NULL,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Core users
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(128) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NULL,
  full_name VARCHAR(255) NOT NULL,
  role TEXT NOT NULL DEFAULT 'alumni' CHECK (role IN ('admin', 'alumni')),
  student_number VARCHAR(64) NULL UNIQUE,
  alumni_id VARCHAR(64) NULL UNIQUE,
  course_id VARCHAR(36) REFERENCES courses(id) ON DELETE SET NULL,
  course_name VARCHAR(255),
  section VARCHAR(32),
  graduation_year INTEGER NULL,
  academic_year_graduated VARCHAR(32),
  gender TEXT NOT NULL DEFAULT 'PreferNotToSay'
    CHECK (gender IN ('Male', 'Female', 'Other', 'PreferNotToSay')),
  birthdate DATE NULL,
  phone_number VARCHAR(32),
  contact_email VARCHAR(255) NULL,
  current_address TEXT,
  permanent_address TEXT,
  biography TEXT,
  photo_url TEXT,
  social_links_json JSONB NULL,
  resume_json JSONB NULL,
  employment_status TEXT NOT NULL DEFAULT 'unemployed'
    CHECK (employment_status IN ('employed', 'selfEmployed', 'freelance', 'unemployed', 'studying')),
  is_verified SMALLINT NOT NULL DEFAULT 0,
  email_verified SMALLINT NOT NULL DEFAULT 0,
  disabled SMALLINT NOT NULL DEFAULT 0,
  is_approved SMALLINT NOT NULL DEFAULT 0,
  has_logged_in SMALLINT NOT NULL DEFAULT 0,
  last_login_at TIMESTAMPTZ NULL,
  profile_completion DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_year ON users (graduation_year);
CREATE INDEX IF NOT EXISTS idx_users_employment ON users (employment_status);
CREATE INDEX IF NOT EXISTS idx_users_approved ON users (is_approved);
CREATE INDEX IF NOT EXISTS idx_users_alumni ON users (alumni_id);

-- 4. Alumni registry
CREATE TABLE IF NOT EXISTS alumni_registry (
  id VARCHAR(64) PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  course VARCHAR(255) NOT NULL DEFAULT 'BS Computer Science',
  academic_year_graduated VARCHAR(32) NULL,
  graduation_year INTEGER NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'disabled')),
  activated_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_registry_status ON alumni_registry (status);

-- 5. Employment records
CREATE TABLE IF NOT EXISTS employment_records (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company VARCHAR(255) NOT NULL,
  position VARCHAR(255) NOT NULL,
  industry VARCHAR(128),
  employment_type VARCHAR(64),
  salary_range VARCHAR(64),
  date_hired DATE NOT NULL,
  end_date DATE NULL,
  country VARCHAR(128),
  province VARCHAR(128),
  city VARCHAR(128),
  work_setup TEXT NOT NULL DEFAULT 'on_site'
    CHECK (work_setup IN ('remote', 'hybrid', 'on_site')),
  job_description TEXT,
  is_current SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_emp_user ON employment_records (user_id);
CREATE INDEX IF NOT EXISTS idx_emp_current ON employment_records (is_current);

-- 6. Career milestones
CREATE TABLE IF NOT EXISTS career_milestones (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  milestone_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_milestone_user ON career_milestones (user_id);

-- 7. Jobs
CREATE TABLE IF NOT EXISTS jobs (
  id VARCHAR(36) PRIMARY KEY,
  created_by VARCHAR(128) NULL,
  company VARCHAR(255) NOT NULL DEFAULT '',
  job_title VARCHAR(255) NULL,
  title VARCHAR(255) NULL,
  industry VARCHAR(128),
  employment_type VARCHAR(64),
  salary VARCHAR(64),
  location VARCHAR(255),
  work_setup TEXT NOT NULL DEFAULT 'on_site'
    CHECK (work_setup IN ('remote', 'hybrid', 'on_site')),
  description TEXT,
  start_date DATE NULL,
  end_date DATE NULL,
  is_current SMALLINT NOT NULL DEFAULT 0,
  visibility TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON jobs (created_by);

-- 8. Surveys
CREATE TABLE IF NOT EXISTS surveys (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  target_graduation_year INTEGER NULL,
  target_batch_year INTEGER NULL,
  opening_date TIMESTAMPTZ NULL,
  closing_date TIMESTAMPTZ NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'closed')),
  allow_update SMALLINT NOT NULL DEFAULT 0,
  visible_batches_json JSONB NULL,
  questions_json JSONB NOT NULL DEFAULT '[]',
  visibility TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),
  is_active SMALLINT NOT NULL DEFAULT 1,
  created_by VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_survey_active ON surveys (is_active);
CREATE INDEX IF NOT EXISTS idx_survey_status ON surveys (status);

-- 8b. Survey questions
CREATE TABLE IF NOT EXISTS survey_questions (
  id VARCHAR(36) PRIMARY KEY,
  survey_id VARCHAR(36) NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL DEFAULT 'short_text'
    CHECK (question_type IN ('short_text', 'long_text', 'single_select', 'multi_select', 'yes_no', 'number', 'date')),
  placeholder VARCHAR(255) NULL,
  character_limit INTEGER NULL,
  is_required SMALLINT NOT NULL DEFAULT 0,
  is_published SMALLINT NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  conditional_parent_id VARCHAR(36) NULL,
  conditional_trigger_value TEXT NULL,
  allow_other SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_sq_survey ON survey_questions (survey_id, sort_order);

-- 8c. Question options
CREATE TABLE IF NOT EXISTS survey_question_options (
  id VARCHAR(36) PRIMARY KEY,
  question_id VARCHAR(36) NOT NULL REFERENCES survey_questions(id) ON DELETE CASCADE,
  option_text VARCHAR(255) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_other SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_sqo_question ON survey_question_options (question_id, sort_order);

-- 9. Survey responses
CREATE TABLE IF NOT EXISTS survey_responses (
  id VARCHAR(36) PRIMARY KEY,
  survey_id VARCHAR(36) NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  answers_json JSONB NOT NULL DEFAULT '{}',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_archived SMALLINT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('draft', 'submitted')),
  UNIQUE (survey_id, user_id),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_response_survey ON survey_responses (survey_id);
CREATE INDEX IF NOT EXISTS idx_response_archived ON survey_responses (is_archived);

-- 9b. Normalized answers
CREATE TABLE IF NOT EXISTS survey_answers (
  id VARCHAR(36) PRIMARY KEY,
  submission_id VARCHAR(36) NOT NULL REFERENCES survey_responses(id) ON DELETE CASCADE,
  question_id VARCHAR(36) NOT NULL REFERENCES survey_questions(id) ON DELETE CASCADE,
  answer_text TEXT NULL,
  answer_json JSONB NULL,
  custom_other_text VARCHAR(500) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (submission_id, question_id),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_sa_question ON survey_answers (question_id);

-- 10. Announcements
CREATE TABLE IF NOT EXISTS announcements (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  visibility TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),
  created_by VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_ann_created ON announcements (created_at);

-- 11. Events
CREATE TABLE IF NOT EXISTS events (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  location VARCHAR(255),
  event_date TIMESTAMPTZ NULL,
  visibility TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),
  extra_json JSONB NULL,
  created_by VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_event_created ON events (created_at);

-- 12. Event registrations
CREATE TABLE IF NOT EXISTS event_registrations (
  id VARCHAR(36) PRIMARY KEY,
  event_id VARCHAR(36) NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(32) NOT NULL DEFAULT 'registered',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (event_id, user_id),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);

-- 13. Reports
CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(36) PRIMARY KEY,
  type VARCHAR(64) NOT NULL DEFAULT 'general',
  title VARCHAR(255) NOT NULL,
  period VARCHAR(64),
  description TEXT,
  data_json JSONB NULL,
  created_by VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_report_created ON reports (created_at);

-- 14. Conversations
CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(128) PRIMARY KEY,
  alumni_id VARCHAR(64) NOT NULL,
  alumni_name VARCHAR(255) NOT NULL DEFAULT 'Alumni',
  alumni_email VARCHAR(255) NOT NULL DEFAULT '',
  alumni_course VARCHAR(255),
  participant_ids_json JSONB NULL,
  last_message TEXT,
  last_message_time TIMESTAMPTZ NULL,
  last_sender_id VARCHAR(128),
  unread_admin INTEGER NOT NULL DEFAULT 0,
  unread_alumni INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_conv_updated ON conversations (last_message_time);

-- 15. Chat messages
CREATE TABLE IF NOT EXISTS messages (
  id VARCHAR(36) PRIMARY KEY,
  conversation_id VARCHAR(128) NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id VARCHAR(128) NOT NULL DEFAULT '',
  sender_name VARCHAR(255) NOT NULL DEFAULT 'User',
  sender_role VARCHAR(32) NOT NULL DEFAULT 'alumni',
  recipient_id VARCHAR(128),
  user_id VARCHAR(128),
  participant_ids_json JSONB NULL,
  text TEXT NOT NULL,
  image_url TEXT NULL,
  is_read SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages (conversation_id, created_at);

-- 16. Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NULL,
  recipient_role TEXT NULL CHECK (recipient_role IN ('admin', 'alumni')),
  type VARCHAR(32) NOT NULL DEFAULT 'system',
  title VARCHAR(255) NOT NULL DEFAULT '',
  description TEXT,
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  is_read SMALLINT NOT NULL DEFAULT 0,
  link TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notif_role ON notifications (recipient_role, is_read);

-- 17. Certificates
CREATE TABLE IF NOT EXISTS certificates (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL DEFAULT '',
  provider TEXT NOT NULL DEFAULT 'other'
    CHECK (provider IN ('tesda', 'google', 'cisco', 'aws', 'microsoft', 'oracle', 'other')),
  file_url TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_type VARCHAR(16) NOT NULL DEFAULT 'image',
  issued_date DATE NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_cert_user ON certificates (user_id, uploaded_at);

-- 18. System settings
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(128) PRIMARY KEY,
  value_json JSONB NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 19. Audit logs (append-only)
CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128),
  action VARCHAR(128) NOT NULL,
  title VARCHAR(255),
  description TEXT,
  actor_id VARCHAR(128),
  actor_name VARCHAR(255),
  actor_role VARCHAR(32),
  target_id VARCHAR(128),
  target_type VARCHAR(128),
  target_resource VARCHAR(128),
  details_json JSONB,
  ip_address VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs (created_at);

-- 20. Password reset codes
CREATE TABLE IF NOT EXISTS password_resets (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  user_id VARCHAR(128),
  code CHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used SMALLINT NOT NULL DEFAULT 0,
  used_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reset_email ON password_resets (email, created_at);

-- 21. Auth sessions
CREATE TABLE IF NOT EXISTS auth_sessions (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_session_user ON auth_sessions (user_id);

-- Attach updated_at triggers (idempotent).
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users', 'alumni_registry', 'employment_records', 'jobs',
    'surveys', 'survey_questions', 'survey_question_options',
    'survey_responses', 'survey_answers', 'announcements', 'events',
    'reports', 'conversations', 'system_settings'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = 'trg_touch_' || t
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER trg_touch_%I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION gradtrack_touch_updated_at()',
        t, t
      );
    END IF;
  END LOOP;
END
$$;
