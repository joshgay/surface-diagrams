import http.client
import json
import threading
import unittest

from surface_diagrams.documents import MAX_DOCUMENT_BYTES, example_document
from surface_diagrams.editor import EditorServer, main


class EditorHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = EditorServer()
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def request(self, path='/', method='GET', body=None, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=10)
        try:
            connection.request(method, path, body, headers or {})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read().decode('utf-8')
        finally:
            connection.close()

    def post(self, path='/api/render', body=None, headers=None):
        values = {'Content-Type': 'application/json', 'X-Surface-Token': self.server.token}
        values.update(headers or {})
        return self.request(path, 'POST', example_document().to_json() if body is None else body, values)

    def test_loopback_only_and_random_token(self):
        self.assertEqual(self.server.server_address[0], '127.0.0.1')
        other = EditorServer()
        try:
            self.assertNotEqual(other.token, self.server.token)
            self.assertGreaterEqual(len(other.token), 40)
        finally:
            other.server_close()

    def test_session_and_assets(self):
        for path, mime in [('/', 'text/html'), ('/editor.js', 'text/javascript'), ('/editor.css', 'text/css')]:
            status, headers, content = self.request(path)
            self.assertEqual(status, 200)
            self.assertIn(mime, headers['Content-Type'])
            self.assertGreater(len(content), 100)
        status, _, content = self.request('/api/session')
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(content)['token'], self.server.token)
        self.assertEqual(set(json.loads(content)['examples']), {'planar', 'braid'})

    def test_security_headers_and_no_cors(self):
        _, headers, _ = self.request()
        self.assertEqual(headers['X-Content-Type-Options'], 'nosniff')
        self.assertEqual(headers['Cache-Control'], 'no-store')
        self.assertIn("frame-ancestors 'none'", headers['Content-Security-Policy'])
        self.assertNotIn('Access-Control-Allow-Origin', headers)

    def test_host_and_origin_block_rebinding(self):
        for headers in ({'Host': 'attacker.example'}, {'Origin': 'https://attacker.example'},
                        {'Origin': 'null'}, {'Host': '127.0.0.1:1'}):
            with self.subTest(headers=headers):
                self.assertEqual(self.request('/api/session', headers=headers)[0], 403)
                self.assertEqual(self.post(headers=headers)[0], 403)
        self.assertEqual(self.request(headers={'Host': f'localhost:{self.server.server_port}'})[0], 200)

    def test_post_requires_session_token(self):
        for token in ('', 'invalid', '\u00e9'):
            self.assertEqual(self.post(headers={'X-Surface-Token': token})[0], 403)

    def test_paths_are_not_a_file_server(self):
        for path in ('/../../pyproject.toml', '/src/surface_diagrams/editor.py', '/api/export/../../file', '/api/eval'):
            with self.subTest(path=path):
                self.assertEqual(self.request(path)[0], 404)
                self.assertEqual(self.post(path)[0], 404)

    def test_render_response(self):
        status, _, content = self.post()
        self.assertEqual(status, 200, content)
        preview = json.loads(content)
        self.assertEqual(preview['svg'], example_document().render_svg())
        self.assertEqual(len(preview['handles']), 6)

    def test_validate_normalizes_recipe(self):
        status, _, content = self.post('/api/validate')
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(content), example_document().to_dict())

    def test_all_exports_are_exact_and_attachment_named(self):
        document = example_document()
        for kind, expected in [('svg', document.render_svg()), ('tikz', document.render_tikz()), ('python', document.python_source())]:
            status, headers, content = self.post('/api/export/'+kind)
            self.assertEqual(status, 200)
            self.assertEqual(content, expected)
            self.assertIn('attachment;', headers['Content-Disposition'])

    def test_bad_content_type_size_and_transfer_encoding(self):
        for headers, status in [({'Content-Type': 'text/plain'}, 415),
                                ({'Content-Length': str(MAX_DOCUMENT_BYTES+1)}, 413),
                                ({'Content-Length': '-1'}, 413), ({'Content-Length': 'bad'}, 413),
                                ({'Transfer-Encoding': 'chunked'}, 400)]:
            with self.subTest(headers=headers):
                self.assertEqual(self.post(headers=headers)[0], status)

    def test_bad_json_and_duplicate_fields(self):
        for body in ('{', '{"version":1,"version":1}', '[]', 'null'):
            status, _, content = self.post(body=body)
            self.assertEqual(status, 400)
            self.assertIn('error', json.loads(content))

    def test_invalid_geometry_can_be_reopened_but_not_exported(self):
        data = example_document().to_dict()
        data['curves'].append({'id': 'other', 'kind': 'arc', 'start': 2, 'end': 4})
        body = json.dumps(data)
        self.assertEqual(self.post('/api/validate', body=body)[0], 200)
        for path in ('/api/render', '/api/export/svg', '/api/export/tikz', '/api/export/python'):
            status, _, content = self.post(path, body=body)
            self.assertIn(status, (400, 422), content)
            self.assertIn('error', json.loads(content))

    def test_cli_port_validation(self):
        with self.assertRaises(SystemExit) as raised:
            main(['--port', '65536'])
        self.assertEqual(raised.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
