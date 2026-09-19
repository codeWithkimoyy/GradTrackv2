/* Seed default CS tracer survey with 5 editable starter questions */
require('../src/config/env');
const crypto = require('node:crypto');
const mysql = require('../src/config/mysql');

async function main() {
  const title = 'BISU Institutional Graduate Tracer Survey — Computer Science';
  // delete existing with same title if any
  const existing = await mysql.query('SELECT id FROM surveys WHERE title = ? AND is_deleted = 0 LIMIT 1', [title]);
  if (existing.length) {
    console.log('[seed] deleting existing survey', existing[0].id);
    await mysql.query('UPDATE surveys SET is_deleted = 1, deleted_at = NOW() WHERE id = ?', [existing[0].id]);
    await mysql.query('UPDATE survey_questions SET is_deleted = 1, deleted_at = NOW() WHERE survey_id = ?', [existing[0].id]);
  }
  const surveyId = crypto.randomUUID();
  const now = new Date();
  const closing = new Date(now); closing.setFullYear(closing.getFullYear() + 1);
  const fmt = (d) => d.toISOString().slice(0,19).replace('T',' ');
  const questions = [];
  const qids = Array.from({length:5}, () => crypto.randomUUID());
  const mk = (idx, text, type, opts, allowOther, placeholder, charLimit, isRequired, cond) => ({
    id: qids[idx],
    text,
    type,
    options: opts,
    allowOther: !!allowOther,
    placeholder: placeholder || null,
    characterLimit: charLimit || null,
    isRequired: !!isRequired,
    isPublished: true,
    sortOrder: idx,
    conditionalParentId: cond ? cond.parent : null,
    conditionalTriggerValue: cond ? cond.trigger : null,
  });
  questions.push(mk(0, 'What is your current employment status?', 'single_select', ['Employed full-time','Employed part-time','Self-employed','Unemployed','Currently studying','Other'], true, null, null, true));
  questions.push(mk(1, 'Is your current work related to Computer Science?', 'single_select', ['Yes, directly related','Somewhat related','No, not related','Not applicable'], false, null, null, true));
  questions.push(mk(2, 'What is your current job role or industry?', 'single_select', ['Software Development','Web or Mobile Development','IT Support','Data or Database Management','Networking','Cybersecurity','Education','Government','Business','Other'], true, 'Enter your job role or industry', null, true));
  questions.push(mk(3, 'If your work is unrelated to Computer Science, what is the main reason?', 'single_select', ['Limited Computer Science job opportunities','Higher salary in another field','Personal interest','Location or family reasons','Career change','Other'], true, 'Enter your reason', null, false, { parent: qids[1], trigger: 'No, not related' }));
  questions.push(mk(4, 'Which Computer Science skills are still useful in your work?', 'multi_select', ['Programming','Problem-solving','Algorithms','Database management','Systems analysis','Digital literacy','Data analysis','Communication','Teamwork','None','Other'], true, 'Enter another skill', null, false));

  // Find admin to attribute
  const admins = await mysql.query("SELECT id FROM users WHERE role='admin' AND is_deleted=0 LIMIT 1");
  const createdBy = admins.length ? admins[0].id : null;

  await mysql.query(
    `INSERT INTO surveys (id, title, description, target_graduation_year, target_batch_year, opening_date, closing_date, status, allow_update, questions_json, visibility, is_active, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      surveyId,
      title,
      'Tracer survey for Computer Science graduates of Bohol Island State University. Your responses help improve curriculum and graduate support. All questions are editable by administrators.',
      null, null, fmt(now), fmt(closing), 'published', 0,
      JSON.stringify(questions), 'public', 1, createdBy
    ]
  );
  // sync normalized
  for (let i=0;i<questions.length;i++) {
    const q = questions[i];
    await mysql.query(
      `INSERT INTO survey_questions (id, survey_id, question_text, question_type, placeholder, character_limit, is_required, is_published, sort_order, conditional_parent_id, conditional_trigger_value, allow_other)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [q.id, surveyId, q.text, q.type, q.placeholder, q.characterLimit, q.isRequired?1:0, q.isPublished?1:0, q.sortOrder, q.conditionalParentId, q.conditionalTriggerValue, q.allowOther?1:0]
    );
    for (let j=0;j<q.options.length;j++) {
      const txt = q.options[j];
      const isOther = String(txt).toLowerCase() === 'other';
      await mysql.query(
        `INSERT INTO survey_question_options (id, question_id, option_text, sort_order, is_other) VALUES (?, ?, ?, ?, ?)`,
        [crypto.randomUUID(), q.id, txt, j, isOther?1:0]
      );
    }
  }
  console.log('[seed] created survey', surveyId, 'with', questions.length, 'questions');
  const check = await mysql.query('SELECT COUNT(*) AS c FROM survey_questions WHERE survey_id=? AND is_deleted=0', [surveyId]);
  console.log('[seed] questions in db:', check[0].c);
  await mysql.close();
}

main().catch(e=>{console.error(e);process.exit(1)});
