-- GradTrack Relational Schema (MySQL 8.0+)
-- Bohol Island State University - Bilar Campus
-- Graduate Tracking and Alumni Management System

CREATE DATABASE IF NOT EXISTS gradtrack_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE gradtrack_db;

-- 1. Departments table
CREATE TABLE IF NOT EXISTS departments (
  id VARCHAR(36) PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Programs / Courses table
CREATE TABLE IF NOT EXISTS courses (
  id VARCHAR(36) PRIMARY KEY,
  department_id VARCHAR(36),
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 3. Core Users table
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(128) PRIMARY KEY, -- Firebase UID or internal UUID
  email VARCHAR(255) NOT NULL UNIQUE,
  full_name VARCHAR(255) NOT NULL,
  role ENUM('admin', 'alumni') NOT NULL DEFAULT 'alumni',
  student_number VARCHAR(64) UNIQUE,
  course_id VARCHAR(36),
  course_name VARCHAR(255),
  section VARCHAR(32),
  graduation_year INT,
  academic_year_graduated VARCHAR(32),
  gender ENUM('Male', 'Female', 'Other', 'PreferNotToSay') DEFAULT 'PreferNotToSay',
  birthdate DATE,
  phone_number VARCHAR(32),
  current_address TEXT,
  permanent_address TEXT,
  biography TEXT,
  photo_url TEXT,
  employment_status ENUM('employed', 'self_employed', 'freelance', 'unemployed', 'studying') DEFAULT 'unemployed',
  is_verified BOOLEAN DEFAULT FALSE,
  is_approved BOOLEAN DEFAULT FALSE,
  disabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE SET NULL,
  INDEX idx_users_role (role),
  INDEX idx_users_year (graduation_year),
  INDEX idx_users_employment (employment_status)
) ENGINE=InnoDB;

-- 4. Employment Records
CREATE TABLE IF NOT EXISTS employment_records (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  company VARCHAR(255) NOT NULL,
  position VARCHAR(255) NOT NULL,
  industry VARCHAR(128),
  employment_type VARCHAR(64),
  salary_range VARCHAR(64),
  location VARCHAR(255),
  work_setup ENUM('on_site', 'remote', 'hybrid') DEFAULT 'on_site',
  date_hired DATE NOT NULL,
  date_resigned DATE,
  is_current BOOLEAN DEFAULT FALSE,
  job_description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_emp_user (user_id),
  INDEX idx_emp_current (is_current)
) ENGINE=InnoDB;

-- 5. Career Milestones
CREATE TABLE IF NOT EXISTS career_milestones (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  type VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  milestone_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_milestone_user (user_id)
) ENGINE=InnoDB;

-- 6. Tracer Study Surveys
CREATE TABLE IF NOT EXISTS surveys (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  target_graduation_year INT,
  questions_json JSON NOT NULL,
  visibility ENUM('public', 'private') DEFAULT 'public',
  is_active BOOLEAN DEFAULT TRUE,
  created_by VARCHAR(128),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_survey_active (is_active)
) ENGINE=InnoDB;

-- 7. Survey Responses
CREATE TABLE IF NOT EXISTS survey_responses (
  id VARCHAR(36) PRIMARY KEY,
  survey_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(128) NOT NULL,
  answers_json JSON NOT NULL,
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_survey_user (survey_id, user_id),
  INDEX idx_response_survey (survey_id)
) ENGINE=InnoDB;

-- 8. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(128),
  action VARCHAR(128) NOT NULL,
  target_resource VARCHAR(128) NOT NULL,
  target_id VARCHAR(128),
  details_json JSON,
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_user (user_id),
  INDEX idx_audit_action (action)
) ENGINE=InnoDB;
