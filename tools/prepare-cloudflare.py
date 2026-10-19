"""Split a verified Godot Web export into Pages shell and versioned R2 payloads."""
import argparse
import gzip
import hashlib
import json
import shutil
from pathlib import Path
from urllib.parse import urlparse

parser=argparse.ArgumentParser()
parser.add_argument('--asset-base-url',required=True)
parser.add_argument('--project',default='typinggame')
parser.add_argument('--page-origin',help='Actual Pages origin returned by project creation; may differ from project name')
parser.add_argument('--source',default='build/web')
parser.add_argument('--out',default='build/cloudflare')
args=parser.parse_args()
base=args.asset_base_url.rstrip('/')
parsed=urlparse(base)
if parsed.scheme not in ['https','http'] or not parsed.netloc or parsed.query or parsed.fragment:
    raise SystemExit('Use a public R2 origin URL with an optional path, no query or fragment')
source=Path(args.source).resolve()
output=Path(args.out).resolve()
pages=output/'pages'
payload=output/'r2'
if pages.exists() and any(pages.iterdir()):
    raise SystemExit('Output already contains a Pages build; use a new --out directory')
pages.mkdir(parents=True,exist_ok=True)
payload.mkdir(parents=True,exist_ok=True)
mapping={}
objects=[]
for name,mime in [('index.wasm','application/wasm'),('index.pck','application/octet-stream')]:
    raw=(source/name).read_bytes()
    digest=hashlib.sha256(raw).hexdigest()
    suffix=Path(name).suffix
    key=f'keybound/{"engine" if suffix==".wasm" else "game"}-{digest[:20]}{suffix}'
    compressed=gzip.compress(raw,compresslevel=9,mtime=0)
    target=payload/Path(key).name
    target.write_bytes(compressed)
    mapping[name]=base+'/'+key
    objects.append({'key':key,'file':str(target),'content_type':mime,'content_encoding':'gzip','cache_control':'public, max-age=31536000, immutable','raw_bytes':len(raw),'upload_bytes':len(compressed),'sha256':digest})
for item in source.iterdir():
    if item.is_file() and item.name not in mapping:
        if item.stat().st_size>25*1024*1024:
            raise SystemExit('Unexpected large shell asset: '+item.name)
        shutil.copy2(item,pages/item.name)
html=(pages/'index.html').read_text(encoding='utf-8')
loader='''<script>
// Versioned public game payloads live on R2; Godot keeps its local virtual file names.
(() => {
 const assets = ASSET_MAPPING;
 const nativeFetch = window.fetch.bind(window);
 const local = Object.fromEntries(Object.entries(assets).map(([name,url]) => [new URL(name,location.href).href,url]));
 window.fetch = (input, options) => {
  const url = new URL(input instanceof Request ? input.url : String(input),location.href).href;
  return local[url] ? nativeFetch(local[url],{...options,mode:'cors',credentials:'omit'}) : nativeFetch(input,options);
 };
})();
</script>
'''.replace('ASSET_MAPPING',json.dumps(mapping,separators=(',',':')))
marker='<script src="index.js"></script>'
if marker not in html:
    raise SystemExit('Unrecognized Godot shell; no changes written to the source export')
(pages/'index.html').write_text(html.replace(marker,loader+marker),encoding='utf-8')
(pages/'_headers').write_text('/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n/index.html\n  Cache-Control: no-cache\n',encoding='utf-8')
page_origin=args.page_origin or f'https://{args.project}.pages.dev'
cors={'rules':[{'allowed':{'origins':[page_origin,'http://127.0.0.1:8765'],'methods':['GET','HEAD'],'headers':['Range']},'exposeHeaders':['Content-Length','Content-Encoding','ETag'],'maxAgeSeconds':3600}]}
(output/'cors.json').write_text(json.dumps(cors,indent=2),encoding='utf-8')
manifest={'project':args.project,'page_origin':page_origin,'asset_base_url':base,'pages_directory':str(pages),'objects':objects}
(output/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
