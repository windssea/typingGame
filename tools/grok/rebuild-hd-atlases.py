"""Decode the original Grok videos again, preserving native frames and pivots.

This is not an enlargement of the old atlases. Every frame is sampled from
the original 720/960px source. Versioned low-resolution assets remain intact.
"""
from pathlib import Path
import json, subprocess, sys
import numpy as np
from PIL import Image, ImageFilter

root=Path(__file__).resolve().parents[2]
names=['mole-idle-v10','mole-hit-v10','ufo-idle-v10','ufo-hit-v10','rally-drive-v10','rally-boost-v10','goblin-walk-v10','goblin-hit-v10']
names += [f'{kind}-{state}-'+('v10b' if kind=='boss' else 'v10') for kind in ['wolf','boss','guard','shaman','bomber'] for state in ['walk','hit']]
names += ['boxing-blue-idle-v002','boxing-blue-punch-v003','boxing-coral-idle-v001','boxing-coral-punch-v001','royal-guard-idle-v002']
summary=[]
for name in names:
    old=root/f'assets/animations/{name}'
    before=json.loads((old/'report.json').read_text())
    prefix=name.rsplit('-v',1)[0]
    out=root/f'assets/animations/{prefix}-hd-v11'
    if out.exists():
        raise SystemExit(f'Versioned target exists: {out}')
    source=Path(before['source'])
    assert source.is_file(),f'Missing original video: {source}'
    cell=384 if prefix.startswith(('boxing','boss')) else 256
    a,b=before['atlas']['interval']
    state=before.get('animation') or 'idle'
    key=before.get('chroma_key') or '00ff00'
    args=[sys.executable,str(root/'tools/grok/pack-animation.py'),'--video',str(source),'--out',str(out),'--start',str(a),'--seconds',str(b-a),'--cell',str(cell),'--key',key,'--name',state]
    crop=before.get('static_crop')
    if crop: args += ['--crop',crop]
    inset=round(before.get('cell_safety_inset_px',0)*cell/before['atlas']['cell'])
    if inset: args += ['--inset',str(inset)]
    if before.get('loop',True) is False: args.append('--once')
    subprocess.run(args,check=True,stdout=subprocess.DEVNULL)
    im=Image.open(out/'idle-atlas.png').convert('RGBA')
    rgba=np.array(im)
    if key=='ff00ff':
        rgb=rgba[:,:,:3].astype(float)
        near=np.array(im.getchannel('A').filter(ImageFilter.MinFilter(5)))<16
        spill=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        mask=near & (rgba[:,:,3]>0) & (rgb[:,:,0]>180) & (rgb[:,:,2]>180) & (spill>65)
        rgba[:,:,3][mask]=np.round(rgba[:,:,3][mask]*(1-np.clip((spill[mask]-65)/90,0,1))).astype('uint8')
    # Preserve the same accepted silhouette mask from the old version, but keep
    # all newly decoded RGB detail. This removes rejected disconnected residue.
    approved=Image.open(old/'idle-atlas.png').getchannel('A').resize(im.size,Image.Resampling.LANCZOS).filter(ImageFilter.MaxFilter(5))
    rgba[:,:,3][np.array(approved)<8]=0
    rgba[:,:,:3][rgba[:,:,3]==0]=0
    Image.fromarray(rgba).save(out/'idle-atlas.png',compress_level=9)
    report=json.loads((out/'report.json').read_text())
    assert report['atlas']['frames']==before['atlas']['frames']
    report.update({'source_runtime_version':name,'status':'native-source-hd-candidate','interpolation':False,'color_detail_source':'original decoded video, not low-resolution atlas enlargement','alpha_reference':f'assets/animations/{name}/idle-atlas.png','loop_review':before.get('loop_review','inherited native interval; inspect runtime')})
    margins=[]
    for i in range(report['atlas']['frames']):
        x,y=(i%8)*cell,(i//8)*cell
        pixels=np.argwhere(rgba[y:y+cell,x:x+cell,3]>32)
        assert len(pixels)>400, f'Empty frame: {name}:{i}'
        ymin,xmin=pixels.min(axis=0);ymax,xmax=pixels.max(axis=0)
        margins.append(int(min(xmin,ymin,cell-1-xmax,cell-1-ymax)))
    report['minimum_frame_margin_px']=min(margins)
    (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary.append({'old':name,'new':out.name,'cell':cell,'frames':report['atlas']['frames'],'decoded_bytes':report['atlas']['decoded_rgba_bytes'],'margin':min(margins)})
    print(out.name,cell,'px',report['atlas']['frames'],'native frames; margin',min(margins),flush=True)
(root/'build/v11-hd-atlases.json').write_text(json.dumps(summary,indent=2)+'\n')
