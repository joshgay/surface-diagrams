"""Local-only browser editor: python -m surface_diagrams.editor.

No third-party runtime dependencies, telemetry, remote assets or file-serving
root. The browser owns file open/save; the server only renders bounded recipes.
"""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from importlib import resources
import json
import secrets
import webbrowser

from .documents import DiagramDocument, MAX_DOCUMENT_BYTES, example_document
from .curves import RoutingError


class EditorServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port=0):
        # Deliberately no host option. This server is not a public deployment.
        super().__init__(('127.0.0.1', port), EditorHandler)
        self.token = secrets.token_urlsafe(32)
        self.allowed_hosts = {f'127.0.0.1:{self.server_port}', f'localhost:{self.server_port}'}

    @property
    def url(self):
        return f'http://127.0.0.1:{self.server_port}'


class EditorHandler(BaseHTTPRequestHandler):
    server_version = 'SurfaceDiagramsEditor'

    def log_message(self, format, *args):
        pass  # Do not write diagram contents or document titles to logs.

    def _reply(self, status, content, mime='application/json; charset=utf-8', filename=None):
        if not isinstance(content, bytes):
            content = content.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.send_header('Connection', 'close')
        if filename:
            self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
        self.end_headers()
        self.close_connection = True
        try:
            self.wfile.write(content)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _error(self, status, message):
        self._reply(status, json.dumps({'error': message}))

    def _local_request(self):
        # Host allowlisting blocks DNS rebinding to this loopback service.
        if self.headers.get('Host') not in self.server.allowed_hosts:
            self._error(403, 'Only the local editor origin is accepted')
            return False
        origin = self.headers.get('Origin')
        if origin is not None and origin not in {'http://'+h for h in self.server.allowed_hosts}:
            self._error(403, 'Cross-origin requests are not accepted')
            return False
        return True

    def do_GET(self):
        if not self._local_request():
            return
        if self.path == '/api/session':
            self._reply(200, json.dumps({'token': self.server.token,
                'examples': {kind: example_document(kind).to_dict() for kind in ('planar', 'braid')}}))
            return
        assets = {'/': ('index.html', 'text/html; charset=utf-8'),
                  '/editor.js': ('editor.js', 'text/javascript; charset=utf-8'),
                  '/editor.css': ('editor.css', 'text/css; charset=utf-8')}
        if self.path not in assets:
            self._error(404, 'Not found')
            return
        name, mime = assets[self.path]
        self._reply(200, resources.files('surface_diagrams').joinpath('editor_assets', name).read_bytes(), mime)

    def do_POST(self):
        if not self._local_request():
            return
        if not secrets.compare_digest(self.headers.get('X-Surface-Token', '').encode('utf-8'), self.server.token.encode('ascii')):
            self._error(403, 'Open the local editor before submitting a recipe')
            return
        if self.path not in ('/api/render', '/api/validate', '/api/export/svg', '/api/export/tikz', '/api/export/python'):
            self._error(404, 'Not found')
            return
        if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
            self._error(415, 'Submit an application/json recipe')
            return
        if self.headers.get('Transfer-Encoding'):
            self._error(400, 'Transfer encoding is not supported')
            return
        try:
            length = int(self.headers.get('Content-Length', '-1'))
        except ValueError:
            length = -1
        if not 0 <= length <= MAX_DOCUMENT_BYTES:
            self._error(413, 'Submit a recipe of at most 256 KiB with Content-Length')
            return
        try:
            self.connection.settimeout(10)
            payload = self.rfile.read(length)
            if len(payload) != length:
                raise ValueError('Incomplete request body')
            document = DiagramDocument.from_json(payload.decode('utf-8'))
            if self.path == '/api/validate':
                self._reply(200, document.to_json())
            elif self.path == '/api/render':
                self._reply(200, json.dumps(document.preview(), allow_nan=False))
            else:
                # All image/code exports require a geometrically renderable
                # recipe; JSON draft downloads are handled by the browser.
                document.drawing(document.style)
                kind = self.path.rsplit('/', 1)[1]
                content = {'svg': document.render_svg, 'tikz': document.render_tikz,
                           'python': document.python_source}[kind]()
                mime = 'image/svg+xml; charset=utf-8' if kind == 'svg' else 'text/plain; charset=utf-8'
                self._reply(200, content, mime, 'diagram.'+('py' if kind == 'python' else kind))
        except RoutingError as error:
            self._error(422, str(error))
        except (UnicodeError, ValueError, TypeError, RecursionError, OverflowError) as error:
            self._error(400, str(error))
        except (TimeoutError, ConnectionResetError):
            self._error(408, 'The request did not finish in time')


def main(argv=None):
    parser = argparse.ArgumentParser(description='Open the local surface-diagrams browser editor.')
    parser.add_argument('--port', type=int, default=0, help='local port; 0 selects a free port (default)')
    parser.add_argument('--no-browser', action='store_true', help='print the URL without opening a browser')
    args = parser.parse_args(argv)
    if not 0 <= args.port <= 65535:
        parser.error('port must be between 0 and 65535')
    try:
        server = EditorServer(args.port)
    except OSError as error:
        parser.error(str(error))
    print('Surface diagrams editor: '+server.url, flush=True)
    print('Local only. Press Ctrl+C to stop.', flush=True)
    if not args.no_browser:
        webbrowser.open(server.url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
