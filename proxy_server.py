import http.server
import socketserver
import os
import sys
import requests

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
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_proxy(self):
        target_url = f"{BACKEND_URL}{self.path}"
        content_len = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_len) if content_len > 0 else None
        
        # Exclude host, content-length, and accept-encoding so requests handles decompression automatically
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ['host', 'content-length', 'accept-encoding']}
        headers['Host'] = 'api.satriasangga.my.id'
        if 'User-Agent' not in headers or 'python' in headers.get('User-Agent', '').lower():
            headers['User-Agent'] = 'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15'

        try:
            resp = requests.request(
                method=self.command,
                url=target_url,
                data=body,
                headers=headers,
                timeout=30,
                allow_redirects=True
            )
            
            self.send_response(resp.status_code)
            for k, v in resp.headers.items():
                if k.lower() not in [
                    'transfer-encoding',
                    'content-encoding',
                    'content-length',
                    'access-control-allow-origin',
                    'access-control-allow-methods',
                    'access-control-allow-headers'
                ]:
                    self.send_header(k, v)
            
            content = resp.content
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except requests.exceptions.RequestException as e:
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
