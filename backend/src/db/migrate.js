/* eslint-disable no-console */
// Applies src/db/migrations.sql and backfills any columns that are missing
// when the database was created with an older revision of the schema.
// Usage: npm run migrate
const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');
require('../config/env');

const REQUIRED_SURVEY_COLUMNS = [
  ['target_batch_year', 'INT NULL'],
  ['opening_date', 'DATETIME NULL'],
  ['closing_date', 'DATETIME NULL'],
  ['status', "ENUM('draft','published','closed') NOT NULL DEFAULT 'draft'"],
  ['allow_update', 'TINYINT(1) NOT NULL DEFAULT 0'],
  ['visible_batches_json', 'JSON NULL'],
];

const REQUIRED_SURVEY_RESPONSE_COLUMNS = [
  ['updated_at', 'DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'],
  ['is_archived', 'TINYINT(1) NOT NULL DEFAULT 0'],
  ['status', "ENUM('draft','submitted') NOT NULL DEFAULT 'submitted'"],
];

const REQUIRED_MESSAGE_COLUMNS = [
  ['image_url', 'TEXT NULL'],
];

const REQUIRED_USER_COLUMNS = [
  ['contact_email', 'VARCHAR(255) NULL'],
  ['password_hash', 'VARCHAR(255) NULL'],
  ['alumni_id', 'VARCHAR(64) NULL'],
  ['email_verified', 'TINYINT(1) NOT NULL DEFAULT 0'],
  ['has_logged_in', 'TINYINT(1) NOT NULL DEFAULT 0'],
  ['last_login_at', 'DATETIME NULL'],
  ['profile_completion', 'DOUBLE NOT NULL DEFAULT 0'],
  ['social_links_json', 'JSON NULL'],
  ['resume_json', 'JSON NULL'],
];

const REQUIRED_EMPLOYMENT_COLUMNS = [
  ['end_date', 'DATE NULL'],
  ['country', 'VARCHAR(128)'],
  ['province', 'VARCHAR(128)'],
  ['city', 'VARCHAR(128)'],
];

// The hosting MySQL user has no DELETE privilege, so removals are
// soft-deletes. Every table with a delete flow carries these columns.
const SOFT_DELETE_TABLES = [
  'users',
  'alumni_registry',
  'employment_records',
  'jobs',
  'career_milestones',
  'surveys',
  'survey_responses',
  'announcements',
  'events',
  'event_registrations',
  'reports',
  'conversations',
  'messages',
  'notifications',
  'certificates',
];

function splitStatements(sql) {
  return sql
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('--'))
    .join('\n')
    .split(/;\s*\n/)
    .map((s) => s.trim().replace(/;$/, ''))
    .filter(Boolean);
}

function splitProcedures(sql) {
  // Remove DELIMITER client directives if present
  sql = sql.replace(/^DELIMITER.*$/gim, '');
  const blocks = [];
  const regex = /(DROP PROCEDURE IF EXISTS[^;]+;|CREATE PROCEDURE[\s\S]*?END;)/g;
  let m;
  while ((m = regex.exec(sql)) !== null) {
    const stmt = m[1].trim();
    if (stmt) blocks.push(stmt.replace(/;$/, ''));
  }
  return blocks;
}

async function applyStoredProcedures(conn) {
  const spFile = path.join(__dirname, 'stored_procedures.sql');
  if (!fs.existsSync(spFile)) {
    console.log('[migrate] stored_procedures.sql not found, skipping SP deploy.');
    return;
  }
  const sql = fs.readFileSync(spFile, 'utf8');
  const blocks = splitProcedures(sql);
  console.log(`[migrate] deploying ${blocks.length} stored procedures...`);
  for (const stmt of blocks) {
    const head = stmt.slice(0, 80).replace(/\s+/g, ' ');
    try {
      // eslint-disable-next-line no-await-in-loop
      await conn.query(stmt);
      if (stmt.trimStart().startsWith('CREATE PROCEDURE')) {
        const name = stmt.match(/CREATE PROCEDURE\s+(\w+)/i)?.[1] ?? head;
        console.log(`[migrate]  ✓ ${name}`);
      }
    } catch (err) {
      console.log(`[migrate] SP notice (${head}...): ${err.message}`);
    }
  }
  console.log('[migrate] stored procedures deployed.');
}

async function columnExists(conn, database, table, column) {
  const [rows] = await conn.query(
    'SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?',
    [database, table, column],
  );
  return rows[0].c > 0;
}

async function ensureColumns(conn, database, table, columns) {
  for (const [name, definition] of columns) {
    if (!definition) continue;
    // eslint-disable-next-line no-await-in-loop
    if (!(await columnExists(conn, database, table, name))) {
      // eslint-disable-next-line no-await-in-loop
      await conn.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${name}\` ${definition}`);
      console.log(`[migrate] added ${table}.${name}`);
    }
  }
}

async function main() {
  const database =
    process.env.MYSQL_DATABASE || process.env.SQL_DATABASE || 'gradtrack_db';
  const conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST || process.env.SQL_HOST || 'localhost',
    port: Number.parseInt(
      process.env.MYSQL_PORT || process.env.SQL_PORT || '3306',
      10,
    ),
    user: process.env.MYSQL_USER || process.env.SQL_USER || 'root',
    password: process.env.MYSQL_PASSWORD ?? process.env.SQL_PASS ?? '',
    database,
    multipleStatements: false,
    connectTimeout: 15000,
  });

  try {
    const file = path.join(__dirname, 'migrations.sql');
    const statements = splitStatements(fs.readFileSync(file, 'utf8'));
    for (const stmt of statements) {
      const head = stmt.slice(0, 60).replace(/\s+/g, ' ');
      try {
        // eslint-disable-next-line no-await-in-loop
        await conn.query(stmt);
      } catch (err) {
        console.log(`[migrate] notice (${head}...): ${err.message}`);
      }
    }

    await ensureColumns(conn, database, 'surveys', REQUIRED_SURVEY_COLUMNS);
    await ensureColumns(conn, database, 'survey_responses', REQUIRED_SURVEY_RESPONSE_COLUMNS);
    await ensureColumns(conn, database, 'messages', REQUIRED_MESSAGE_COLUMNS);
    await ensureColumns(conn, database, 'users', REQUIRED_USER_COLUMNS);
    await ensureColumns(
      conn,
      database,
      'employment_records',
      REQUIRED_EMPLOYMENT_COLUMNS,
    );
    for (const table of [...SOFT_DELETE_TABLES, 'survey_questions', 'survey_question_options', 'survey_answers']) {
      // eslint-disable-next-line no-await-in-loop
      await ensureColumns(conn, database, table, [
        ['is_deleted', 'TINYINT(1) NOT NULL DEFAULT 0'],
        ['deleted_at', 'DATETIME NULL'],
      ]);
    }

    // student_number / alumni_id must be nullable-unique (older schema had
    // plain UNIQUE which is still compatible; nothing to do here).
    console.log('[migrate] schema is up to date.');

    // Deploy stored procedures for every table (CALL sp_* from backend)
    await applyStoredProcedures(conn);
  } finally {
    await conn.end();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('[migrate] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { main };
