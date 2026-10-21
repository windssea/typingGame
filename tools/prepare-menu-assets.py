"""Derive light menu previews; full-resolution gameplay art is left untouched."""
from pathlib import Path
import json,re,subprocess,shutil
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/menu-v20';OUT.mkdir(exist_ok=True)
MODES=['dojo','bubbles','rain','sprint','castle','balloons','aliens','moles','racing','fighter','royal','submarine','restaurant']
regions=json.loads((ROOT/'assets/generated/regions.json').read_text(encoding='utf-8'))
clips={'dojo':'coach-idle-hd-v11','aliens':'ufo-idle-hd-v11','moles':'mole-idle-hd-v11','racing':'rally-drive-hd-v11','fighter':'boxing-blue-idle-hd-v11','royal':'knight-v18','submarine':'sub-v18','restaurant':'chef-stir-v18'}
def background(mode):
 if mode=='rain':return 'assets/generated/v20/rain-background.png'
 if mode in ['royal','submarine','restaurant','sprint']:return f'assets/generated/v18/{mode}-background.png'
 if mode=='castle':return 'assets/generated/v17/castle-field.png'
 return 'assets/generated/'+{'dojo':'skybridge-background-v13','balloons':'balloons-background-v2'}.get(mode,mode+'-background')+'.png'
def convert(source,target,filters):
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(ROOT/source),'-vf',filters,'-frames:v','1',str(OUT/target)],check=True)
for mode in MODES:
 convert(background(mode),f'bg-{mode}.png','scale=576:324:force_original_aspect_ratio=increase,crop=576:324')
 crop=''
 if mode in clips:
  directory=ROOT/'assets/animations'/clips[mode]
  rect=[int(float(v.strip())) for v in re.search(r'region = Rect2\(([^)]+)\)',(directory/'idle.tres').read_text()).group(1).split(',')]
  source=str((directory/'idle-atlas.png').relative_to(ROOT));crop=f'crop={rect[2]}:{rect[3]}:{rect[0]}:{rect[1]},'
 elif mode=='castle':source='assets/generated/v17/tower-fire.png'
 else:
  family='arcade' if mode=='balloons' else 'learning';key={'bubbles':'bubble','rain':'comet','sprint':'stopwatch','balloons':'balloon_coral'}[mode]
  rect=regions[family][key];source=f'assets/generated/{"learning-sprites-v10" if family=="learning" else "arcade-sprites"}.png'
  crop=f'crop={rect[2]}:{rect[3]}:{rect[0]}:{rect[1]},'
 convert(source,f'icon-{mode}.png',crop+'scale=320:320:force_original_aspect_ratio=decrease,pad=320:320:(ow-iw)/2:(oh-ih)/2:color=0x00000000')
for name,source in [('lobby','academy-lobby-v10'),('settings','dojo-background')]:
 shutil.copy2(ROOT/f'assets/generated/{source}.png',OUT/f'{name}.png')
print('Prepared 13 light previews, 13 icons and 2 full-resolution menu backgrounds.')
