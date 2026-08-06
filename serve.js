const http = require('http');
const fs = require('fs');
const path = require('path');
const dir = 'build/web';
http.createServer((q, r) => {
  let f = path.join(dir, q.url === '/' ? 'index.html' : q.url);
  fs.readFile(f, (e, d) => {
    if (e) { r.writeHead(404); r.end('Not found'); }
    else {
      const ct = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png', '.json': 'application/json' };
      r.writeHead(200, { 'Content-Type': ct[path.extname(f)] || 'text/plain' });
      r.end(d);
    }
  });
}).listen(8080, () => {
  console.log('Running on http://localhost:8080');
  require('child_process').exec('start http://localhost:8080');
});
