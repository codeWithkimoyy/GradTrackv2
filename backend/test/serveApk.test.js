const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { after, before, test } = require('node:test');

let child;

function request(pathname, method = 'GET') {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: '127.0.0.1', port: 8080, path: pathname, method },
      (res) => {
        res.resume();
        res.on('end', () => resolve(res));
      },
    );
    req.on('error', reject);
    req.end();
  });
}

before(async () => {
  child = spawn(process.execPath, [path.join(__dirname, '../../serve_apk.js')], {
    stdio: 'ignore',
  });
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await request('/health');
      if (response.statusCode === 200) return;
    } catch (_) {
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }
  throw new Error('APK server did not start');
});

after(() => {
  child?.kill();
});

test('unknown app-prefixed paths return 404', async () => {
  assert.equal((await request('/application')).statusCode, 404);
  assert.equal((await request('/apple')).statusCode, 404);
});

test('complete APK responses do not advertise byte ranges', async () => {
  const response = await request('/apk/universal', 'HEAD');
  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['accept-ranges'], undefined);
});
