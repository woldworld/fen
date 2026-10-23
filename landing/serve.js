#!/usr/bin/env node
/**
 * Local preview server for the built landing site (landing/dist).
 *
 * Why this exists: the pages reference the site root ("/style.css", "/lisbon/"),
 * which is correct for production but broken when opening index.html straight
 * off the filesystem. Preview through a server, not file://.
 *
 *   node serve.js            # http://127.0.0.1:4173/
 *   PORT=8080 node serve.js
 *
 * Binds loopback only - this is a preview tool, never expose it to the LAN.
 */

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const DIST = path.join(__dirname, 'dist');
const PORT = Number(process.env.PORT || 4173);
const HOST = '127.0.0.1';

if (!fs.existsSync(DIST)) {
  console.error('dist/ not found - run "node build.js" first.');
  process.exit(1);
}

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
};

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);

  // Resolve inside dist only - reject any traversal attempt outright.
  let filePath = path.join(DIST, path.normalize(urlPath));
  if (!filePath.startsWith(DIST)) {
    res.writeHead(403);
    res.end('forbidden');
    return;
  }

  let stat = null;
  try {
    stat = fs.statSync(filePath);
  } catch (e) {
    stat = null;
  }

  if (stat && stat.isDirectory()) filePath = path.join(filePath, 'index.html');
  else if (!stat) {
    // "/lisbon" (no trailing slash) -> directory exists -> index.html
    try {
      if (fs.statSync(path.join(DIST, path.normalize(urlPath), 'index.html'))) {
        filePath = path.join(DIST, path.normalize(urlPath), 'index.html');
      }
    } catch (e) {
      /* fall through to 404 */
    }
  }

  fs.readFile(filePath, (err, buf) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('404');
      return;
    }
    res.writeHead(200, {
      'Content-Type': TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(buf);
  });
});

server.listen(PORT, HOST, () => {
  console.log('landing preview: http://' + HOST + ':' + PORT + '/');
  console.log('serving        : ' + DIST);
  console.log('(loopback only - Ctrl+C to stop)');
});
