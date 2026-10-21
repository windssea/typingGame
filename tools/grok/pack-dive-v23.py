"""Extract reviewed original Grok poses, preserving native 24fps and common pivots."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

root=Path(__file__).resolve().parents[2]
jobs=[
    ('dive-scout-idle-v23','dive-scout-v23','idle',0,2,False),
    ('dive-scout-alert-v23','dive-scout-v23','alert',2,1.5,True),
    ('dive-scout-hit-v23','dive-scout-v23','hit',6,1.25,True),
    ('dive-armored-idle-v23','dive-armored-v23','idle',0,2,False),
    ('dive-armored-alert-v23','dive-armored-v23','alert',2,1.5,True),
    ('dive-armored-hit-v23','dive-armored-react-v23b','hit',3.25,1.25,True),
]
parser=argparse.ArgumentParser();parser.add_argument('--only',choices=[j[0] for j in jobs]);parser.add_argument('--cruise',action='store_true');args=parser.parse_args()
for name,source,state,start,seconds,once in jobs:
    if args.only and name!=args.only: continue
    if args.cruise and name=='dive-armored-hit-v23': continue
    out=root/'assets/animations'/name
    command=[sys.executable,str(root/'tools/grok/pack-animation.py'),'--video',str(root/f'build/animations/{source}/grok-raw.mp4'),'--out',str(out),'--start',str(start),'--seconds',str(seconds),'--cell','384','--inset','8','--key','ff00ff','--name',state]
    if once:command+=['--once']
    subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
    im=Image.open(out/'idle-atlas.png').convert('RGBA');pixels=np.array(im)
    rgb=pixels[:,:,:3].astype(float)
    boundary=np.array(im.getchannel('A').filter(ImageFilter.MinFilter(5)))<16
    spill=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
    mask=boundary & (pixels[:,:,3]>0) & (rgb[:,:,0]>180) & (rgb[:,:,2]>180) & (spill>65)
    pixels[:,:,3][mask]=np.round(pixels[:,:,3][mask]*(1-np.clip((spill[mask]-65)/90,0,1))).astype('uint8')
    pixels[:,:,:3][pixels[:,:,3]==0]=0
    Image.fromarray(pixels).save(out/'idle-atlas.png',compress_level=9)
    report=json.loads((out/'report.json').read_text(encoding='utf-8'));margins=[]
    for i in range(report['atlas']['frames']):
        x,y=i%8*384,i//8*384;points=np.argwhere(pixels[y:y+384,x:x+384,3]>32)
        ymin,xmin=points.min(axis=0);ymax,xmax=points.max(axis=0);margins.append(int(min(xmin,ymin,383-xmax,383-ymax)))
    assert min(margins)>=7,(name,min(margins))
    report.update({'status':'reviewed-native-source','minimum_frame_margin_px':min(margins),'loop_review':'native interval and mechanical silhouette inspected; common source-canvas pivot retained'})
    report['processing']+=['boundary-only magenta-spill alpha attenuation, no opaque interior recoloring']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(name,report['atlas']['frames'],'native frames; margin',min(margins),flush=True)
