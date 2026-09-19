// Serves the built APK over LAN so a phone on same Wi-Fi can download without USB.
// Usage: node serve_apk.js  (then open http://<PC-IP>:8080 on phone)
// Boss Kim — now serves v1.0.3 (versionCode 4, targetSdk 34, minSdk 21) with robust headers, HTML landing, and split-ABI support.
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const APK_DIR = path.join(__dirname, 'frontend', 'build', 'app', 'outputs', 'flutter-apk');
const UNIVERSAL_APK = path.join(APK_DIR, 'app-release.apk');
const PORT = 8080;

function getLocalIps() {
  const nets = os.networkInterfaces();
  const ips = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) ips.push(net.address);
    }
  }
  return ips;
}

function safeStat(filePath) {
  try {
    return fs.statSync(filePath);
  } catch (_) {
    return null;
  }
}

function serveFile(res, filePath, fileName) {
  const stat = safeStat(filePath);
  if (!stat) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end('APK not found. Run: flutter build apk --release in frontend/');
  }
  res.writeHead(200, {
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename="${fileName}"`,
    'Cache-Control': 'no-cache',
    'Accept-Ranges': 'bytes',
    'Access-Control-Allow-Origin': '*',
  });
  const stream = fs.createReadStream(filePath);
  stream.on('error', (err) => {
    console.error('[serve] stream error', err.message);
    if (!res.headersSent) res.writeHead(500);
    res.end('Internal server error');
  });
  stream.pipe(res);
  console.log(`${new Date().toISOString()} serving ${fileName} (${stat.size} bytes) -> ${res.req?.socket?.remoteAddress || 'unknown'}`);
}

function landingHtml() {
  const universalStat = safeStat(UNIVERSAL_APK);
  const universalSize = universalStat ? (universalStat.size / (1024 * 1024)).toFixed(1) + ' MB' : 'missing — run flutter build apk --release';
  const universalName = 'GradTrack-v1.0.3+3-universal.apk';
  // check for split apks
  const splits = ['app-arm64-v8a-release.apk', 'app-armeabi-v7a-release.apk', 'app-x86_64-release.apk']
    .map((n) => ({ name: n, stat: safeStat(path.join(APK_DIR, n)) }))
    .filter((x) => x.stat);
  const splitLinks = splits.length
    ? `<h3>Split APKs (smaller, per ABI)</h3><ul>${splits.map((s) => `<li><a href="/apk/${s.name}">${s.name}</a> — ${(s.stat.size / (1024 * 1024)).toFixed(1)} MB</li>`).join('')}</ul><p>Most phones use <code>arm64-v8a</code>. If unsure, use universal.</p>`
    : '<p>Split APKs not built. Run <code>flutter build apk --split-per-abi --release</code> to generate smaller per-ABI apks.</p>';
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GradTrack APK — v1.0.3</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,sans-serif;max-width:720px;margin:40px auto;padding:0 20px;line-height:1.6;color:#1a1a1a}
  a.button{display:inline-block;padding:14px 22px;background:#0b57d0;color:#fff;text-decoration:none;border-radius:10px;font-weight:700;margin:8px 8px 8px 0}
  a.button.secondary{background:#e8f0fe;color:#0b57d0;border:1px solid #a8c7fa}
  code{background:#f1f3f4;padding:2px 6px;border-radius:6px;font-size:0.95em}
  .card{border:1px solid #dadce0;border-radius:16px;padding:20px;margin:20px 0;background:#fff}
  .ok{color:#137333;font-weight:700} .warn{color:#b3261e}
  ul{padding-left:20px}
</style></head><body>
<h1>GradTrack v1.0.3 (versionCode 4)</h1>
<p>Built: ${universalStat ? new Date(universalStat.mtime).toLocaleString() : '—'} — <span class="${universalStat ? 'ok' : 'warn'}">${universalSize}</span></p>
<div class="card">
  <h2>Install on your phone</h2>
  <p><strong>Recommended (universal):</strong> Works on all ABIs (arm64, arm, x86_64) — 78 MB</p>
  <a class="button" href="/apk/universal">⬇ Download Universal APK</a>
  <a class="button secondary" href="/apk/universal" download>Save as ${universalName}</a>
  ${splitLinks}
  <h3>Why install fails &amp; fixes</h3>
  <ul>
    <li><strong>App not installed / Package appears invalid</strong> — Download was truncated (use stable Wi-Fi, re-download). New build is signed v2+v3 (minSdk 21 = Android 5.0+, targetSdk 34). If your phone is Android 4.x, cannot install.</li>
    <li><strong>App not installed as package conflicts</strong> — Uninstall previous <code>com.gradtracker.app</code> first: <code>Settings → Apps → GradTrack → Uninstall</code>. Debug vs release have different signatures and <em>must not</em> coexist. Then try <code>adb uninstall com.gradtracker.app</code>.</li>
    <li><strong>Play Protect blocks install</strong> — Tap <em>Install anyway</em> / disable Play Protect temporarily, or enable <code>Install unknown apps</code> for your browser/file manager (Chrome → Allow).</li>
    <li><strong>Storage</strong> — Need ~150 MB free for arm64 (32 MB apk + unpack). Universal needs 300 MB. Clear cache if needed.</li>
    <li><strong>VersionCode</strong> — New APK is v3 (was v1/v2). If you had v1/v2 installed, Android requires higher versionCode — this build (arm64=2003, universal=3) satisfies that. If you had arm64 2002, arm64 2003 is update (2003>2002). Uninstall first if mixing universal ↔ split.</li>
  </ul>
  <h3>Quick checks on phone</h3>
  <ol>
    <li>Phone + PC on same Wi-Fi</li>
    <li>Enable: <code>Settings → Security → Install unknown apps → Allow</code> (Chrome / Files)</li>
    <li>Uninstall any old GradTrack first</li>
    <li>Re-download and tap APK in file manager (not just browser preview)</li>
  </ol>
  <p>APK details: <code>package=com.gradtracker.app</code>, <code>compileSdk 36</code>, <code>targetSdk 34</code>, <code>minSdk 21 (effective 24 via libs)</code>, signed release (CN=GradTrack, BISU Bilar), v2+v3 — <code>78.4 MB universal / 32.4 MB arm64</code></p>
</div>
<div class="card">
  <h3>Direct links</h3>
  <ul>
    <li><a href="/apk/universal">/apk/universal</a> — universal APK (recommended)</li>
    <li><a href="/apk/arm64">/apk/arm64</a> — arm64-v8a (≈ 35 MB, most phones)</li>
    <li><a href="/apk/armeabi">/apk/armeabi</a> — armeabi-v7a</li>
    <li><a href="/apk/x86_64">/apk/x86_64</a> — x86_64 (emulator)</li>
  </ul>
</div>
<p style="color:#5f6368;font-size:0.9em">Server: <code>node serve_apk.js</code> — serves ${APK_DIR} on port ${PORT}. PC IPs: ${getLocalIps().join(', ') || 'unknown'}</p>
</body></html>`;
}

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS', 'Access-Control-Allow-Headers': '*' });
    return res.end();
  }
  if (url === '/' || url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache', 'Access-Control-Allow-Origin': '*' });
    return res.end(landingHtml());
  }
  if (url === '/health' || url === '/ping') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ ok: true, version: '1.0.3+4', universal: !!safeStat(UNIVERSAL_APK) }));
  }
  // APK routes
  let filePath = null;
  let fileName = null;
  if (url === '/apk/universal' || url === '/app' || url === '/app-release.apk' || url === '/GradTrack.apk' || url.startsWith('/app')) {
    filePath = UNIVERSAL_APK;
    fileName = 'GradTrack-v1.0.3+3-universal.apk';
  } else if (url === '/apk/arm64' || url === '/apk/app-arm64-v8a-release.apk') {
    filePath = path.join(APK_DIR, 'app-arm64-v8a-release.apk');
    fileName = 'GradTrack-v1.0.3-arm64-v8a.apk';
  } else if (url === '/apk/armeabi' || url === '/apk/app-armeabi-v7a-release.apk') {
    filePath = path.join(APK_DIR, 'app-armeabi-v7a-release.apk');
    fileName = 'GradTrack-v1.0.3-armeabi-v7a.apk';
  } else if (url === '/apk/x86_64' || url === '/apk/app-x86_64-release.apk') {
    filePath = path.join(APK_DIR, 'app-x86_64-release.apk');
    fileName = 'GradTrack-v1.0.3-x86_64.apk';
  } else if (url.startsWith('/apk/')) {
    const base = path.basename(url);
    // sanitize
    if (!base.includes('..') && base.endsWith('.apk')) {
      filePath = path.join(APK_DIR, base);
      fileName = base;
    }
  }
  if (filePath) {
    if (req.method === 'HEAD') {
      const stat = safeStat(filePath);
      if (!stat) {
        res.writeHead(404);
        return res.end();
      }
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': stat.size,
        'Content-Disposition': `attachment; filename="${fileName}"`,
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      });
      return res.end();
    }
    return serveFile(res, filePath, fileName);
  }
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('not found — try / or /apk/universal');
});

server.listen(PORT, '0.0.0.0', () => {
  const ips = getLocalIps();
  console.log(`\n=== GradTrack APK server v1.0.3+3 (targetSdk 34, minSdk 21) ===`);
  console.log(`Universal APK: ${UNIVERSAL_APK} (${safeStat(UNIVERSAL_APK) ? (safeStat(UNIVERSAL_APK).size / (1024 * 1024)).toFixed(1) + ' MB' : 'MISSING'})`);
  console.log(`Listening on port ${PORT}`);
  ips.forEach((ip) => console.log(`  http://${ip}:${PORT}/  -> download on phone`));
  if (ips.length === 0) console.log(`  http://<PC-IP>:${PORT}/`);
  console.log(`Routes: / (landing) | /apk/universal (78 MB) | /apk/arm64 (32 MB) | /health\n`);
});
