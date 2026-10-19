"""Local R2 header/CORS simulator for testing the deployment package, not a public server."""
import argparse
import json
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--package',required=True)
parser.add_argument('--port',type=int,default=8766)
args=parser.parse_args()
root=Path(args.package).resolve()
manifest=json.loads((root/'manifest.json').read_text())
objects={'/'+entry['key']:entry for entry in manifest['objects']}

class Handler(SimpleHTTPRequestHandler):
    def do_HEAD(self): self.serve(False)
    def do_GET(self): self.serve(True)
    def serve(self,body):
        item=objects.get(self.path.split('?')[0])
        if not item:
            self.send_error(404)
            return
        data=Path(item['file']).read_bytes()
        self.send_response(200)
        self.send_header('Content-Type',item['content_type'])
        self.send_header('Content-Encoding',item['content_encoding'])
        self.send_header('Content-Length',str(len(data)))
        self.send_header('Access-Control-Allow-Origin','http://127.0.0.1:8765')
        self.send_header('Access-Control-Expose-Headers','Content-Length, Content-Encoding, ETag')
        self.end_headers()
        if body: self.wfile.write(data)

ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
