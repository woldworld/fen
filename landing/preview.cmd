@echo off
rem Double-click preview launcher for the landing site.
rem The site uses root-absolute paths (/style.css, /assets/...), so it MUST be
rem served over HTTP - opening dist\index.html directly via file:// shows a
rem broken, unstyled page. This script serves landing\dist and opens Edge.
cd /d "%~dp0dist"
start "" "http://127.0.0.1:4199/"
python -m http.server 4199 --bind 127.0.0.1
