// Temporary: serves the built APK over LAN so a phone on the same Wi-Fi can
// download it without a USB cable. Delete after use.
const http = require('http');
const fs = require('fs');
const path = require('path');

const APK = path.join(__dirname, 'frontend', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const PORT = 8080;

http
  .createServer((req, res) => {
    if (req.url === '/' || req.url.startsWith('/app')) {
      const size = fs.statSync(APK).size;
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': size,
        'Content-Disposition': 'attachment; filename="GradTrack.apk"',
      });
      fs.createReadStream(APK).pipe(res);
      console.log(`${new Date().toISOString()} serving GradTrack.apk (${size} bytes)`);
    } else {
      res.writeHead(404);
      res.end('not found');
    }
  })
  .listen(PORT, '0.0.0.0', () => {
    console.log(`APK server running -> http://<PC-IP>:${PORT}`);
  });
