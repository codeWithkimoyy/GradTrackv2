const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const host = process.env.HOST ?? '127.0.0.1';
const port = Number.parseInt(process.env.PORT ?? '8080', 10);
const webRoot = path.resolve(__dirname, 'build/web');

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

function sendFile(response, filePath) {
  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      response.end('Unable to read the web build.');
      return;
    }

    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(filePath)] ??
          'application/octet-stream',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end(data);
  });
}

const server = http.createServer((request, response) => {
  const requestPath = decodeURIComponent(new URL(request.url, 'http://local').pathname);
  const relativePath = requestPath === '/' ? 'index.html' : requestPath.slice(1);
  const candidate = path.resolve(webRoot, relativePath);

  if (!candidate.startsWith(`${webRoot}${path.sep}`) && candidate !== webRoot) {
    response.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Forbidden');
    return;
  }

  fs.stat(candidate, (error, stat) => {
    if (!error && stat.isFile()) {
      sendFile(response, candidate);
      return;
    }

    // Flutter web uses client-side routing, so unknown paths return index.html.
    sendFile(response, path.join(webRoot, 'index.html'));
  });
});

server.listen(port, host, () => {
  console.log(`GradTrack frontend running on http://${host}:${port}`);
});
