"""Normalize existing, reviewed atlas regions into pinned chroma video references."""
import json
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[2]
regions=json.loads((root/'assets/generated/regions.json').read_text())
common='''Production 2D sprite animation for a bright premium American cartoon children's typing game. LOCKED orthographic camera, no zoom, pan, cuts, parallax, text, UI, new objects or duplicates. Preserve the exact supplied character, materials, colors and view. Entire subject stays inside the central 70% of the canvas throughout. Flat pure MAGENTA #ff00ff background, no background lighting changes or cast shadow. Body articulates internally, NOT a still image bobbing or scaling. Keep the root centered and stationary; no traveling across the canvas. Start and finish with the same recognizable reference pose. Request 8 seconds. Native frames only.\n'''
jobs={
 'mole':('arcade','mole','''0-2 seconds: curious idle, visibly blink, whiskers twitch, paws alternately tap the dirt, chest breathes. 2-3.2: a playful surprised reaction: eyes widen, ears fold, head ducks slightly between the shoulders, paws cover head briefly. No hammer or violence. 3.2-4.2: head rises and shakes left-right once; return to smiling idle. 4.2-6: relaxed blink and paw-tap idle. 6-7: head and body retract behind the dirt mound leaving the same mound fixed. 7-8: pop up again, paws land and smile. Dirt mound location fixed; no extra holes.'''),
 'ufo':('arcade','ufo','''0-2 seconds: friendly green alien pilot blinks, antennae flex independently, shoulders breathe and hands actively steer the wheel; saucer lamps softly pulse. 2-3: pilot leans forward with determined eyebrows and pulls controls. 3-4.2: surprised comic hit reaction, pilot ducks and antennae spring back, saucer rim flexes very slightly then settles. Do not destroy ship, add projectiles, particles, lightning, cracks or smoke. 4.2-8: recover original facing, visible blinking and alternating hand movements at controls. Hull stays centered, whole craft view and dome unchanged. Keep the alien skin green; background is magenta.'''),
 'rally-car':('arcade','car_mint','''A top-down mint racing car pointing RIGHT. 0-3 seconds: continuous rolling animation in place. Four black tyres rotate with subtle moving tread highlights, front wheels make small independent steering corrections, suspension compresses and rebounds, seat/helmet shifts subtly. Do not rotate the entire car. 3-4.2: acceleration: rear suspension dips, front axle lightens, tyres spin faster then settle. 4.2-8: return to the stable drive cycle, suspension and independent wheels keep moving. Preserve overhead camera, body shape, rightward nose, paint and white stripe. No road, dust, smoke, flames, glow trail or ground shadow; those are supplied by the game engine.'''),
 'goblin':('castle','goblin','''0-4 seconds: lively WALK IN PLACE with alternating left/right foot plants, bent knee lifts, hip twist, counter-swinging free arm and club arm; ears bounce, face blinks. The root must remain planted at the same central location; never travel toward the camera. Keep same three-quarter facing and club. 4-5.2: short playful club swing with visible elbow bend, torso anticipation and recovery; club stays safely within canvas. 5.2-6.2: recoil from a magic hit, arms lift, ears flick and shoulders flinch, no gore. 6.2-8: return to the walk cycle. Do not spawn weapons, symbols, dust, trails, magic or duplicate limbs. Skin stays GREEN on magenta background.''')}
for asset,(family,region,action) in jobs.items():
    folder=root/'assets/animation-sources'/f'{asset}-motion-v08'
    folder.mkdir(parents=True,exist_ok=True)
    if (folder/'seed-v001.png').exists():
        raise SystemExit(f'Existing reviewed reference: {folder}; use a new version instead of overwriting')
    source=root/f'assets/generated/{family}-sprites.png'
    x,y,w,h=regions[family][region]
    cut=Image.open(source).convert('RGBA').crop((x,y,x+w,y+h))
    assert cut.getchannel('A').getextrema()[0]==0,'Source must have genuine alpha'
    cut.thumbnail((510,510),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(768,768),(255,0,255,255))
    canvas.alpha_composite(cut,((768-cut.width)//2,(768-cut.height)//2))
    canvas.convert('RGB').save(folder/'seed-v001.png')
    (folder/'motion-v001.txt').write_text(common+action+'\n',encoding='utf-8')
    (folder/'seed-provenance.json').write_text(json.dumps({'source':source.relative_to(root).as_posix(),'source_region':regions[family][region],'source_tool':'built-in Image Gen (existing approved atlas)','processing':['extract declared RGBA atlas region','uniform fit within 510x510','center on 768x768 flat magenta for Grok reference'],'seed_is_animation':False,'prompt':'motion-v001.txt'},indent=2)+'\n',encoding='utf-8')
    print(folder.relative_to(root))
