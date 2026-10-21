"""Normalize generated entrance props and reuse reviewed native 24fps Grok clips."""
from pathlib import Path
from PIL import Image
import numpy as np
import re,json,hashlib,shutil
root=Path(__file__).resolve().parents[1]
out=root/'assets/menu-v25';out.mkdir(exist_ok=True)
source=Path('C:/Users/windssea/.codex/generated_images/01a15294-8334-75c2-ab9d-fb510040e509/exec-8eb25249-9e0b-4a75-8e18-9c3572ea8612.png')
shutil.copyfile(source,out/'entrances.png')
im=Image.open(source).convert('RGBA')
report={'generator':'built-in ImageGen; transparent_background=true','asset':'assets/menu-v25/entrances.png','size':im.size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'alpha_extrema':im.getchannel('A').getextrema(),'native_animation_reuse':[]}
for name,clip in [('coach','coach-idle-hd-v11'),('coach-cheer','coach-cheer-hd-v11'),('knight','knight-v18')]:
    text=(root/f'assets/animations/{clip}/idle.tres').read_text()
    atlas=Image.open(root/f'assets/animations/{clip}/idle-atlas.png').convert('RGBA')
    regions=re.findall(r'region = Rect2\((\d+), (\d+), (\d+), (\d+)\)',text)
    sheet=Image.new('RGBA',(256*8,256*6))
    removed_key_pixels=0
    for i,region in enumerate(regions):
        x,y,w,h=map(int,region)
        frame=atlas.crop((x,y,x+w,y+h)).resize((256,256),Image.Resampling.LANCZOS)
        pixels=np.array(frame)
        rgb=pixels[:,:,:3].astype(float)
        residue=(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)&(rgb[:,:,0]>70)&(rgb[:,:,2]>70)&(pixels[:,:,3]>0)
        removed_key_pixels+=int(residue.sum())
        pixels[residue,3]=0
        frame=Image.fromarray(pixels)
        sheet.paste(frame,(i%8*256,i//8*256))
    sheet.save(out/f'{name}-atlas.png',optimize=True)
    text=text.replace(f'assets/animations/{clip}/idle-atlas.png',f'assets/menu-v25/{name}-atlas.png')
    count=iter(range(len(regions)))
    text=re.sub(r'region = Rect2\(\d+, \d+, \d+, \d+\)',lambda m:(lambda i:f'region = Rect2({i%8*256}, {i//8*256}, 256, 256)')(next(count)),text)
    (out/f'{name}.tres').write_text(text,encoding='utf-8')
    report['native_animation_reuse'].append({'source':f'assets/animations/{clip}/idle.tres','runtime':f'assets/menu-v25/{name}.tres','frames':len(regions),'fps':24,'frame_interpolation':False,'new_generation':False,'source_magenta_key_residue_pixels_removed':removed_key_pixels})
for meta in out.glob('*.png.import'):
    settings=meta.read_text(encoding='utf-8').replace('compress/mode=0','compress/mode=1').replace('compress/lossy_quality=0.7','compress/lossy_quality=0.88').replace('mipmaps/generate=false','mipmaps/generate=true')
    meta.write_text(settings,encoding='utf-8')
(out/'art-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(out/'image-prompt.txt').write_text('Matched transparent floating island entrance dioramas. Left: mint/ivory keyboard learning pavilion, warm brass and keycap props. Right: cobalt/ivory original royal adventure gate with blue/coral flags and crystals. Empty central stages for real animated characters. Eye-level slightly elevated frontal three-quarter view. Premium bright American stylized cartoon art, large forms, unified upper-left sunlight, clean alpha silhouettes and contact shadows. No text, characters, UI cards or copied emblems.\n',encoding='utf-8')
print(json.dumps(report))
