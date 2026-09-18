-- GradTrack Relational Schema (MySQL 5.7+ / MariaDB 10.2+)
-- Bohol Island State University - Bilar Campus
-- Graduate Tracking and Alumni Management System
--
-- Single source of truth after the Firebase -> MySQL migration.
-- JSON API of the backend exposes camelCase keys; column names stay
-- snake_case and the translation lives in the route layer.

-- The connection already selects the target database (SQL_DATABASE /
-- MYSQL_DATABASE, e.g. `bisublar_gt` on shared hosting), so no
-- CREATE DATABASE / USE statements here. The migrate runner connects
-- directly to that database.

-- 1. Departments table
CREATE TABLE IF NOT EXISTS departments (
  id VARCHAR(36) PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Programs / Courses table
CREATE TABLE IF NOT EXISTS courses (
  id VARCHAR(36) PRIMARY KEY,
  department_id VARCHAR(36),
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 3. Core Users table (replaces Firestore `users` + Firebase Auth identity)
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(128) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NULL,
  full_name VARCHAR(255) NOT NULL,
  role ENUM('admin', 'alumni') NOT NULL DEFAULT 'alumni',
  student_number VARCHAR(64) NULL UNIQUE,
  alumni_id VARCHAR(64) NULL UNIQUE,
  course_id VARCHAR(36),
  course_name VARCHAR(255),
  section VARCHAR(32),
  graduation_year INT NULL,
  academic_year_graduated VARCHAR(32),
  gender ENUM('Male', 'Female', 'Other', 'PreferNotToSay') DEFAULT 'PreferNotToSay',
  birthdate DATE NULL,
  phone_number VARCHAR(32),
  current_address TEXT,
  permanent_address TEXT,
  biography TEXT,
  photo_url MEDIUMTEXT,
  social_links_json JSON NULL,
  resume_json JSON NULL,
  employment_status ENUM('employed', 'selfEmployed', 'freelance', 'unemployed', 'studying') DEFAULT 'unemployed',
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  email_verified TINYINT(1) NOT NULL DEFAULT 0,
  disabled TINYINT(1) NOT NULL DEFAULT 0,
  is_approved TINYINT(1) NOT NULL DEFAULT 0,
  has_logged_in TINYINT(1) NOT NULL DEFAULT 0,
  last_login_at DATETIME NULL,
  profile_completion DOUBLE NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE SET NULL,
  INDEX idx_users_role (role),
  INDEX idx_users_year (graduation_year),
  INDEX idx_users_employment (employment_status),
  INDEX idx_users_approved (is_approved),
  INDEX idx_users_alumni (alumni_id),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 4. Alumni registry (replaces Firestore `alumni_registry`).
-- Office pre-registers IDs; alumni activate Pending -> Active on signup.
CREATE TABLE IF NOT EXISTS alumni_registry (
  id VARCHAR(64) PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  course VARCHAR(255) NOT NULL DEFAULT 'BS Computer Science',
  academic_year_graduated VARCHAR(32) NULL,
  graduation_year INT NULL,
  status ENUM('pending', 'active', 'disabled') NOT NULL DEFAULT 'pending',
  activated_at DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_registry_status (status),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 5. Employment Records (replaces Firestore `employment_records`)
CREATE TABLE IF NOT EXISTS employment_records (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
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
  work_setup ENUM('remote', 'hybrid', 'on_site') DEFAULT 'on_site',
  job_description TEXT,
  is_current TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_emp_user (user_id),
  INDEX idx_emp_current (is_current),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 6. Career Milestones (replaces Firestore `career_milestones`)
CREATE TABLE IF NOT EXISTS career_milestones (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  type VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  milestone_date DATE NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_milestone_user (user_id),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 7. Job postings + alumni-submitted job entries (replaces Firestore `jobs`,
-- the shared store where alumni record employment and staff post openings)
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
  work_setup ENUM('remote', 'hybrid', 'on_site') DEFAULT 'on_site',
  description TEXT,
  start_date DATE NULL,
  end_date DATE NULL,
  is_current TINYINT(1) NOT NULL DEFAULT 0,
  visibility ENUM('public', 'private') DEFAULT 'public',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_jobs_created (created_by),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 8. Tracer Study Surveys (replaces Firestore `surveys`)
CREATE TABLE IF NOT EXISTS surveys (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  target_graduation_year INT NULL,
  visible_batches_json JSON NULL,
  questions_json JSON NOT NULL,
  visibility ENUM('public', 'private') DEFAULT 'public',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by VARCHAR(128),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_survey_active (is_active),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 9. Survey Responses (replaces Firestore `survey_responses`)
CREATE TABLE IF NOT EXISTS survey_responses (
  id VARCHAR(36) PRIMARY KEY,
  survey_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(128) NOT NULL,
  answers_json JSON NOT NULL,
  submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_survey_user (survey_id, user_id),
  INDEX idx_response_survey (survey_id),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 10. Announcements (replaces Firestore `announcements`)
CREATE TABLE IF NOT EXISTS announcements (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  visibility ENUM('public', 'private') DEFAULT 'public',
  created_by VARCHAR(128),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_ann_created (created_at),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 11. Events (replaces Firestore `events`)
CREATE TABLE IF NOT EXISTS events (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  location VARCHAR(255),
  event_date DATETIME NULL,
  visibility ENUM('public', 'private') DEFAULT 'public',
  extra_json JSON NULL,
  created_by VARCHAR(128),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_event_created (created_at),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 12. Event registrations (replaces Firestore `event_registrations`)
CREATE TABLE IF NOT EXISTS event_registrations (
  id VARCHAR(36) PRIMARY KEY,
  event_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(128) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'registered',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_event_user (event_id, user_id),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 13. Reports (replaces Firestore `reports`)
CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(36) PRIMARY KEY,
  type VARCHAR(64) NOT NULL DEFAULT 'general',
  title VARCHAR(255) NOT NULL,
  period VARCHAR(64),
  description TEXT,
  data_json JSON NULL,
  created_by VARCHAR(128),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_report_created (created_at),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 14. Conversations (replaces Firestore `conversations`, id conv_<alumniId>)
CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(128) PRIMARY KEY,
  alumni_id VARCHAR(64) NOT NULL,
  alumni_name VARCHAR(255) NOT NULL DEFAULT 'Alumni',
  alumni_email VARCHAR(255) NOT NULL DEFAULT '',
  alumni_course VARCHAR(255),
  participant_ids_json JSON NULL,
  last_message TEXT,
  last_message_time DATETIME NULL,
  last_sender_id VARCHAR(128),
  unread_admin INT NOT NULL DEFAULT 0,
  unread_alumni INT NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_conv_updated (last_message_time),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 15. Chat messages (replaces Firestore `messages`)
CREATE TABLE IF NOT EXISTS messages (
  id VARCHAR(36) PRIMARY KEY,
  conversation_id VARCHAR(128) NOT NULL,
  sender_id VARCHAR(128) NOT NULL DEFAULT '',
  sender_name VARCHAR(255) NOT NULL DEFAULT 'User',
  sender_role VARCHAR(32) NOT NULL DEFAULT 'alumni',
  recipient_id VARCHAR(128),
  user_id VARCHAR(128),
  participant_ids_json JSON NULL,
  text MEDIUMTEXT NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  INDEX idx_msg_conv (conversation_id, created_at),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 16. Notifications (replaces Firestore `notifications`)
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NULL,
  recipient_role ENUM('admin', 'alumni') NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'system',
  title VARCHAR(255) NOT NULL DEFAULT '',
  description TEXT,
  priority ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'medium',
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  link TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notif_user (user_id, created_at),
  INDEX idx_notif_role (recipient_role, is_read),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 17. Certificates (replaces Firestore `certificates`)
CREATE TABLE IF NOT EXISTS certificates (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  title VARCHAR(255) NOT NULL DEFAULT '',
  provider ENUM('tesda', 'google', 'cisco', 'aws', 'microsoft', 'oracle', 'other') NOT NULL DEFAULT 'other',
  file_url TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_type VARCHAR(16) NOT NULL DEFAULT 'image',
  issued_date DATE NULL,
  uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_cert_user (user_id, uploaded_at),
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 18. System settings (replaces Firestore `system_settings` docs)
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(128) PRIMARY KEY,
  value_json JSON NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 19. Audit Logs (replaces Firestore `audit_logs`; append-only)
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
  details_json JSON,
  ip_address VARCHAR(45),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_user (user_id),
  INDEX idx_audit_action (action),
  INDEX idx_audit_created (created_at)
) ENGINE=InnoDB;

-- 20. Password reset codes (replaces Firestore `password_resets`)
CREATE TABLE IF NOT EXISTS password_resets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  user_id VARCHAR(128),
  code CHAR(6) NOT NULL,
  expires_at DATETIME NOT NULL,
  used TINYINT(1) NOT NULL DEFAULT 0,
  used_at DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_reset_email (email, created_at)
) ENGINE=InnoDB;

-- 21. Auth sessions (opaque bearer tokens replacing Firebase ID tokens)
CREATE TABLE IF NOT EXISTS auth_sessions (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  last_used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  revoked TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_session_user (user_id)
) ENGINE=InnoDB;
