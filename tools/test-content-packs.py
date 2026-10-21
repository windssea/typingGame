"""Test every game with ONLY its declared exported packs mounted."""
import argparse,json,subprocess,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--source',default='build/web-streamed')
parser.add_argument('--engine',default='D:/dev/windssea/game/godot4.7.2/Godot_v4.7.2-stable_win64_console.exe')
args=parser.parse_args();source=Path(args.source).resolve()
manifest=json.loads((source/'content-packs.json').read_text())
sandbox=root/'build/pack-sandbox';sandbox.mkdir(exist_ok=True)
results=[]
for mode,groups in manifest['modes'].items():
 command=[args.engine,'--headless','--path',str(sandbox),'--main-pack',str(source/'index.pck'),'--script',str(root/'tests/content_pack_resources.gd'),'--',mode]
 command.extend(str(source/manifest['packs'][group]['file']) for group in groups)
 process=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 log=process.stdout.decode('utf-8',errors='replace')
 (root/f'build/v20-pack-{mode}.log').write_text(log,encoding='utf-8')
 errors=re.findall(r'^(?:SCRIPT ERROR|ERROR:).*',log,re.M)
 result={'mode':mode,'exit':process.returncode,'errors':errors,'passed':process.returncode==0 and not errors and 'checks; 0 failures' in log}
 results.append(result);print(json.dumps(result),flush=True)
(root/'build/v20-pack-tests.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
raise SystemExit(int(not all(result['passed'] for result in results)))
