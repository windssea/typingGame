"""Normalize generated cutouts without painting or replacing their native alpha."""
import argparse, json, shutil, hashlib
from pathlib import Path
from io import BytesIO
from PIL import Image
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--generation',type=Path,help='Optional JSON from a fresh generation; defaults to committed source manifest')
parser.add_argument('--check',action='store_true',help='Verify source-to-runtime reproduction without writing files')
args=parser.parse_args()
manifest_path=root/'docs/ART_ASSETS_V17.provenance.json'
records=json.loads(args.generation.read_text(encoding='utf-8-sig')) if args.generation else json.loads(manifest_path.read_text(encoding='utf-8'))['assets']
runtime=root/'assets/generated/v17';runtime.mkdir(parents=True,exist_ok=True)
sources=root/'docs/art-sources-v17';sources.mkdir(parents=True,exist_ok=True)
(sources/'.gdignore').write_text('',encoding='utf-8')
manifest={'version':'1.7','provider':'built-in image_gen','assets':[]}
for entry in records:
    name=entry.get('name',entry.get('id'));original=Path(entry['source']);original=original if original.is_absolute() else root/original
    source=sources/(name+'-source.png')
    if original.resolve()!=source.resolve(): shutil.copy2(original,source)
    im=Image.open(source).convert('RGBA')
    if name=='castle-field':
        output=im.convert('RGB');output.thumbnail((1536,1024),Image.Resampling.LANCZOS)
        anchor=None
    else:
        alpha_range=im.getchannel('A').getextrema(); assert alpha_range[0]==0 and alpha_range[1]>=250,name+' must have native transparency'
        bounds=im.getchannel('A').point(lambda a:255 if a>2 else 0).getbbox()
        crop=im.crop(bounds)
        size=(640,512) if name=='castle-keep' else (512,256) if name=='tower-pad' else (512,640)
        padding=16
        crop.thumbnail((size[0]-padding*2,size[1]-padding*2),Image.Resampling.LANCZOS)
        output=Image.new('RGBA',size)
        bottom=size[1]-padding
        output.alpha_composite(crop,((size[0]-crop.width)//2,bottom-crop.height))
        anchor=[.5,bottom/size[1]]
    destination=runtime/(name+'.png')
    encoded=BytesIO();output.save(encoded,format='PNG',optimize=True)
    if args.check:
        assert encoded.getvalue()==destination.read_bytes(),name+' normalization drifted'
    else: destination.write_bytes(encoded.getvalue())
    manifest['assets'].append({'id':name,'runtime':destination.relative_to(root).as_posix(),'source':source.relative_to(root).as_posix(),'source_size':list(im.size),'runtime_size':list(output.size),'anchor':anchor,'alpha':'native preserved' if anchor else 'opaque','camera':'orthographic 30 degree downward','key_light':'upper left','mipmaps':True,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':entry['prompt'],'status':entry.get('status','awaiting in-engine review')})
if not args.check: (root/'docs/ART_ASSETS_V17.provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared',len(manifest['assets']),'assets')
