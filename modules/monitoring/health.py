"""Expose only a boolean pipeline health result for the off-host watchdog."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
from urllib.parse import urlencode
from urllib.request import urlopen


def request_json(url):
    with urlopen(url, timeout=3) as response:
        return json.loads(response.read(65536))


def healthy(expected_targets):
    try:
        selector = 'up{host="amalthea"}'
        query = (f'min({selector}) * (count({selector}) == bool {expected_targets})'
                 f' * (max(time() - timestamp({selector})) < bool 180)')
        result = request_json('http://127.0.0.1:8427/api/v1/query?' + urlencode({'query': query, 'nocache': '1'}))
        values = result['data']['result']
        metrics_ok = result['status'] == 'success' and len(values) == 1 and float(values[0]['value'][1]) == 1
        grafana_ok = request_json('http://127.0.0.1:3002/api/health').get('database') == 'ok'
        return metrics_ok and grafana_ok
    except Exception:
        return False


def handler(expected_targets):
    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(10)

        def do_GET(self):
            if self.path != '/':
                self.send_error(404)
                return
            ok = healthy(expected_targets)
            data = json.dumps({'healthy': ok}).encode()
            self.send_response(200 if ok else 503)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass

    return Handler


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8425), handler(int(sys.argv[1]))).serve_forever()
