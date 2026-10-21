"""Split exported, unchanged resource bytes into a menu bootstrap and per-game packs."""
from pathlib import Path
import argparse,collections,json,struct,subprocess,shutil

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--source',default='build/web')
parser.add_argument('--out',default='build/web-streamed')
parser.add_argument('--engine',default='D:/dev/windssea/game/godot4.7.2/Godot_v4.7.2-stable_win64_console.exe')
args=parser.parse_args();source=Path(args.source).resolve();dest=Path(args.out).resolve()
if source==dest:raise ValueError('Keep the original export in a separate directory')
dest.mkdir(parents=True,exist_ok=True);raw=dest/'extracted';raw.mkdir(exist_ok=True)
imports={}
for meta in (ROOT/'assets').rglob('*.import'):
 for line in meta.read_text(encoding='utf-8').splitlines():
  if line.startswith('path') and 'res://.godot/imported/' in line: imports[line.split('=',1)[1].strip('"').removeprefix('res://')]=str(meta.relative_to(ROOT))[:-7].replace('\\','/')
MODES=['dojo','bubbles','rain','sprint','castle','balloons','aliens','moles','racing','fighter','royal','submarine','restaurant']
backgrounds={'assets/generated/'+{'dojo':'skybridge-background-v13','balloons':'balloons-background-v2'}.get(m,m+'-background')+'.png':m for m in MODES}
backgrounds.update({f'assets/generated/v18/{m}-background.png':m for m in ['royal','submarine','restaurant','sprint']})
backgrounds['assets/generated/v17/castle-field.png']='castle'
backgrounds.pop('assets/generated/sprint-background.png',None)
backgrounds.pop('assets/generated/rain-background.png',None)
backgrounds['assets/generated/v20/rain-background.png']='rain'
animation_groups={
 'coach':'dojo','goblin':'goblins','wolf':'castle','boss':'bosses','guard':'castle','shaman':'castle','bomber':'castle','royal-guard':'castle',
 'mole':'moles','ufo':'aliens','rally':'racing','boxing':'fighter','knight':'royal','sub':'submarine','chef':'restaurant','balloon':'balloons','robot':'sprint'}
def group_for(path):
 s=imports.get(path,path)
 if not path.endswith('.ctex'):return 'core'
 if s.startswith('assets/menu-v20/') or s=='assets/generated/v18/cloud.png' or '/ui-' in s or not s.startswith(('assets/generated/','assets/animations/')):return 'core'
 if s.startswith('assets/animations/'):
  clip=s.split('/')[2]
  for prefix in sorted(animation_groups,key=len,reverse=True):
   if clip.startswith(prefix):return animation_groups[prefix]
  raise ValueError('Unclassified animation '+s)
 if s in backgrounds:return backgrounds[s]
 if s=='assets/generated/v20/kitchen-props.png':return 'restaurant'
 if s=='assets/generated/v22/comfort-tart.png':return 'restaurant'
 if s=='assets/generated/learning-sprites-v10.png':return 'learning'
 if s=='assets/generated/arcade-sprites.png':return 'arcade'
 if s=='assets/generated/castle-sprites.png' or s.startswith('assets/generated/v17/'):return 'castle'
 if s.startswith('assets/generated/v18/'):
  name=Path(s).stem
  if name in ['knight','goblin']:return 'royal'
  if name=='sub':return 'submarine'
  if name=='chef' or name.startswith(('food','customer')):return 'restaurant'
  if name=='cannon':return 'rain'
  if name=='robot':return 'sprint'
 # Older scenery and editor-only figures are not needed by the current menu or arenas.
 return 'unused'
groups=collections.defaultdict(list);inventory=[]
with (source/'index.pck').open('rb') as stream:
 def u32():return struct.unpack('<I',stream.read(4))[0]
 def u64():return struct.unpack('<Q',stream.read(8))[0]
 magic,version,major,minor,patch,flags=[u32() for _ in range(6)]
 if magic!=0x43504447 or version not in (3,4) or flags&1:raise ValueError('Unsupported or encrypted PCK')
 base=u64();directory=u64();stream.seek(directory);count=u32();entries=[]
 for _ in range(count):
  n=u32();path=stream.read(n).rstrip(b'\0').decode();offset=u64()+base;size=u64();stream.read(16);entry_flags=u32();entries.append((path,offset,size,entry_flags))
 for path,offset,size,entry_flags in entries:
  virtual=path.removeprefix('res://')
  if '..' in Path(virtual).parts:raise ValueError('Unsafe pack path')
  group=group_for(virtual)
  inventory.append({'path':virtual,'source':imports.get(virtual,virtual),'group':group,'bytes':size})
  if group=='unused':continue
  target=raw/virtual;target.parent.mkdir(parents=True,exist_ok=True)
  stream.seek(offset);target.write_bytes(stream.read(size))
  groups[group].append({'path':virtual,'file':str(target)})
plan={'groups':{g:{'output':str(dest/('index.pck' if g=='core' else f'content-{g}.pck')),'files':v} for g,v in groups.items()}}
(dest/'pack-plan.json').write_text(json.dumps(plan),encoding='utf-8')
subprocess.run([args.engine,'--headless','--path',str(ROOT),'--script','tools/build-content-packs.gd','--',str(dest/'pack-plan.json')],check=True)
for item in source.iterdir():
 if item.is_file() and item.name!='index.pck':shutil.copy2(item,dest/item.name)
requirements={m:([('arcade' if m in ['balloons','aliens','moles','racing','fighter'] else 'learning')]+[m] if m in ['dojo','bubbles','rain','sprint','balloons','aliens','moles','racing','fighter'] else [m]) for m in MODES}
for mode in ['castle','royal']:requirements[mode]=['goblins','bosses']+requirements[mode]
manifest={'modes':requirements,'packs':{g:{'file':f'content-{g}.pck','bytes':(dest/f'content-{g}.pck').stat().st_size} for g in groups if g!='core'}}
for mode,dependencies in requirements.items():
 if any(group not in manifest['packs'] for group in dependencies):raise ValueError('Missing content dependency for '+mode)
(dest/'content-packs.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(dest/'pack-inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
html=(dest/'index.html').read_text(encoding='utf-8');original=(source/'index.pck').stat().st_size;size=(dest/'index.pck').stat().st_size
html=html.replace(f'"index.pck":{original}',f'"index.pck":{size}')
(dest/'index.html').write_text(html,encoding='utf-8')
print(json.dumps({'bootstrap_bytes':size,'original_bytes':original,'groups':{g:sum(i['bytes'] for i in inventory if i['group']==g) for g in groups},'discarded_unused_bytes':sum(i['bytes'] for i in inventory if i['group']=='unused')},indent=2))
