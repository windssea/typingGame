"""Versioned technical seed extraction from the approved castle atlas."""
from pathlib import Path
import json
import argparse
from PIL import Image

root=Path(__file__).resolve().parents[2]
regions=json.loads((root/'assets/generated/regions.json').read_text())['castle']
atlas=Image.open(root/'assets/generated/castle-sprites.png').convert('RGBA')
common='''Original bright American cartoon 2D game sprite animation. Locked orthographic three-quarter camera, no cuts, pans or zoom. Keep exact reference identity, colors, materials, equipment and facing. Flat pure MAGENTA #ff00ff background. NO shadows, scenery, text, UI, extra objects, particles or duplicates. Root stays centered and fixed. Entire character and equipment remain inside central 65 percent of frame. Internal articulated movement, not whole-image bobbing or scaling. Native 24fps, request 8 seconds; no interpolation. Return to original reference pose at end.\n'''
actions={
 'wolf':'''0-4 seconds: walk in place, distinctly alternating all four paws, jointed knees, shoulder and hip weight shift, tail swings, ears flick and eyes blink. Keep body planted at original center. 4-5.3: playful forward bite feint, neck stretches and jaws open a little then recover, no teeth close-up or violence. 5.3-6.3: surprised magic-hit recoil, head pulls back, front paws brace and ears lower. 6.3-8: resume walking. Preserve original side/three-quarter view; never face the camera.''',
 'boss':'''0-4 seconds: weighty walk in place with alternating planted boots, shoulders counter-rotate, free arm swings and weapon hand flexes; mouth breathes and eyebrows move. Root fixed. 4-5.3: raise the existing hammer/weapon by bending the elbow, torso anticipates then do one controlled downward practice swing and settle. All equipment must remain in frame. 5.3-6.3: comic magic-hit recoil, shoulders flinch and knees bend, no injury, gore, debris or new magic. 6.3-8: resume idle walk. Keep original costume and headgear, no new crown, armor or accessories.''',
 'guard':'''0-4 seconds: heavy shield warrior WALK IN PLACE, clear alternating boot plants and bending knees, shoulders counter-swing, shield hand grips and shield shifts independently. Blink and breathe. Root stays fixed. 4-5.3: lift existing shield into a protective guard and lower it, elbows articulate. 5.3-6.3: a comic magic-hit block reaction, knees brace, shield tilts backward, shoulders recoil and return. No sparks or damage. 6.3-8: return to original walking pose. Same shield, helmet, weapon, colors and three-quarter view.''',
 'shaman':'''0-4 seconds: robe-wearing shaman WALK IN PLACE, visible alternating foot steps beneath robe, hand grips existing staff, elbow and wrist articulate, shoulders breathe, head blinks and ears bounce. Root remains fixed. 4-5.3: existing staff hand raises and lowers in a short casting gesture, NO generated magic or particles. 5.3-6.3: surprised comic magic-hit flinch, arms spread slightly, shoulders pull back, then recover. 6.3-8: resume walking. Preserve exact staff and all original clothing.''',
 'bomber':'''0-4 seconds: comic bomber WALK IN PLACE with alternating knees and boot plants, torso counter-rotates, both hands securely carry the existing round bomb, eyes blink and eyebrows act. Root fixed. 4-5.3: crouch and carefully lift the same bomb a little, then return; do NOT throw, duplicate or explode it. 5.3-6.3: surprised magic-hit flinch, shoulders recoil and knees bend, bomb stays held safely. 6.3-8: return to walking pose. Preserve exact original clothing and bomb shape; no extra fuse particles, sparks, smoke, damage or new objects.'''
}
parser=argparse.ArgumentParser()
parser.add_argument('--kind',choices=['all']+list(actions),default='all')
args=parser.parse_args()
for name,action in actions.items():
    if args.kind!='all' and name!=args.kind: continue
    folder=root/f'assets/animation-sources/{name}-motion-v10'
    folder.mkdir(parents=True,exist_ok=True)
    if (folder/'seed-v001.png').exists(): raise SystemExit('Versioned seed exists; inspect instead of overwriting')
    x,y,w,h=regions[name]
    sprite=atlas.crop((x,y,x+w,y+h))
    sprite.thumbnail((460,460),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(768,768),(255,0,255,255))
    canvas.alpha_composite(sprite,((768-sprite.width)//2,(768-sprite.height)//2))
    canvas.convert('RGB').save(folder/'seed-v001.png')
    (folder/'motion-v001.txt').write_text(common+action+'\n',encoding='utf-8')
    (folder/'seed-provenance.json').write_text(json.dumps({'source':'assets/generated/castle-sprites.png','region':regions[name],'operation':'technical alpha region extraction and fixed magenta reference canvas','source_tool':'built-in Image Gen original atlas'},indent=2)+'\n')
    print(folder.relative_to(root))
