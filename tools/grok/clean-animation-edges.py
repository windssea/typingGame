"""Versioned chroma-edge cleanup of existing native-frame production atlases.

Only near-transparent boundary pixels with high red AND blue contamination are
attenuated. Opaque purple hulls and green skin are not globally desaturated.
No temporal processing, interpolation, relighting or animation synthesis.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageFilter

root=Path(__file__).resolve().parents[2]
clips=['mole-idle','mole-hit','ufo-idle','ufo-hit','rally-drive','rally-boost','goblin-walk','goblin-hit']
for name in clips:
    source=root/f'assets/animations/{name}-v08'
    target=root/f'assets/animations/{name}-v10'
    if target.exists(): raise SystemExit(f'Versioned output exists: {target}')
    target.mkdir()
    image=Image.open(source/'idle-atlas.png').convert('RGBA')
    rgba=np.array(image)
    rgb=rgba[:,:,:3].astype(float)
    alpha=rgba[:,:,3].copy()
    near=np.array(image.getchannel('A').filter(ImageFilter.MinFilter(5)))<16
    spill=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
    mask=near & (alpha>0) & (rgb[:,:,0]>180) & (rgb[:,:,2]>180) & (spill>65)
    attenuation=np.clip((spill-65)/90,0,1)
    rgba[:,:,3][mask]=np.round(alpha[mask]*(1-attenuation[mask])).astype('uint8')
    rgba[:,:,:3][rgba[:,:,3]==0]=0
    Image.fromarray(rgba).save(target/'idle-atlas.png',compress_level=9)
    resource=(source/'idle.tres').read_text(encoding='utf-8').replace(f'{name}-v08/',f'{name}-v10/')
    (target/'idle.tres').write_text(resource,encoding='utf-8')
    report=json.loads((source/'report.json').read_text(encoding='utf-8'))
    report['atlas']['file']=(target/'idle-atlas.png').relative_to(root).as_posix()
    report['source_atlas']=(source/'idle-atlas.png').relative_to(root).as_posix()
    report['processing'].append('boundary-only magenta contamination attenuation, no interior color remap')
    report['boundary_pixels_affected']=int(mask.sum())
    report['interpolation']=False
    (target/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(name, int(mask.sum()), 'boundary pixels cleaned across the complete atlas')
