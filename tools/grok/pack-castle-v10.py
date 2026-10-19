"""Pack reviewed native-frame wolf and boss clips; remove isolated keying residue."""
from pathlib import Path
import json
import subprocess
import sys
import argparse
from collections import deque
import numpy as np
from PIL import Image,ImageFilter

root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--kind',choices=['all','wolf','boss','guard','shaman','bomber'],default='all')
parser.add_argument('--version',default='v10')
args=parser.parse_args()
for kind in (['wolf','boss','guard','shaman','bomber'] if args.kind=='all' else [args.kind]):
    cell=192 if kind in ['wolf','boss'] else 128
    source=root/f'build/animations/{kind}-motion-v10/v001/grok-raw.mp4'
    for state,start,seconds in [('walk',.25,2.0),('hit',5.25,.75)]:
        destination=root/f'assets/animations/{kind}-{state}-{args.version}'
        command=[sys.executable,str(root/'tools/grok/pack-animation.py'),'--video',str(source),'--out',str(destination),'--start',str(start),'--seconds',str(seconds),'--cell',str(cell),'--key','ff00ff','--name','idle' if state=='walk' else 'hit']
        command+=['--crop','96:96:528:528'] if kind=='wolf' else ['--inset','12']
        if state=='hit': command.append('--once')
        subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
        image=Image.open(destination/'idle-atlas.png').convert('RGBA')
        rgba=np.array(image)
        rgb=rgba[:,:,:3].astype(float)
        near=np.array(image.getchannel('A').filter(ImageFilter.MinFilter(5)))<16
        spill=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        mask=near & (rgba[:,:,3]>0) & (rgb[:,:,0]>180) & (rgb[:,:,2]>180) & (spill>65)
        rgba[:,:,3][mask]=np.round(rgba[:,:,3][mask]*(1-np.clip((spill[mask]-65)/90,0,1))).astype('uint8')
        report=json.loads((destination/'report.json').read_text())
        cells=report['atlas']['frames']
        removed=0
        margins=[]
        for frame in range(cells):
            x,y=(frame%8)*cell,(frame//8)*cell
            alpha=rgba[y:y+cell,x:x+cell,3]
            active=alpha>24
            visited=np.zeros((cell,cell),dtype=bool)
            groups=[]
            for py,px in zip(*np.where(active)):
                if visited[py,px]: continue
                queue=deque([(py,px)]);visited[py,px]=True;group=[]
                while queue:
                    cy,cx=queue.popleft();group.append((cy,cx))
                    for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]:
                        ny,nx=cy+dy,cx+dx
                        if 0<=ny<cell and 0<=nx<cell and active[ny,nx] and not visited[ny,nx]:
                            visited[ny,nx]=True;queue.append((ny,nx))
                groups.append(group)
            largest=max(map(len,groups),default=1)
            for group in groups:
                if len(group)<largest*.008:
                    for cy,cx in group: alpha[cy,cx]=0
                    removed+=len(group)
            pixels=np.argwhere(alpha>24)
            assert len(pixels)>400,'Character lost during keying'
            ymin,xmin=pixels.min(axis=0);ymax,xmax=pixels.max(axis=0)
            margins.append(int(min(xmin,ymin,cell-1-xmax,cell-1-ymax)))
        rgba[:,:,:3][rgba[:,:,3]==0]=0
        Image.fromarray(rgba).save(destination/'idle-atlas.png',compress_level=9)
        report['processing']+=['boundary-only magenta cleanup','remove isolated tiny keying residue, preserve main silhouette']
        report['isolated_residue_pixels_removed']=removed
        report['minimum_frame_margin_px']=min(margins)
        report['status']='reviewed-native-frames'
        assert min(margins)>=10,'Review cropping: character too near edge'
        (destination/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(kind,state,cells,'native frames; minimum margin',min(margins))
    archive=root/f'assets/animation-sources/{kind}-motion-v10/source-silent.mp4'
    subprocess.run(['ffmpeg','-n','-hide_banner','-loglevel','error','-i',str(source),'-map','0:V:0','-c:v','copy','-an',str(archive)],check=True)
