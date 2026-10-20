"""Normalize generated masters and prepare fixed chroma canvases for real Grok clips."""
import json, hashlib, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('C:/Users/windssea/.codex/generated_images/01a15294-8334-75c2-ab9d-fb510040e509')
IDS = {'royal':'d897cf47-565d-43b0-a428-f22153d784c3', 'submarine':'738966ee-a45d-4e1c-951a-d0e3da355a71', 'restaurant':'69cbaf8b-da3b-495b-b75d-039c41ad01c0', 'actors':'c1a7ba9a-0b3b-4491-ad1c-50fd0f0aaddb', 'sprint':'175912ab-430c-4e62-9fe1-cd07a768b214', 'cafe':'90b6df70-00da-42dd-a668-177e55f7640d'}
OUT = ROOT/'assets/generated/v18'
OUT.mkdir(parents=True,exist_ok=True)
masters = ROOT/'docs/art-sources-v18'
masters.mkdir(exist_ok=True)
(masters/'.gdignore').touch()
report = {'tool':'built-in image_gen', 'style':'original American animated cartoon, sapphire/gold/teal', 'assets':[]}
for name, identifier in IDS.items():
    path = masters/f'{name}.png'
    if not path.exists(): path=SOURCE/f'exec-{identifier}.png'
    image = Image.open(path).convert('RGBA')
    if path.resolve()!=(masters/f'{name}.png').resolve(): shutil.copy2(path,masters/f'{name}.png')
    if name not in ['actors','cafe']: image.save(OUT/f'{name}-background.png')
    report['assets'].append({'name':name,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':image.size,'alpha':image.getchannel('A').getextrema()})

sheet = Image.open(masters/'actors.png').convert('RGBA')
names = ['knight','goblin','sub','chef','cannon','robot']
for index,name in enumerate(names):
    col,row = index%3,index//3
    crop = sheet.crop((col*512,row*512,(col+1)*512,480 if row==0 else 1024))
    bounds = crop.getchannel('A').getbbox()
    if bounds: crop=crop.crop(bounds)
    crop.thumbnail((384,384),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(448,448))
    canvas.alpha_composite(crop,((448-crop.width)//2,436-crop.height))
    canvas.save(OUT/f'{name}.png')
    if name in ['knight','sub','chef','robot']:
        seed=Image.new('RGBA',(720,720),(255,0,255,255))
        enlarged=canvas.resize((620,620),Image.Resampling.LANCZOS)
        seed.alpha_composite(enlarged,(50,50))
        folder=ROOT/f'assets/animation-sources/{name}-v18'
        folder.mkdir(parents=True,exist_ok=True)
        # Preserve the exact source used by the already submitted Grok request.
        if not (folder/'seed.png').exists(): seed.convert('RGB').save(folder/'seed.png')
        motion={'knight':'Run on the spot facing RIGHT, real alternating leg strides, knees bend, arms and sword move with the run, blue plume and cape trail. Feet stay near bottom center. First 4 seconds run, seconds 4-6 slash sword once with clear anticipation and recovery, then run.', 'sub':'Submarine stays centered facing RIGHT. Propeller visibly spins continuously, engine mechanism pulses, pilot adjusts controls, hull gently pitches only 2 degrees. At seconds 4-6 forward torpedo hatch opens, recoil then closes. Do NOT generate bubble trails outside hull; game engine adds these.', 'chef':'Chef stands near fixed floor anchor and visibly cooks: bend knees, lift frying pan, flip golden food high in a clear arc and catch it, swing free arm to balance, delighted smile; repeat twice. Full body retained with no hand deformation.', 'robot':'Robot runs IN PLACE facing right with visibly alternating feet, bent knees, swinging opposite arms and clear airborne passing pose. Real mechanical joint articulation, not whole-body sliding or bobbing. Keep identity, same scale and fixed foot anchor.'}[name]
        if not (folder/'motion.txt').exists(): (folder/'motion.txt').write_text('LOCKED CAMERA. One isolated original cartoon game sprite. EXACT flat solid MAGENTA #ff00ff background throughout, no floor, shadows, text, particles, camera motion or zoom. Full silhouette always inside safe 10% margin. '+motion+' Preserve original proportions, materials and upper-left lighting. 8 seconds at native 24fps if available; no audio.',encoding='utf-8')

cafe = Image.open(masters/'cafe.png').convert('RGBA')
for row,prefix in enumerate(['food','customer']):
    for col in range(3):
        crop=cafe.crop((col*512,0 if row==0 else 430,(col+1)*512,420 if row==0 else 1024))
        crop=crop.crop(crop.getchannel('A').getbbox())
        crop.thumbnail((320,320),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(352,352))
        canvas.alpha_composite(crop,((352-crop.width)//2,(352-crop.height)//2))
        canvas.save(OUT/f'{prefix}{col}.png')
cloud = Image.open(masters/'cloud.png').convert('RGBA')
cloud.thumbnail((768,256),Image.Resampling.LANCZOS)
cloud.save(OUT/'cloud.png')
cloud_source = masters/'cloud.png'
report['assets'].append({'name':'cloud','source_sha256':hashlib.sha256(cloud_source.read_bytes()).hexdigest(),'size':Image.open(cloud_source).size,'alpha':cloud.getchannel('A').getextrema()})
(ROOT/'docs/ART_ASSETS_V18.provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
