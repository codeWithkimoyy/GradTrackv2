const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

process.env.NODE_ENV = 'test';

const mysql = require('../src/config/mysql');
const surveysRouter = require('../src/routes/surveys');

const originalQuery = mysql.query;

afterEach(() => {
  mysql.query = originalQuery;
});

function updateSurveyHandler() {
  const layer = surveysRouter.stack.find(
    (candidate) =>
      candidate.route?.path === '/:id' && candidate.route.methods.patch,
  );
  assert.ok(layer, 'PATCH /:id survey route must exist');
  return layer.route.stack.at(-1).handle;
}

test('editing a survey reuses existing question and option IDs', async () => {
  const statements = [];
  mysql.query = async (sql, params = []) => {
    statements.push({ sql, params });

    if (sql.includes('SELECT q.id AS question_id')) {
      return [{ question_id: 'q1', option_id: 'o1' }];
    }
    if (sql.includes('INSERT INTO survey_questions')) {
      assert.match(sql, /ON DUPLICATE KEY UPDATE/);
      assert.equal(params[0], 'q1');
      return { affectedRows: 2 };
    }
    if (sql.includes('INSERT INTO survey_question_options')) {
      assert.match(sql, /ON DUPLICATE KEY UPDATE/);
      assert.equal(params[0], 'o1');
      return { affectedRows: 2 };
    }
    if (sql.startsWith('UPDATE surveys SET')) {
      return { affectedRows: 1 };
    }
    if (sql.startsWith('SELECT * FROM surveys')) {
      return [{ id: 'survey-1', title: 'Survey', questions_json: '[]' }];
    }
    if (sql.startsWith('SELECT * FROM survey_questions')) {
      return [];
    }
    return { affectedRows: 1 };
  };

  let responseBody;
  let routeError;
  await updateSurveyHandler()(
    {
      params: { id: 'survey-1' },
      body: {
        questions: [
          {
            id: 'q1',
            text: 'Updated question',
            type: 'single_select',
            options: [{ id: 'o1', text: 'Yes' }],
          },
        ],
      },
      user: { uid: 'admin-1', role: 'admin' },
    },
    {
      status() {
        return this;
      },
      json(value) {
        responseBody = value;
        return this;
      },
    },
    (error) => {
      routeError = error;
    },
  );

  if (routeError) throw routeError;
  assert.equal(responseBody.updated, true);
  assert.ok(
    statements.some(({ sql }) =>
      sql.startsWith('UPDATE survey_question_options'),
    ),
    'existing options must be soft-deleted before synchronization',
  );
});
