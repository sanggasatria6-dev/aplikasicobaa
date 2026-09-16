import http.server
import socketserver
import urllib.request
import urllib.error
import sys
import os

PORT = 54321
DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "build/web"))
BACKEND_URL = "https://api.satriasangga.my.id"

class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_proxy(self):
        target_url = f"{BACKEND_URL}{self.path}"
        content_len = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_len) if content_len > 0 else None
        
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ['host', 'content-length']}
        headers['Host'] = 'api.satriasangga.my.id'
        if 'User-Agent' not in headers or 'python' in headers.get('User-Agent', '').lower():
            headers['User-Agent'] = 'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15'

        req = urllib.request.Request(target_url, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in ['transfer-encoding', 'content-encoding', 'access-control-allow-origin']:
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in ['transfer-encoding', 'content-encoding', 'access-control-allow-origin']:
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            err_msg = f'{{"success": false, "message": "Proxy Error: {str(e)}"}}'.encode('utf-8')
            self.wfile.write(err_msg)

    def do_GET(self):
        if self.path.startswith('/api/'):
            self.do_proxy()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self.do_proxy()
        else:
            self.send_error(404)

    def do_PUT(self):
        if self.path.startswith('/api/'):
            self.do_proxy()
        else:
            self.send_error(404)

    def do_DELETE(self):
        if self.path.startswith('/api/'):
            self.do_proxy()
        else:
            self.send_error(404)

class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

if __name__ == '__main__':
    with ThreadingHTTPServer(('0.0.0.0', PORT), ProxyHTTPRequestHandler) as httpd:
        print(f"Serving {DIRECTORY} on port {PORT} with API proxy to {BACKEND_URL}")
        httpd.serve_forever()
