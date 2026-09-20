-- GradTrack Stored Procedures (MySQL 5.7+ / MariaDB 10.2+)
-- Auto-generated for every table in migrations.sql
-- Called via CALL sp_<table>_<action>(...)
-- Applied by src/db/migrate.js after migrations.sql

-- ============================================================
-- 1. departments
-- ============================================================
DROP PROCEDURE IF EXISTS sp_departments_create;
CREATE PROCEDURE sp_departments_create(
  IN p_id VARCHAR(36),
  IN p_code VARCHAR(20),
  IN p_name VARCHAR(255)
)
BEGIN
  INSERT INTO departments (id, code, name) VALUES (p_id, p_code, p_name);
  SELECT * FROM departments WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_departments_get_by_id;
CREATE PROCEDURE sp_departments_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM departments WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_departments_get_by_code;
CREATE PROCEDURE sp_departments_get_by_code(IN p_code VARCHAR(20))
BEGIN
  SELECT * FROM departments WHERE code = p_code LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_departments_list;
CREATE PROCEDURE sp_departments_list()
BEGIN
  SELECT * FROM departments ORDER BY name ASC;
END;

DROP PROCEDURE IF EXISTS sp_departments_update;
CREATE PROCEDURE sp_departments_update(
  IN p_id VARCHAR(36),
  IN p_code VARCHAR(20),
  IN p_name VARCHAR(255)
)
BEGIN
  UPDATE departments SET
    code = COALESCE(p_code, code),
    name = COALESCE(p_name, name)
  WHERE id = p_id;
  SELECT * FROM departments WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_departments_delete;
CREATE PROCEDURE sp_departments_delete(IN p_id VARCHAR(36))
BEGIN
  DELETE FROM departments WHERE id = p_id;
END;

-- ============================================================
-- 2. courses
-- ============================================================
DROP PROCEDURE IF EXISTS sp_courses_create;
CREATE PROCEDURE sp_courses_create(
  IN p_id VARCHAR(36),
  IN p_department_id VARCHAR(36),
  IN p_code VARCHAR(20),
  IN p_name VARCHAR(255)
)
BEGIN
  INSERT INTO courses (id, department_id, code, name) VALUES (p_id, p_department_id, p_code, p_name);
  SELECT * FROM courses WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_courses_get_by_id;
CREATE PROCEDURE sp_courses_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM courses WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_courses_list;
CREATE PROCEDURE sp_courses_list(IN p_department_id VARCHAR(36))
BEGIN
  IF p_department_id IS NULL OR p_department_id = '' THEN
    SELECT * FROM courses ORDER BY name ASC;
  ELSE
    SELECT * FROM courses WHERE department_id = p_department_id ORDER BY name ASC;
  END IF;
END;

DROP PROCEDURE IF EXISTS sp_courses_update;
CREATE PROCEDURE sp_courses_update(
  IN p_id VARCHAR(36),
  IN p_department_id VARCHAR(36),
  IN p_code VARCHAR(20),
  IN p_name VARCHAR(255)
)
BEGIN
  UPDATE courses SET
    department_id = COALESCE(p_department_id, department_id),
    code = COALESCE(p_code, code),
    name = COALESCE(p_name, name)
  WHERE id = p_id;
  SELECT * FROM courses WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_courses_delete;
CREATE PROCEDURE sp_courses_delete(IN p_id VARCHAR(36))
BEGIN
  DELETE FROM courses WHERE id = p_id;
END;

-- ============================================================
-- 3. users
-- ============================================================
DROP PROCEDURE IF EXISTS sp_users_create;
CREATE PROCEDURE sp_users_create(
  IN p_id VARCHAR(128),
  IN p_email VARCHAR(255),
  IN p_password_hash VARCHAR(255),
  IN p_full_name VARCHAR(255),
  IN p_role ENUM('admin','alumni'),
  IN p_student_number VARCHAR(64),
  IN p_alumni_id VARCHAR(64),
  IN p_course_id VARCHAR(36),
  IN p_course_name VARCHAR(255),
  IN p_section VARCHAR(32),
  IN p_graduation_year INT,
  IN p_academic_year_graduated VARCHAR(32),
  IN p_gender ENUM('Male','Female','Other','PreferNotToSay'),
  IN p_birthdate DATE,
  IN p_phone_number VARCHAR(32),
  IN p_contact_email VARCHAR(255),
  IN p_current_address TEXT,
  IN p_permanent_address TEXT,
  IN p_biography TEXT,
  IN p_photo_url MEDIUMTEXT,
  IN p_social_links_json JSON,
  IN p_resume_json JSON,
  IN p_employment_status ENUM('employed','selfEmployed','freelance','unemployed','studying'),
  IN p_is_verified TINYINT,
  IN p_email_verified TINYINT,
  IN p_disabled TINYINT,
  IN p_is_approved TINYINT
)
BEGIN
  INSERT INTO users (
    id, email, password_hash, full_name, role, student_number, alumni_id,
    course_id, course_name, section, graduation_year, academic_year_graduated,
    gender, birthdate, phone_number, contact_email, current_address, permanent_address,
    biography, photo_url, social_links_json, resume_json, employment_status,
    is_verified, email_verified, disabled, is_approved
  ) VALUES (
    p_id, p_email, p_password_hash, p_full_name, p_role, p_student_number, p_alumni_id,
    p_course_id, p_course_name, p_section, p_graduation_year, p_academic_year_graduated,
    p_gender, p_birthdate, p_phone_number, p_contact_email, p_current_address, p_permanent_address,
    p_biography, p_photo_url, p_social_links_json, p_resume_json, p_employment_status,
    COALESCE(p_is_verified,0), COALESCE(p_email_verified,0), COALESCE(p_disabled,0), COALESCE(p_is_approved,0)
  );
  SELECT * FROM users WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_get_by_id;
CREATE PROCEDURE sp_users_get_by_id(IN p_id VARCHAR(128))
BEGIN
  SELECT * FROM users WHERE id = p_id AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_get_by_email;
CREATE PROCEDURE sp_users_get_by_email(IN p_email VARCHAR(255))
BEGIN
  SELECT * FROM users WHERE email = p_email AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_get_by_alumni_id;
CREATE PROCEDURE sp_users_get_by_alumni_id(IN p_alumni_id VARCHAR(64))
BEGIN
  SELECT * FROM users WHERE alumni_id = p_alumni_id AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_get_by_student_number;
CREATE PROCEDURE sp_users_get_by_student_number(IN p_student_number VARCHAR(64))
BEGIN
  SELECT * FROM users WHERE student_number = p_student_number AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_list_admin;
CREATE PROCEDURE sp_users_list_admin(
  IN p_role VARCHAR(16),
  IN p_approved TINYINT,
  IN p_search VARCHAR(255),
  IN p_limit INT
)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit, 200), 500);
  SELECT id, email, full_name, role, student_number, alumni_id, course_name,
         section, graduation_year, academic_year_graduated, gender, birthdate,
         phone_number, current_address, permanent_address, biography, photo_url,
         social_links_json, resume_json, employment_status, is_verified,
         email_verified, disabled, is_approved, has_logged_in, last_login_at,
         profile_completion, created_at, updated_at
  FROM users
  WHERE is_deleted = 0
    AND (p_role IS NULL OR p_role = '' OR role = p_role)
    AND (p_approved IS NULL OR is_approved = p_approved)
    AND (p_search IS NULL OR p_search = '' OR full_name LIKE CONCAT('%', p_search, '%') OR email LIKE CONCAT('%', p_search, '%') OR alumni_id LIKE CONCAT('%', p_search, '%'))
  ORDER BY created_at DESC
  LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_users_list_alumni;
CREATE PROCEDURE sp_users_list_alumni(
  IN p_course VARCHAR(255),
  IN p_year INT,
  IN p_search VARCHAR(255),
  IN p_limit INT
)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit, 50), 200);
  SELECT id, full_name, email, course_name, graduation_year,
         employment_status, is_verified, is_approved, disabled,
         academic_year_graduated, alumni_id, created_at
  FROM users
  WHERE role = 'alumni' AND is_deleted = 0
    AND (p_course IS NULL OR p_course = '' OR course_name = p_course)
    AND (p_year IS NULL OR graduation_year = p_year)
    AND (p_search IS NULL OR p_search = '' OR full_name LIKE CONCAT('%', p_search, '%') OR email LIKE CONCAT('%', p_search, '%') OR alumni_id LIKE CONCAT('%', p_search, '%'))
  ORDER BY graduation_year DESC, full_name ASC
  LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_users_export;
CREATE PROCEDURE sp_users_export(
  IN p_course VARCHAR(255),
  IN p_year INT,
  IN p_status VARCHAR(32)
)
BEGIN
  SELECT alumni_id, full_name, email, phone_number, course_name, section,
         graduation_year, academic_year_graduated, employment_status,
         is_verified, is_approved, created_at
  FROM users
  WHERE role = 'alumni' AND is_deleted = 0
    AND (p_course IS NULL OR p_course = '' OR course_name = p_course)
    AND (p_year IS NULL OR graduation_year = p_year)
    AND (p_status IS NULL OR p_status = '' OR employment_status = p_status)
  ORDER BY graduation_year DESC, full_name ASC;
END;

DROP PROCEDURE IF EXISTS sp_users_batches;
CREATE PROCEDURE sp_users_batches()
BEGIN
  SELECT DISTINCT graduation_year AS yr
  FROM users
  WHERE role = 'alumni' AND is_deleted = 0 AND graduation_year IS NOT NULL
  ORDER BY graduation_year DESC;
END;

DROP PROCEDURE IF EXISTS sp_users_update_admin;
CREATE PROCEDURE sp_users_update_admin(
  IN p_id VARCHAR(128),
  IN p_full_name VARCHAR(255),
  IN p_course_name VARCHAR(255),
  IN p_graduation_year INT,
  IN p_academic_year_graduated VARCHAR(32),
  IN p_employment_status ENUM('employed','selfEmployed','freelance','unemployed','studying'),
  IN p_is_verified TINYINT,
  IN p_is_approved TINYINT,
  IN p_disabled TINYINT,
  IN p_role ENUM('admin','alumni'),
  IN p_student_number VARCHAR(64),
  IN p_section VARCHAR(32),
  IN p_phone_number VARCHAR(32)
)
BEGIN
  UPDATE users SET
    full_name = COALESCE(p_full_name, full_name),
    course_name = COALESCE(p_course_name, course_name),
    graduation_year = COALESCE(p_graduation_year, graduation_year),
    academic_year_graduated = COALESCE(p_academic_year_graduated, academic_year_graduated),
    employment_status = COALESCE(p_employment_status, employment_status),
    is_verified = COALESCE(p_is_verified, is_verified),
    is_approved = COALESCE(p_is_approved, is_approved),
    disabled = COALESCE(p_disabled, disabled),
    role = COALESCE(p_role, role),
    student_number = COALESCE(p_student_number, student_number),
    section = COALESCE(p_section, section),
    phone_number = COALESCE(p_phone_number, phone_number)
  WHERE id = p_id AND is_deleted = 0;
  SELECT * FROM users WHERE id = p_id AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_update_profile;
CREATE PROCEDURE sp_users_update_profile(
  IN p_id VARCHAR(128),
  IN p_full_name VARCHAR(255),
  IN p_phone_number VARCHAR(32),
  IN p_current_address TEXT,
  IN p_permanent_address TEXT,
  IN p_biography TEXT,
  IN p_photo_url MEDIUMTEXT,
  IN p_social_links_json JSON,
  IN p_birthdate DATE,
  IN p_gender ENUM('Male','Female','Other','PreferNotToSay'),
  IN p_course_name VARCHAR(255),
  IN p_graduation_year INT
)
BEGIN
  UPDATE users SET
    full_name = COALESCE(p_full_name, full_name),
    phone_number = COALESCE(p_phone_number, phone_number),
    current_address = COALESCE(p_current_address, current_address),
    permanent_address = COALESCE(p_permanent_address, permanent_address),
    biography = COALESCE(p_biography, biography),
    photo_url = COALESCE(p_photo_url, photo_url),
    social_links_json = COALESCE(p_social_links_json, social_links_json),
    birthdate = COALESCE(p_birthdate, birthdate),
    gender = COALESCE(p_gender, gender),
    course_name = COALESCE(p_course_name, course_name),
    graduation_year = COALESCE(p_graduation_year, graduation_year)
  WHERE id = p_id AND is_deleted = 0;
  SELECT * FROM users WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_users_soft_delete;
CREATE PROCEDURE sp_users_soft_delete(
  IN p_id VARCHAR(128),
  IN p_deleted_at DATETIME
)
BEGIN
  UPDATE users SET is_deleted = 1, deleted_at = p_deleted_at WHERE id = p_id AND is_deleted = 0;
  UPDATE auth_sessions SET revoked = 1 WHERE user_id = p_id;
END;

DROP PROCEDURE IF EXISTS sp_users_restore;
CREATE PROCEDURE sp_users_restore(IN p_id VARCHAR(128))
BEGIN
  UPDATE users SET is_deleted = 0, deleted_at = NULL WHERE id = p_id AND is_deleted = 1;
END;

DROP PROCEDURE IF EXISTS sp_users_set_employment_status;
CREATE PROCEDURE sp_users_set_employment_status(
  IN p_id VARCHAR(128),
  IN p_status ENUM('employed','selfEmployed','freelance','unemployed','studying')
)
BEGIN
  UPDATE users SET employment_status = p_status WHERE id = p_id AND is_deleted = 0;
END;

DROP PROCEDURE IF EXISTS sp_users_set_resume;
CREATE PROCEDURE sp_users_set_resume(
  IN p_id VARCHAR(128),
  IN p_resume_json JSON
)
BEGIN
  UPDATE users SET resume_json = p_resume_json WHERE id = p_id AND is_deleted = 0;
END;

DROP PROCEDURE IF EXISTS sp_users_counts;
CREATE PROCEDURE sp_users_counts()
BEGIN
  SELECT
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0) AS totalUsers,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND role='admin') AS admins,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND role='alumni') AS alumni,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND role='alumni' AND is_verified=1) AS verifiedAlumni,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND employment_status='employed') AS employed,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND employment_status='selfEmployed') AS selfEmployed,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND employment_status='freelance') AS freelance,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND employment_status='unemployed') AS unemployed,
    (SELECT COUNT(*) FROM users WHERE is_deleted = 0 AND employment_status='studying') AS studying;
END;

DROP PROCEDURE IF EXISTS sp_users_pending_approvals;
CREATE PROCEDURE sp_users_pending_approvals(IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,20),100);
  SELECT * FROM users WHERE is_approved = 0 AND is_deleted = 0 ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_users_update_last_login;
CREATE PROCEDURE sp_users_update_last_login(
  IN p_id VARCHAR(128),
  IN p_last_login_at DATETIME
)
BEGIN
  UPDATE users SET last_login_at = p_last_login_at, has_logged_in = 1 WHERE id = p_id AND is_deleted = 0;
END;

DROP PROCEDURE IF EXISTS sp_users_update_password;
CREATE PROCEDURE sp_users_update_password(
  IN p_id VARCHAR(128),
  IN p_password_hash VARCHAR(255)
)
BEGIN
  UPDATE users SET password_hash = p_password_hash WHERE id = p_id AND is_deleted = 0;
END;

-- ============================================================
-- 4. alumni_registry
-- ============================================================
DROP PROCEDURE IF EXISTS sp_alumni_registry_create;
CREATE PROCEDURE sp_alumni_registry_create(
  IN p_id VARCHAR(64),
  IN p_full_name VARCHAR(255),
  IN p_course VARCHAR(255),
  IN p_academic_year_graduated VARCHAR(32),
  IN p_graduation_year INT,
  IN p_status ENUM('pending','active','disabled')
)
BEGIN
  INSERT INTO alumni_registry (id, full_name, course, academic_year_graduated, graduation_year, status)
  VALUES (p_id, p_full_name, COALESCE(p_course,'BS Computer Science'), p_academic_year_graduated, p_graduation_year, COALESCE(p_status,'pending'));
  SELECT * FROM alumni_registry WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_upsert;
CREATE PROCEDURE sp_alumni_registry_upsert(
  IN p_id VARCHAR(64),
  IN p_full_name VARCHAR(255),
  IN p_course VARCHAR(255),
  IN p_academic_year_graduated VARCHAR(32),
  IN p_graduation_year INT
)
BEGIN
  INSERT INTO alumni_registry (id, full_name, course, academic_year_graduated, graduation_year, status)
  VALUES (p_id, p_full_name, COALESCE(p_course,'BS Computer Science'), p_academic_year_graduated, p_graduation_year, 'pending')
  ON DUPLICATE KEY UPDATE
    full_name = VALUES(full_name),
    course = VALUES(course),
    academic_year_graduated = VALUES(academic_year_graduated),
    graduation_year = VALUES(graduation_year),
    is_deleted = 0, deleted_at = NULL;
  SELECT * FROM alumni_registry WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_get_by_id;
CREATE PROCEDURE sp_alumni_registry_get_by_id(IN p_id VARCHAR(64))
BEGIN
  SELECT * FROM alumni_registry WHERE id = p_id AND is_deleted = 0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_list;
CREATE PROCEDURE sp_alumni_registry_list(IN p_status VARCHAR(16), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM alumni_registry
  WHERE is_deleted = 0
    AND (p_status IS NULL OR p_status='' OR status = p_status)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_update;
CREATE PROCEDURE sp_alumni_registry_update(
  IN p_id VARCHAR(64),
  IN p_full_name VARCHAR(255),
  IN p_course VARCHAR(255),
  IN p_academic_year_graduated VARCHAR(32),
  IN p_graduation_year INT,
  IN p_status ENUM('pending','active','disabled'),
  IN p_activated_at DATETIME
)
BEGIN
  UPDATE alumni_registry SET
    full_name = COALESCE(p_full_name, full_name),
    course = COALESCE(p_course, course),
    academic_year_graduated = COALESCE(p_academic_year_graduated, academic_year_graduated),
    graduation_year = COALESCE(p_graduation_year, graduation_year),
    status = COALESCE(p_status, status),
    activated_at = COALESCE(p_activated_at, activated_at),
    is_deleted = 0, deleted_at = NULL
  WHERE id = p_id AND is_deleted = 0;
  SELECT * FROM alumni_registry WHERE id = p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_activate;
CREATE PROCEDURE sp_alumni_registry_activate(
  IN p_id VARCHAR(64),
  IN p_activated_at DATETIME
)
BEGIN
  UPDATE alumni_registry SET status='active', activated_at = COALESCE(p_activated_at, NOW()) WHERE id = p_id AND is_deleted = 0;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_soft_delete;
CREATE PROCEDURE sp_alumni_registry_soft_delete(
  IN p_id VARCHAR(64),
  IN p_deleted_at DATETIME
)
BEGIN
  UPDATE alumni_registry SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_restore;
CREATE PROCEDURE sp_alumni_registry_restore(IN p_id VARCHAR(64))
BEGIN
  UPDATE alumni_registry SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

DROP PROCEDURE IF EXISTS sp_alumni_registry_reactivate_deleted;
CREATE PROCEDURE sp_alumni_registry_reactivate_deleted(
  IN p_id VARCHAR(64),
  IN p_full_name VARCHAR(255),
  IN p_course VARCHAR(255),
  IN p_academic_year_graduated VARCHAR(32),
  IN p_graduation_year INT
)
BEGIN
  UPDATE alumni_registry SET
    full_name = p_full_name,
    course = COALESCE(p_course,'BS Computer Science'),
    academic_year_graduated = p_academic_year_graduated,
    graduation_year = p_graduation_year,
    status='pending', activated_at=NULL,
    is_deleted=0, deleted_at=NULL
  WHERE id=p_id;
END;

-- ============================================================
-- 5. employment_records
-- ============================================================
DROP PROCEDURE IF EXISTS sp_employment_create;
CREATE PROCEDURE sp_employment_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_company VARCHAR(255),
  IN p_position VARCHAR(255),
  IN p_industry VARCHAR(128),
  IN p_employment_type VARCHAR(64),
  IN p_salary_range VARCHAR(64),
  IN p_date_hired DATE,
  IN p_end_date DATE,
  IN p_country VARCHAR(128),
  IN p_province VARCHAR(128),
  IN p_city VARCHAR(128),
  IN p_work_setup ENUM('remote','hybrid','on_site'),
  IN p_job_description TEXT,
  IN p_is_current TINYINT
)
BEGIN
  INSERT INTO employment_records
    (id, user_id, company, position, industry, employment_type, salary_range, date_hired, end_date, country, province, city, work_setup, job_description, is_current)
  VALUES (p_id, p_user_id, p_company, p_position, p_industry, p_employment_type, p_salary_range, p_date_hired, p_end_date, p_country, p_province, p_city, COALESCE(p_work_setup,'on_site'), p_job_description, COALESCE(p_is_current,0));
  SELECT * FROM employment_records WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_employment_get_by_id;
CREATE PROCEDURE sp_employment_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM employment_records WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_employment_list_by_user;
CREATE PROCEDURE sp_employment_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM employment_records WHERE user_id=p_user_id AND is_deleted=0 ORDER BY date_hired DESC;
END;

DROP PROCEDURE IF EXISTS sp_employment_list_all;
CREATE PROCEDURE sp_employment_list_all()
BEGIN
  SELECT * FROM employment_records WHERE is_deleted=0 ORDER BY created_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_employment_update;
CREATE PROCEDURE sp_employment_update(
  IN p_id VARCHAR(36),
  IN p_company VARCHAR(255),
  IN p_position VARCHAR(255),
  IN p_industry VARCHAR(128),
  IN p_employment_type VARCHAR(64),
  IN p_salary_range VARCHAR(64),
  IN p_date_hired DATE,
  IN p_end_date DATE,
  IN p_country VARCHAR(128),
  IN p_province VARCHAR(128),
  IN p_city VARCHAR(128),
  IN p_work_setup ENUM('remote','hybrid','on_site'),
  IN p_job_description TEXT,
  IN p_is_current TINYINT
)
BEGIN
  UPDATE employment_records SET
    company = COALESCE(p_company, company),
    position = COALESCE(p_position, position),
    industry = COALESCE(p_industry, industry),
    employment_type = COALESCE(p_employment_type, employment_type),
    salary_range = COALESCE(p_salary_range, salary_range),
    date_hired = COALESCE(p_date_hired, date_hired),
    end_date = COALESCE(p_end_date, end_date),
    country = COALESCE(p_country, country),
    province = COALESCE(p_province, province),
    city = COALESCE(p_city, city),
    work_setup = COALESCE(p_work_setup, work_setup),
    job_description = COALESCE(p_job_description, job_description),
    is_current = COALESCE(p_is_current, is_current)
  WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_employment_soft_delete;
CREATE PROCEDURE sp_employment_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE employment_records SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_employment_clear_current;
CREATE PROCEDURE sp_employment_clear_current(IN p_user_id VARCHAR(128), IN p_exclude_id VARCHAR(36))
BEGIN
  UPDATE employment_records SET is_current=0 WHERE user_id=p_user_id AND id <> p_exclude_id AND is_deleted=0;
  UPDATE jobs SET is_current=0 WHERE created_by=p_user_id AND id <> p_exclude_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_employment_restore;
CREATE PROCEDURE sp_employment_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE employment_records SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

-- ============================================================
-- 6. career_milestones
-- ============================================================
DROP PROCEDURE IF EXISTS sp_milestones_create;
CREATE PROCEDURE sp_milestones_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_type VARCHAR(64),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_milestone_date DATE
)
BEGIN
  INSERT INTO career_milestones (id, user_id, type, title, description, milestone_date)
  VALUES (p_id, p_user_id, p_type, p_title, p_description, p_milestone_date)
  ON DUPLICATE KEY UPDATE type=VALUES(type), title=VALUES(title), description=VALUES(description), milestone_date=VALUES(milestone_date), is_deleted=0, deleted_at=NULL;
  SELECT * FROM career_milestones WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_milestones_get_by_id;
CREATE PROCEDURE sp_milestones_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM career_milestones WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_milestones_list_by_user;
CREATE PROCEDURE sp_milestones_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM career_milestones WHERE user_id=p_user_id AND is_deleted=0 ORDER BY milestone_date DESC;
END;

DROP PROCEDURE IF EXISTS sp_milestones_soft_delete;
CREATE PROCEDURE sp_milestones_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE career_milestones SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_milestones_has_any;
CREATE PROCEDURE sp_milestones_has_any(IN p_user_id VARCHAR(128))
BEGIN
  SELECT COUNT(*) AS c FROM career_milestones WHERE user_id=p_user_id AND is_deleted=0;
END;

-- ============================================================
-- 7. jobs
-- ============================================================
DROP PROCEDURE IF EXISTS sp_jobs_create;
CREATE PROCEDURE sp_jobs_create(
  IN p_id VARCHAR(36),
  IN p_created_by VARCHAR(128),
  IN p_company VARCHAR(255),
  IN p_job_title VARCHAR(255),
  IN p_title VARCHAR(255),
  IN p_industry VARCHAR(128),
  IN p_employment_type VARCHAR(64),
  IN p_salary VARCHAR(64),
  IN p_location VARCHAR(255),
  IN p_work_setup ENUM('remote','hybrid','on_site'),
  IN p_description TEXT,
  IN p_start_date DATE,
  IN p_end_date DATE,
  IN p_is_current TINYINT,
  IN p_visibility ENUM('public','private')
)
BEGIN
  INSERT INTO jobs (id, created_by, company, job_title, title, industry, employment_type, salary, location, work_setup, description, start_date, end_date, is_current, visibility)
  VALUES (p_id, p_created_by, COALESCE(p_company,''), p_job_title, p_title, p_industry, p_employment_type, p_salary, p_location, COALESCE(p_work_setup,'on_site'), p_description, p_start_date, p_end_date, COALESCE(p_is_current,0), COALESCE(p_visibility,'public'));
  SELECT * FROM jobs WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_jobs_get_by_id;
CREATE PROCEDURE sp_jobs_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM jobs WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_jobs_list;
CREATE PROCEDURE sp_jobs_list(IN p_visibility VARCHAR(16), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM jobs
  WHERE is_deleted=0
    AND (p_visibility IS NULL OR p_visibility='' OR visibility=p_visibility)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_jobs_list_by_user;
CREATE PROCEDURE sp_jobs_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM jobs WHERE created_by=p_user_id AND is_deleted=0 ORDER BY created_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_jobs_update;
CREATE PROCEDURE sp_jobs_update(
  IN p_id VARCHAR(36),
  IN p_company VARCHAR(255),
  IN p_job_title VARCHAR(255),
  IN p_title VARCHAR(255),
  IN p_industry VARCHAR(128),
  IN p_employment_type VARCHAR(64),
  IN p_salary VARCHAR(64),
  IN p_location VARCHAR(255),
  IN p_work_setup ENUM('remote','hybrid','on_site'),
  IN p_description TEXT,
  IN p_start_date DATE,
  IN p_end_date DATE,
  IN p_is_current TINYINT,
  IN p_visibility ENUM('public','private')
)
BEGIN
  UPDATE jobs SET
    company = COALESCE(p_company, company),
    job_title = COALESCE(p_job_title, job_title),
    title = COALESCE(p_title, title),
    industry = COALESCE(p_industry, industry),
    employment_type = COALESCE(p_employment_type, employment_type),
    salary = COALESCE(p_salary, salary),
    location = COALESCE(p_location, location),
    work_setup = COALESCE(p_work_setup, work_setup),
    description = COALESCE(p_description, description),
    start_date = COALESCE(p_start_date, start_date),
    end_date = COALESCE(p_end_date, end_date),
    is_current = COALESCE(p_is_current, is_current),
    visibility = COALESCE(p_visibility, visibility)
  WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_jobs_soft_delete;
CREATE PROCEDURE sp_jobs_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE jobs SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_jobs_restore;
CREATE PROCEDURE sp_jobs_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE jobs SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

-- ============================================================
-- 8. surveys
-- ============================================================
DROP PROCEDURE IF EXISTS sp_surveys_create;
CREATE PROCEDURE sp_surveys_create(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_target_graduation_year INT,
  IN p_target_batch_year INT,
  IN p_opening_date DATETIME,
  IN p_closing_date DATETIME,
  IN p_status ENUM('draft','published','closed'),
  IN p_allow_update TINYINT,
  IN p_visible_batches_json JSON,
  IN p_questions_json JSON,
  IN p_visibility ENUM('public','private'),
  IN p_is_active TINYINT,
  IN p_created_by VARCHAR(128)
)
BEGIN
  INSERT INTO surveys (id, title, description, target_graduation_year, target_batch_year, opening_date, closing_date, status, allow_update, visible_batches_json, questions_json, visibility, is_active, created_by)
  VALUES (p_id, p_title, p_description, p_target_graduation_year, p_target_batch_year, p_opening_date, p_closing_date, COALESCE(p_status,'draft'), COALESCE(p_allow_update,0), p_visible_batches_json, COALESCE(p_questions_json, JSON_ARRAY()), COALESCE(p_visibility,'public'), COALESCE(p_is_active,1), p_created_by);
  SELECT * FROM surveys WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_surveys_get_by_id;
CREATE PROCEDURE sp_surveys_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM surveys WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_surveys_list;
CREATE PROCEDURE sp_surveys_list(
  IN p_visibility VARCHAR(16),
  IN p_status VARCHAR(16),
  IN p_is_alumni TINYINT,
  IN p_graduation_year INT
)
BEGIN
  SELECT * FROM surveys
  WHERE is_deleted=0
    AND (p_visibility IS NULL OR p_visibility='' OR visibility=p_visibility)
    AND (p_status IS NULL OR p_status='' OR status=p_status)
    AND (p_is_alumni = 0 OR (
      status='published' AND visibility='public' AND is_active=1
      AND (opening_date IS NULL OR opening_date <= NOW())
      AND (closing_date IS NULL OR closing_date >= NOW())
      AND (visible_batches_json IS NULL OR JSON_LENGTH(visible_batches_json)=0 OR (p_graduation_year IS NOT NULL AND JSON_CONTAINS(visible_batches_json, JSON_ARRAY(p_graduation_year))))
    ))
  ORDER BY updated_at DESC, created_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_surveys_list_all;
CREATE PROCEDURE sp_surveys_list_all(IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM surveys WHERE is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_surveys_update;
CREATE PROCEDURE sp_surveys_update(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_target_graduation_year INT,
  IN p_target_batch_year INT,
  IN p_opening_date DATETIME,
  IN p_clear_opening_date TINYINT,
  IN p_closing_date DATETIME,
  IN p_clear_closing_date TINYINT,
  IN p_status ENUM('draft','published','closed'),
  IN p_allow_update TINYINT,
  IN p_visible_batches_json JSON,
  IN p_clear_visible_batches TINYINT,
  IN p_questions_json JSON,
  IN p_visibility ENUM('public','private'),
  IN p_is_active TINYINT
)
BEGIN
  UPDATE surveys SET
    title = COALESCE(p_title, title),
    description = COALESCE(p_description, description),
    target_graduation_year = COALESCE(p_target_graduation_year, target_graduation_year),
    target_batch_year = COALESCE(p_target_batch_year, target_batch_year),
    opening_date = IF(p_clear_opening_date=1, NULL, COALESCE(p_opening_date, opening_date)),
    closing_date = IF(p_clear_closing_date=1, NULL, COALESCE(p_closing_date, closing_date)),
    status = COALESCE(p_status, status),
    allow_update = COALESCE(p_allow_update, allow_update),
    visible_batches_json = IF(p_clear_visible_batches=1, NULL, COALESCE(p_visible_batches_json, visible_batches_json)),
    questions_json = COALESCE(p_questions_json, questions_json),
    visibility = COALESCE(p_visibility, visibility),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id=p_id AND is_deleted=0;
  SELECT * FROM surveys WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_surveys_soft_delete;
CREATE PROCEDURE sp_surveys_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE surveys SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
  UPDATE survey_responses SET is_deleted=1, deleted_at=p_deleted_at WHERE survey_id=p_id;
  UPDATE survey_questions SET is_deleted=1, deleted_at=p_deleted_at WHERE survey_id=p_id;
END;

DROP PROCEDURE IF EXISTS sp_surveys_update_questions_json;
CREATE PROCEDURE sp_surveys_update_questions_json(IN p_id VARCHAR(36), IN p_questions_json JSON)
BEGIN
  UPDATE surveys SET questions_json=p_questions_json WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_surveys_count;
CREATE PROCEDURE sp_surveys_count()
BEGIN
  SELECT COUNT(*) AS c FROM surveys WHERE is_deleted=0;
END;

-- ============================================================
-- 8b. survey_questions
-- ============================================================
DROP PROCEDURE IF EXISTS sp_survey_questions_create;
CREATE PROCEDURE sp_survey_questions_create(
  IN p_id VARCHAR(36),
  IN p_survey_id VARCHAR(36),
  IN p_question_text TEXT,
  IN p_question_type ENUM('short_text','long_text','single_select','multi_select','yes_no','number','date'),
  IN p_placeholder VARCHAR(255),
  IN p_character_limit INT,
  IN p_is_required TINYINT,
  IN p_is_published TINYINT,
  IN p_sort_order INT,
  IN p_conditional_parent_id VARCHAR(36),
  IN p_conditional_trigger_value TEXT,
  IN p_allow_other TINYINT
)
BEGIN
  INSERT INTO survey_questions (id, survey_id, question_text, question_type, placeholder, character_limit, is_required, is_published, sort_order, conditional_parent_id, conditional_trigger_value, allow_other)
  VALUES (p_id, p_survey_id, p_question_text, COALESCE(p_question_type,'short_text'), p_placeholder, p_character_limit, COALESCE(p_is_required,0), COALESCE(p_is_published,1), COALESCE(p_sort_order,0), p_conditional_parent_id, p_conditional_trigger_value, COALESCE(p_allow_other,0));
  SELECT * FROM survey_questions WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_questions_list_by_survey;
CREATE PROCEDURE sp_survey_questions_list_by_survey(IN p_survey_id VARCHAR(36))
BEGIN
  SELECT * FROM survey_questions WHERE survey_id=p_survey_id AND is_deleted=0 ORDER BY sort_order ASC, created_at ASC;
END;

DROP PROCEDURE IF EXISTS sp_survey_questions_get_by_id;
CREATE PROCEDURE sp_survey_questions_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM survey_questions WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_questions_soft_delete_by_survey;
CREATE PROCEDURE sp_survey_questions_soft_delete_by_survey(IN p_survey_id VARCHAR(36))
BEGIN
  UPDATE survey_questions SET is_deleted=1, deleted_at=NOW() WHERE survey_id=p_survey_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_questions_update_sort;
CREATE PROCEDURE sp_survey_questions_update_sort(IN p_id VARCHAR(36), IN p_survey_id VARCHAR(36), IN p_sort_order INT)
BEGIN
  UPDATE survey_questions SET sort_order=p_sort_order WHERE id=p_id AND survey_id=p_survey_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_questions_restore;
CREATE PROCEDURE sp_survey_questions_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE survey_questions SET is_deleted=0, deleted_at=NULL WHERE id=p_id;
END;

-- ============================================================
-- 8c. survey_question_options
-- ============================================================
DROP PROCEDURE IF EXISTS sp_survey_question_options_create;
CREATE PROCEDURE sp_survey_question_options_create(
  IN p_id VARCHAR(36),
  IN p_question_id VARCHAR(36),
  IN p_option_text VARCHAR(255),
  IN p_sort_order INT,
  IN p_is_other TINYINT
)
BEGIN
  INSERT INTO survey_question_options (id, question_id, option_text, sort_order, is_other)
  VALUES (p_id, p_question_id, p_option_text, COALESCE(p_sort_order,0), COALESCE(p_is_other,0));
  SELECT * FROM survey_question_options WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_question_options_list_by_question;
CREATE PROCEDURE sp_survey_question_options_list_by_question(IN p_question_id VARCHAR(36))
BEGIN
  SELECT * FROM survey_question_options WHERE question_id=p_question_id AND is_deleted=0 ORDER BY sort_order ASC;
END;

DROP PROCEDURE IF EXISTS sp_survey_question_options_soft_delete_by_question;
CREATE PROCEDURE sp_survey_question_options_soft_delete_by_question(IN p_question_id VARCHAR(36))
BEGIN
  UPDATE survey_question_options SET is_deleted=1, deleted_at=NOW() WHERE question_id=p_question_id AND is_deleted=0;
END;

-- ============================================================
-- 9. survey_responses
-- ============================================================
DROP PROCEDURE IF EXISTS sp_survey_responses_create;
CREATE PROCEDURE sp_survey_responses_create(
  IN p_id VARCHAR(36),
  IN p_survey_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_answers_json JSON,
  IN p_status ENUM('draft','submitted')
)
BEGIN
  INSERT INTO survey_responses (id, survey_id, user_id, answers_json, status)
  VALUES (p_id, p_survey_id, p_user_id, COALESCE(p_answers_json, JSON_OBJECT()), COALESCE(p_status,'submitted'));
  SELECT * FROM survey_responses WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_upsert;
CREATE PROCEDURE sp_survey_responses_upsert(
  IN p_id VARCHAR(36),
  IN p_survey_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_answers_json JSON,
  IN p_status ENUM('draft','submitted')
)
BEGIN
  INSERT INTO survey_responses (id, survey_id, user_id, answers_json, status)
  VALUES (p_id, p_survey_id, p_user_id, COALESCE(p_answers_json, JSON_OBJECT()), COALESCE(p_status,'submitted'))
  ON DUPLICATE KEY UPDATE answers_json=VALUES(answers_json), status=VALUES(status), updated_at=NOW(), is_deleted=0, deleted_at=NULL;
  -- handle unique constraint uq_survey_user: if insert fails due to duplicate survey+user, update that row
  -- Fallback path handled in application layer; this SP covers id-based upsert.
  SELECT * FROM survey_responses WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_get_by_id;
CREATE PROCEDURE sp_survey_responses_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM survey_responses WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_get_by_survey_user;
CREATE PROCEDURE sp_survey_responses_get_by_survey_user(IN p_survey_id VARCHAR(36), IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM survey_responses WHERE survey_id=p_survey_id AND user_id=p_user_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_list_by_survey;
CREATE PROCEDURE sp_survey_responses_list_by_survey(IN p_survey_id VARCHAR(36), IN p_archived TINYINT)
BEGIN
  SELECT r.*, u.full_name AS respondent_name, u.email AS respondent_email, u.graduation_year, u.academic_year_graduated, u.course_name, u.employment_status, u.birthdate
  FROM survey_responses r LEFT JOIN users u ON u.id=r.user_id
  WHERE r.survey_id=p_survey_id AND r.is_deleted=0
    AND (p_archived IS NULL OR r.is_archived=p_archived)
  ORDER BY r.submitted_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_list_by_user;
CREATE PROCEDURE sp_survey_responses_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM survey_responses WHERE user_id=p_user_id AND is_deleted=0 ORDER BY submitted_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_update;
CREATE PROCEDURE sp_survey_responses_update(
  IN p_id VARCHAR(36),
  IN p_answers_json JSON,
  IN p_status ENUM('draft','submitted')
)
BEGIN
  UPDATE survey_responses SET answers_json=COALESCE(p_answers_json, answers_json), status=COALESCE(p_status, status), updated_at=NOW(), is_deleted=0, deleted_at=NULL WHERE id=p_id;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_set_archived;
CREATE PROCEDURE sp_survey_responses_set_archived(IN p_id VARCHAR(36), IN p_archived TINYINT)
BEGIN
  UPDATE survey_responses SET is_archived=p_archived WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_soft_delete;
CREATE PROCEDURE sp_survey_responses_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE survey_responses SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_list_for_export;
CREATE PROCEDURE sp_survey_responses_list_for_export(IN p_survey_id VARCHAR(36))
BEGIN
  SELECT r.*, u.full_name, u.email, u.graduation_year, u.academic_year_graduated, u.course_name
  FROM survey_responses r LEFT JOIN users u ON u.id=r.user_id
  WHERE r.survey_id=p_survey_id AND r.is_deleted=0 AND r.is_archived=0 ORDER BY r.submitted_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_survey_responses_count_by_survey;
CREATE PROCEDURE sp_survey_responses_count_by_survey(IN p_survey_id VARCHAR(36))
BEGIN
  SELECT COUNT(*) AS c FROM survey_responses WHERE survey_id=p_survey_id AND is_deleted=0;
END;

-- ============================================================
-- 9b. survey_answers
-- ============================================================
DROP PROCEDURE IF EXISTS sp_survey_answers_create;
CREATE PROCEDURE sp_survey_answers_create(
  IN p_id VARCHAR(36),
  IN p_submission_id VARCHAR(36),
  IN p_question_id VARCHAR(36),
  IN p_answer_text TEXT,
  IN p_answer_json JSON,
  IN p_custom_other_text VARCHAR(500)
)
BEGIN
  INSERT INTO survey_answers (id, submission_id, question_id, answer_text, answer_json, custom_other_text)
  VALUES (p_id, p_submission_id, p_question_id, p_answer_text, p_answer_json, p_custom_other_text);
  SELECT * FROM survey_answers WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_survey_answers_list_by_submission;
CREATE PROCEDURE sp_survey_answers_list_by_submission(IN p_submission_id VARCHAR(36))
BEGIN
  SELECT * FROM survey_answers WHERE submission_id=p_submission_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_answers_list_by_question;
CREATE PROCEDURE sp_survey_answers_list_by_question(IN p_question_id VARCHAR(36))
BEGIN
  SELECT answer_text, answer_json, custom_other_text FROM survey_answers WHERE question_id=p_question_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_answers_soft_delete_by_submission;
CREATE PROCEDURE sp_survey_answers_soft_delete_by_submission(IN p_submission_id VARCHAR(36))
BEGIN
  UPDATE survey_answers SET is_deleted=1, deleted_at=NOW() WHERE submission_id=p_submission_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_survey_answers_upsert;
CREATE PROCEDURE sp_survey_answers_upsert(
  IN p_submission_id VARCHAR(36),
  IN p_question_id VARCHAR(36),
  IN p_answer_text TEXT,
  IN p_answer_json JSON,
  IN p_custom_other_text VARCHAR(500)
)
BEGIN
  INSERT INTO survey_answers (id, submission_id, question_id, answer_text, answer_json, custom_other_text)
  VALUES (UUID(), p_submission_id, p_question_id, p_answer_text, p_answer_json, p_custom_other_text)
  ON DUPLICATE KEY UPDATE answer_text=VALUES(answer_text), answer_json=VALUES(answer_json), custom_other_text=VALUES(custom_other_text), is_deleted=0, deleted_at=NULL;
END;

-- ============================================================
-- 10. announcements
-- ============================================================
DROP PROCEDURE IF EXISTS sp_announcements_create;
CREATE PROCEDURE sp_announcements_create(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_visibility ENUM('public','private'),
  IN p_created_by VARCHAR(128)
)
BEGIN
  INSERT INTO announcements (id, title, description, visibility, created_by) VALUES (p_id, p_title, p_description, COALESCE(p_visibility,'public'), p_created_by);
  SELECT * FROM announcements WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_announcements_get_by_id;
CREATE PROCEDURE sp_announcements_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM announcements WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_announcements_list;
CREATE PROCEDURE sp_announcements_list(IN p_visibility VARCHAR(16), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM announcements
  WHERE is_deleted=0
    AND (p_visibility IS NULL OR p_visibility='' OR visibility=p_visibility)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_announcements_update;
CREATE PROCEDURE sp_announcements_update(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_visibility ENUM('public','private')
)
BEGIN
  UPDATE announcements SET
    title=COALESCE(p_title, title),
    description=COALESCE(p_description, description),
    visibility=COALESCE(p_visibility, visibility)
  WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_announcements_soft_delete;
CREATE PROCEDURE sp_announcements_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE announcements SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_announcements_restore;
CREATE PROCEDURE sp_announcements_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE announcements SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

-- ============================================================
-- 11. events
-- ============================================================
DROP PROCEDURE IF EXISTS sp_events_create;
CREATE PROCEDURE sp_events_create(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_location VARCHAR(255),
  IN p_event_date DATETIME,
  IN p_visibility ENUM('public','private'),
  IN p_extra_json JSON,
  IN p_created_by VARCHAR(128)
)
BEGIN
  INSERT INTO events (id, title, description, location, event_date, visibility, extra_json, created_by)
  VALUES (p_id, p_title, p_description, p_location, p_event_date, COALESCE(p_visibility,'public'), p_extra_json, p_created_by);
  SELECT * FROM events WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_events_get_by_id;
CREATE PROCEDURE sp_events_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM events WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_events_list;
CREATE PROCEDURE sp_events_list(IN p_visibility VARCHAR(16), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM events
  WHERE is_deleted=0
    AND (p_visibility IS NULL OR p_visibility='' OR visibility=p_visibility)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_events_update;
CREATE PROCEDURE sp_events_update(
  IN p_id VARCHAR(36),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_location VARCHAR(255),
  IN p_event_date DATETIME,
  IN p_visibility ENUM('public','private'),
  IN p_extra_json JSON
)
BEGIN
  UPDATE events SET
    title=COALESCE(p_title, title),
    description=COALESCE(p_description, description),
    location=COALESCE(p_location, location),
    event_date=COALESCE(p_event_date, event_date),
    visibility=COALESCE(p_visibility, visibility),
    extra_json=COALESCE(p_extra_json, extra_json)
  WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_events_soft_delete;
CREATE PROCEDURE sp_events_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE events SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_events_restore;
CREATE PROCEDURE sp_events_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE events SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

-- ============================================================
-- 12. event_registrations
-- ============================================================
DROP PROCEDURE IF EXISTS sp_event_registrations_create;
CREATE PROCEDURE sp_event_registrations_create(
  IN p_id VARCHAR(36),
  IN p_event_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_status VARCHAR(32)
)
BEGIN
  INSERT INTO event_registrations (id, event_id, user_id, status) VALUES (p_id, p_event_id, p_user_id, COALESCE(p_status,'registered'));
  SELECT * FROM event_registrations WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_get_by_id;
CREATE PROCEDURE sp_event_registrations_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM event_registrations WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_list_by_event;
CREATE PROCEDURE sp_event_registrations_list_by_event(IN p_event_id VARCHAR(36))
BEGIN
  SELECT * FROM event_registrations WHERE event_id=p_event_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_list_by_user;
CREATE PROCEDURE sp_event_registrations_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM event_registrations WHERE user_id=p_user_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_exists;
CREATE PROCEDURE sp_event_registrations_exists(IN p_event_id VARCHAR(36), IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM event_registrations WHERE event_id=p_event_id AND user_id=p_user_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_update_status;
CREATE PROCEDURE sp_event_registrations_update_status(IN p_id VARCHAR(36), IN p_status VARCHAR(32))
BEGIN
  UPDATE event_registrations SET status=p_status WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_event_registrations_soft_delete;
CREATE PROCEDURE sp_event_registrations_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE event_registrations SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

-- ============================================================
-- 13. reports
-- ============================================================
DROP PROCEDURE IF EXISTS sp_reports_create;
CREATE PROCEDURE sp_reports_create(
  IN p_id VARCHAR(36),
  IN p_type VARCHAR(64),
  IN p_title VARCHAR(255),
  IN p_period VARCHAR(64),
  IN p_description TEXT,
  IN p_data_json JSON,
  IN p_created_by VARCHAR(128)
)
BEGIN
  INSERT INTO reports (id, type, title, period, description, data_json, created_by)
  VALUES (p_id, COALESCE(p_type,'general'), p_title, p_period, p_description, p_data_json, p_created_by);
  SELECT * FROM reports WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_reports_get_by_id;
CREATE PROCEDURE sp_reports_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM reports WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_reports_list;
CREATE PROCEDURE sp_reports_list(IN p_type VARCHAR(64), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM reports
  WHERE is_deleted=0
    AND (p_type IS NULL OR p_type='' OR type=p_type)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_reports_update;
CREATE PROCEDURE sp_reports_update(
  IN p_id VARCHAR(36),
  IN p_type VARCHAR(64),
  IN p_title VARCHAR(255),
  IN p_period VARCHAR(64),
  IN p_description TEXT,
  IN p_data_json JSON
)
BEGIN
  UPDATE reports SET
    type=COALESCE(p_type, type),
    title=COALESCE(p_title, title),
    period=COALESCE(p_period, period),
    description=COALESCE(p_description, description),
    data_json=COALESCE(p_data_json, data_json)
  WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_reports_soft_delete;
CREATE PROCEDURE sp_reports_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE reports SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

-- ============================================================
-- 14. conversations
-- ============================================================
DROP PROCEDURE IF EXISTS sp_conversations_upsert;
CREATE PROCEDURE sp_conversations_upsert(
  IN p_id VARCHAR(128),
  IN p_alumni_id VARCHAR(64),
  IN p_alumni_name VARCHAR(255),
  IN p_alumni_email VARCHAR(255),
  IN p_alumni_course VARCHAR(255),
  IN p_participant_ids_json JSON,
  IN p_last_message TEXT,
  IN p_last_message_time DATETIME,
  IN p_last_sender_id VARCHAR(128),
  IN p_unread_admin INT,
  IN p_unread_alumni INT
)
BEGIN
  INSERT INTO conversations (id, alumni_id, alumni_name, alumni_email, alumni_course, participant_ids_json, last_message, last_message_time, last_sender_id, unread_admin, unread_alumni)
  VALUES (p_id, p_alumni_id, COALESCE(p_alumni_name,'Alumni'), COALESCE(p_alumni_email,''), p_alumni_course, p_participant_ids_json, p_last_message, p_last_message_time, p_last_sender_id, COALESCE(p_unread_admin,0), COALESCE(p_unread_alumni,0))
  ON DUPLICATE KEY UPDATE
    alumni_name=VALUES(alumni_name),
    alumni_email=VALUES(alumni_email),
    alumni_course=VALUES(alumni_course),
    participant_ids_json=VALUES(participant_ids_json),
    last_message=VALUES(last_message),
    last_message_time=VALUES(last_message_time),
    last_sender_id=VALUES(last_sender_id),
    unread_admin=unread_admin+VALUES(unread_admin),
    unread_alumni=unread_alumni+VALUES(unread_alumni),
    is_deleted=0, deleted_at=NULL;
  SELECT * FROM conversations WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_conversations_get_by_id;
CREATE PROCEDURE sp_conversations_get_by_id(IN p_id VARCHAR(128))
BEGIN
  SELECT * FROM conversations WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_conversations_list;
CREATE PROCEDURE sp_conversations_list(IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,200),500);
  SELECT * FROM conversations WHERE is_deleted=0 ORDER BY last_message_time DESC, updated_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_conversations_get_own;
CREATE PROCEDURE sp_conversations_get_own(IN p_id VARCHAR(128))
BEGIN
  SELECT * FROM conversations WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_conversations_mark_read_admin;
CREATE PROCEDURE sp_conversations_mark_read_admin(IN p_id VARCHAR(128))
BEGIN
  UPDATE conversations SET unread_admin=0 WHERE id=p_id;
END;

DROP PROCEDURE IF EXISTS sp_conversations_mark_read_alumni;
CREATE PROCEDURE sp_conversations_mark_read_alumni(IN p_id VARCHAR(128))
BEGIN
  UPDATE conversations SET unread_alumni=0 WHERE id=p_id;
END;

DROP PROCEDURE IF EXISTS sp_conversations_soft_delete;
CREATE PROCEDURE sp_conversations_soft_delete(IN p_id VARCHAR(128), IN p_deleted_at DATETIME)
BEGIN
  UPDATE conversations SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

-- ============================================================
-- 15. messages
-- ============================================================
DROP PROCEDURE IF EXISTS sp_messages_create;
CREATE PROCEDURE sp_messages_create(
  IN p_id VARCHAR(36),
  IN p_conversation_id VARCHAR(128),
  IN p_sender_id VARCHAR(128),
  IN p_sender_name VARCHAR(255),
  IN p_sender_role VARCHAR(32),
  IN p_recipient_id VARCHAR(128),
  IN p_user_id VARCHAR(128),
  IN p_participant_ids_json JSON,
  IN p_text MEDIUMTEXT,
  IN p_image_url TEXT
)
BEGIN
  INSERT INTO messages (id, conversation_id, sender_id, sender_name, sender_role, recipient_id, user_id, participant_ids_json, text, image_url)
  VALUES (p_id, p_conversation_id, COALESCE(p_sender_id,''), COALESCE(p_sender_name,'User'), COALESCE(p_sender_role,'alumni'), p_recipient_id, p_user_id, p_participant_ids_json, p_text, p_image_url);
  SELECT * FROM messages WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_messages_get_by_id;
CREATE PROCEDURE sp_messages_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM messages WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_messages_list_by_conversation;
CREATE PROCEDURE sp_messages_list_by_conversation(IN p_conversation_id VARCHAR(128), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  SELECT * FROM messages WHERE conversation_id=p_conversation_id AND is_deleted=0 ORDER BY created_at ASC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_messages_mark_read;
CREATE PROCEDURE sp_messages_mark_read(IN p_conversation_id VARCHAR(128))
BEGIN
  UPDATE messages SET is_read=1 WHERE conversation_id=p_conversation_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_messages_soft_delete;
CREATE PROCEDURE sp_messages_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE messages SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_messages_encrypt_update;
CREATE PROCEDURE sp_messages_encrypt_update(IN p_id VARCHAR(36), IN p_text MEDIUMTEXT)
BEGIN
  UPDATE messages SET text=p_text WHERE id=p_id;
END;

-- ============================================================
-- 16. notifications
-- ============================================================
DROP PROCEDURE IF EXISTS sp_notifications_create;
CREATE PROCEDURE sp_notifications_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_recipient_role ENUM('admin','alumni'),
  IN p_type VARCHAR(32),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_priority ENUM('low','medium','high'),
  IN p_link TEXT
)
BEGIN
  INSERT INTO notifications (id, user_id, recipient_role, type, title, description, priority, link)
  VALUES (p_id, p_user_id, p_recipient_role, COALESCE(p_type,'system'), COALESCE(p_title,''), p_description, COALESCE(p_priority,'medium'), p_link);
  SELECT * FROM notifications WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_notifications_create_for_alumni_bulk;
CREATE PROCEDURE sp_notifications_create_for_alumni_bulk(
  IN p_type VARCHAR(32),
  IN p_title VARCHAR(255),
  IN p_description TEXT
)
BEGIN
  INSERT INTO notifications (id, user_id, recipient_role, type, title, description)
  SELECT UUID(), id, 'alumni', p_type, p_title, p_description FROM users WHERE role='alumni' AND is_deleted=0 AND (disabled IS NULL OR disabled=0);
END;

DROP PROCEDURE IF EXISTS sp_notifications_get_by_id;
CREATE PROCEDURE sp_notifications_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM notifications WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_notifications_list_by_user;
CREATE PROCEDURE sp_notifications_list_by_user(IN p_user_id VARCHAR(128), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,200),500);
  SELECT * FROM notifications WHERE user_id=p_user_id AND is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_notifications_list_by_role;
CREATE PROCEDURE sp_notifications_list_by_role(IN p_role ENUM('admin','alumni'), IN p_is_read TINYINT, IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,200),500);
  SELECT * FROM notifications
  WHERE is_deleted=0
    AND (p_role IS NULL OR recipient_role=p_role)
    AND (p_is_read IS NULL OR is_read=p_is_read)
  ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_notifications_list_unread_by_user;
CREATE PROCEDURE sp_notifications_list_unread_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM notifications WHERE user_id=p_user_id AND is_read=0 AND is_deleted=0 ORDER BY created_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_notifications_mark_read;
CREATE PROCEDURE sp_notifications_mark_read(IN p_id VARCHAR(36))
BEGIN
  UPDATE notifications SET is_read=1 WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_notifications_mark_all_read_by_user;
CREATE PROCEDURE sp_notifications_mark_all_read_by_user(IN p_user_id VARCHAR(128))
BEGIN
  UPDATE notifications SET is_read=1 WHERE user_id=p_user_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_notifications_mark_all_read_by_role;
CREATE PROCEDURE sp_notifications_mark_all_read_by_role(IN p_role ENUM('admin','alumni'))
BEGIN
  UPDATE notifications SET is_read=1 WHERE recipient_role=p_role AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_notifications_soft_delete;
CREATE PROCEDURE sp_notifications_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE notifications SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_notifications_count_unread;
CREATE PROCEDURE sp_notifications_count_unread(IN p_user_id VARCHAR(128))
BEGIN
  SELECT COUNT(*) AS c FROM notifications WHERE user_id=p_user_id AND is_read=0 AND is_deleted=0;
END;

-- ============================================================
-- 17. certificates
-- ============================================================
DROP PROCEDURE IF EXISTS sp_certificates_create;
CREATE PROCEDURE sp_certificates_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_title VARCHAR(255),
  IN p_provider ENUM('tesda','google','cisco','aws','microsoft','oracle','other'),
  IN p_file_url TEXT,
  IN p_storage_path TEXT,
  IN p_file_type VARCHAR(16),
  IN p_issued_date DATE
)
BEGIN
  INSERT INTO certificates (id, user_id, title, provider, file_url, storage_path, file_type, issued_date)
  VALUES (p_id, p_user_id, COALESCE(p_title,''), COALESCE(p_provider,'other'), p_file_url, p_storage_path, COALESCE(p_file_type,'image'), p_issued_date);
  SELECT * FROM certificates WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_certificates_get_by_id;
CREATE PROCEDURE sp_certificates_get_by_id(IN p_id VARCHAR(36))
BEGIN
  SELECT * FROM certificates WHERE id=p_id AND is_deleted=0 LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_certificates_list_by_user;
CREATE PROCEDURE sp_certificates_list_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM certificates WHERE user_id=p_user_id AND is_deleted=0 ORDER BY uploaded_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_certificates_soft_delete;
CREATE PROCEDURE sp_certificates_soft_delete(IN p_id VARCHAR(36), IN p_deleted_at DATETIME)
BEGIN
  UPDATE certificates SET is_deleted=1, deleted_at=p_deleted_at WHERE id=p_id AND is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_certificates_restore;
CREATE PROCEDURE sp_certificates_restore(IN p_id VARCHAR(36))
BEGIN
  UPDATE certificates SET is_deleted=0, deleted_at=NULL WHERE id=p_id AND is_deleted=1;
END;

-- ============================================================
-- 18. system_settings
-- ============================================================
DROP PROCEDURE IF EXISTS sp_system_settings_get_by_key;
CREATE PROCEDURE sp_system_settings_get_by_key(IN p_key VARCHAR(128))
BEGIN
  SELECT * FROM system_settings WHERE setting_key=p_key LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_system_settings_list;
CREATE PROCEDURE sp_system_settings_list()
BEGIN
  SELECT * FROM system_settings ORDER BY setting_key ASC;
END;

DROP PROCEDURE IF EXISTS sp_system_settings_upsert;
CREATE PROCEDURE sp_system_settings_upsert(IN p_key VARCHAR(128), IN p_value_json JSON)
BEGIN
  INSERT INTO system_settings (setting_key, value_json) VALUES (p_key, p_value_json)
  ON DUPLICATE KEY UPDATE value_json=VALUES(value_json);
  SELECT * FROM system_settings WHERE setting_key=p_key LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_system_settings_delete;
CREATE PROCEDURE sp_system_settings_delete(IN p_key VARCHAR(128))
BEGIN
  DELETE FROM system_settings WHERE setting_key=p_key;
END;

-- ============================================================
-- 19. audit_logs
-- ============================================================
DROP PROCEDURE IF EXISTS sp_audit_logs_create;
CREATE PROCEDURE sp_audit_logs_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_action VARCHAR(128),
  IN p_title VARCHAR(255),
  IN p_description TEXT,
  IN p_actor_id VARCHAR(128),
  IN p_actor_name VARCHAR(255),
  IN p_actor_role VARCHAR(32),
  IN p_target_id VARCHAR(128),
  IN p_target_type VARCHAR(128),
  IN p_target_resource VARCHAR(128),
  IN p_details_json JSON,
  IN p_ip_address VARCHAR(45)
)
BEGIN
  INSERT INTO audit_logs (id, user_id, action, title, description, actor_id, actor_name, actor_role, target_id, target_type, target_resource, details_json, ip_address)
  VALUES (p_id, p_user_id, p_action, p_title, p_description, p_actor_id, p_actor_name, p_actor_role, p_target_id, p_target_type, p_target_resource, p_details_json, p_ip_address);
  SELECT * FROM audit_logs WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_audit_logs_list;
CREATE PROCEDURE sp_audit_logs_list(IN p_limit INT, IN p_offset INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,100),500);
  SET p_offset = COALESCE(p_offset,0);
  SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset;
END;

DROP PROCEDURE IF EXISTS sp_audit_logs_list_by_user;
CREATE PROCEDURE sp_audit_logs_list_by_user(IN p_user_id VARCHAR(128), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,100),500);
  SELECT * FROM audit_logs WHERE user_id=p_user_id ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_audit_logs_list_by_action;
CREATE PROCEDURE sp_audit_logs_list_by_action(IN p_action VARCHAR(128), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,100),500);
  SELECT * FROM audit_logs WHERE action=p_action ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_audit_logs_count;
CREATE PROCEDURE sp_audit_logs_count()
BEGIN
  SELECT COUNT(*) AS c FROM audit_logs;
END;

-- ============================================================
-- 20. password_resets
-- ============================================================
DROP PROCEDURE IF EXISTS sp_password_resets_create;
CREATE PROCEDURE sp_password_resets_create(
  IN p_email VARCHAR(255),
  IN p_user_id VARCHAR(128),
  IN p_code CHAR(6),
  IN p_expires_at DATETIME
)
BEGIN
  INSERT INTO password_resets (email, user_id, code, expires_at) VALUES (p_email, p_user_id, p_code, p_expires_at);
  SELECT * FROM password_resets WHERE id=LAST_INSERT_ID() LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_password_resets_get_valid;
CREATE PROCEDURE sp_password_resets_get_valid(IN p_email VARCHAR(255), IN p_code CHAR(6))
BEGIN
  SELECT * FROM password_resets WHERE email=p_email AND code=p_code AND used=0 AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_password_resets_get_by_email;
CREATE PROCEDURE sp_password_resets_get_by_email(IN p_email VARCHAR(255), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,10),50);
  SELECT * FROM password_resets WHERE email=p_email ORDER BY created_at DESC LIMIT p_limit;
END;

DROP PROCEDURE IF EXISTS sp_password_resets_mark_used;
CREATE PROCEDURE sp_password_resets_mark_used(IN p_id BIGINT UNSIGNED)
BEGIN
  UPDATE password_resets SET used=1, used_at=NOW() WHERE id=p_id;
END;

DROP PROCEDURE IF EXISTS sp_password_resets_cleanup_expired;
CREATE PROCEDURE sp_password_resets_cleanup_expired()
BEGIN
  DELETE FROM password_resets WHERE expires_at < NOW() OR used=1;
END;

-- ============================================================
-- 21. auth_sessions
-- ============================================================
DROP PROCEDURE IF EXISTS sp_auth_sessions_create;
CREATE PROCEDURE sp_auth_sessions_create(
  IN p_id VARCHAR(36),
  IN p_user_id VARCHAR(128),
  IN p_token_hash CHAR(64),
  IN p_expires_at DATETIME
)
BEGIN
  INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES (p_id, p_user_id, p_token_hash, p_expires_at);
  SELECT * FROM auth_sessions WHERE id=p_id LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_get_by_token_hash;
CREATE PROCEDURE sp_auth_sessions_get_by_token_hash(IN p_token_hash CHAR(64))
BEGIN
  SELECT * FROM auth_sessions WHERE token_hash=p_token_hash LIMIT 1;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_get_by_user;
CREATE PROCEDURE sp_auth_sessions_get_by_user(IN p_user_id VARCHAR(128))
BEGIN
  SELECT * FROM auth_sessions WHERE user_id=p_user_id ORDER BY created_at DESC;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_revoke_by_user;
CREATE PROCEDURE sp_auth_sessions_revoke_by_user(IN p_user_id VARCHAR(128))
BEGIN
  UPDATE auth_sessions SET revoked=1 WHERE user_id=p_user_id;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_revoke_by_token;
CREATE PROCEDURE sp_auth_sessions_revoke_by_token(IN p_token_hash CHAR(64))
BEGIN
  UPDATE auth_sessions SET revoked=1 WHERE token_hash=p_token_hash;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_touch;
CREATE PROCEDURE sp_auth_sessions_touch(IN p_token_hash CHAR(64))
BEGIN
  UPDATE auth_sessions SET last_used_at=NOW() WHERE token_hash=p_token_hash;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_delete_expired;
CREATE PROCEDURE sp_auth_sessions_delete_expired()
BEGIN
  DELETE FROM auth_sessions WHERE expires_at < NOW();
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_extend;
CREATE PROCEDURE sp_auth_sessions_extend(IN p_token_hash CHAR(64), IN p_expires_at DATETIME)
BEGIN
  UPDATE auth_sessions SET last_used_at = NOW(), expires_at = p_expires_at WHERE token_hash = p_token_hash;
END;

DROP PROCEDURE IF EXISTS sp_auth_sessions_get_valid;
CREATE PROCEDURE sp_auth_sessions_get_valid(IN p_token_hash CHAR(64))
BEGIN
  SELECT u.*, s.user_id, s.expires_at, s.revoked
  FROM auth_sessions s
  JOIN users u ON u.id=s.user_id
  WHERE s.token_hash=p_token_hash
    AND s.revoked=0
    AND s.expires_at > NOW()
    AND u.is_deleted=0
  LIMIT 1;
END;

-- ============================================================
-- Aggregate / Stats SPs
-- ============================================================
DROP PROCEDURE IF EXISTS sp_stats_staff;
CREATE PROCEDURE sp_stats_staff()
BEGIN
  SELECT
    (SELECT COUNT(*) FROM users WHERE is_deleted=0) AS totalUsers,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND role='admin') AS admins,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND role='alumni') AS alumni,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND role='alumni' AND is_verified=1) AS verifiedAlumni,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND employment_status='employed') AS employed,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND employment_status='selfEmployed') AS selfEmployed,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND employment_status='freelance') AS freelance,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND employment_status='unemployed') AS unemployed,
    (SELECT COUNT(*) FROM users WHERE is_deleted=0 AND employment_status='studying') AS studying,
    (SELECT COUNT(*) FROM surveys WHERE is_deleted=0) AS surveyCount,
    (SELECT COUNT(*) FROM survey_responses WHERE is_deleted=0) AS responseCount,
    (SELECT COUNT(*) FROM events WHERE is_deleted=0) AS eventCount,
    (SELECT COUNT(*) FROM announcements WHERE is_deleted=0) AS announcementCount;
END;

DROP PROCEDURE IF EXISTS sp_stats_signup_trend;
CREATE PROCEDURE sp_stats_signup_trend()
BEGIN
  SELECT created_at FROM users WHERE is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_stats_response_trend;
CREATE PROCEDURE sp_stats_response_trend()
BEGIN
  SELECT submitted_at FROM survey_responses WHERE is_deleted=0;
END;

DROP PROCEDURE IF EXISTS sp_stats_employment_by_year;
CREATE PROCEDURE sp_stats_employment_by_year()
BEGIN
  SELECT graduation_year AS y, employment_status AS s, COUNT(*) AS c
  FROM users WHERE is_deleted=0 AND role='alumni' AND graduation_year IS NOT NULL
  GROUP BY graduation_year, employment_status;
END;

DROP PROCEDURE IF EXISTS sp_stats_employment_by_course;
CREATE PROCEDURE sp_stats_employment_by_course()
BEGIN
  SELECT course_name AS course, employment_status AS s, COUNT(*) AS c
  FROM users WHERE is_deleted=0 AND role='alumni' AND course_name IS NOT NULL
  GROUP BY course_name, employment_status;
END;

DROP PROCEDURE IF EXISTS sp_stats_batches;
CREATE PROCEDURE sp_stats_batches()
BEGIN
  SELECT academic_year_graduated AS ay, graduation_year AS gy, COUNT(*) AS c
  FROM users WHERE role='alumni' AND is_deleted=0
  GROUP BY academic_year_graduated, graduation_year;
END;

DROP PROCEDURE IF EXISTS sp_stats_survey_progress_count;
CREATE PROCEDURE sp_stats_survey_progress_count(IN p_graduation_year INT, IN p_role VARCHAR(16))
BEGIN
  IF p_role = 'alumni' THEN
    IF p_graduation_year IS NULL THEN
      SELECT COUNT(*) AS c FROM surveys WHERE is_deleted=0 AND (visible_batches_json IS NULL OR JSON_LENGTH(visible_batches_json)=0);
    ELSE
      SELECT COUNT(*) AS c FROM surveys WHERE is_deleted=0 AND (visible_batches_json IS NULL OR JSON_LENGTH(visible_batches_json)=0 OR JSON_CONTAINS(visible_batches_json, JSON_ARRAY(p_graduation_year)));
    END IF;
  ELSE
    SELECT COUNT(*) AS c FROM surveys WHERE is_deleted=0;
  END IF;
END;

DROP PROCEDURE IF EXISTS sp_content_list;
CREATE PROCEDURE sp_content_list(IN p_table VARCHAR(64), IN p_visibility VARCHAR(16), IN p_limit INT)
BEGIN
  SET p_limit = LEAST(COALESCE(p_limit,500),1000);
  IF p_table='announcements' THEN
    IF p_visibility='public' THEN
      SELECT * FROM announcements WHERE is_deleted=0 AND visibility='public' ORDER BY created_at DESC LIMIT p_limit;
    ELSE
      SELECT * FROM announcements WHERE is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
    END IF;
  ELSEIF p_table='events' THEN
    IF p_visibility='public' THEN
      SELECT * FROM events WHERE is_deleted=0 AND visibility='public' ORDER BY created_at DESC LIMIT p_limit;
    ELSE
      SELECT * FROM events WHERE is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
    END IF;
  ELSEIF p_table='jobs' THEN
    IF p_visibility='public' THEN
      SELECT * FROM jobs WHERE is_deleted=0 AND visibility='public' ORDER BY created_at DESC LIMIT p_limit;
    ELSE
      SELECT * FROM jobs WHERE is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
    END IF;
  ELSEIF p_table='reports' THEN
    SELECT * FROM reports WHERE is_deleted=0 ORDER BY created_at DESC LIMIT p_limit;
  END IF;
END;
