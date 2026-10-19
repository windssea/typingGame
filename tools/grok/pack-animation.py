"""Normalize a real generated clip into a Godot atlas without interpolating frames."""
import argparse
import json
import math
import subprocess
from fractions import Fraction
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--video', required=True)
parser.add_argument('--out', required=True)
parser.add_argument('--start', type=float, default=0)
parser.add_argument('--seconds', type=float, default=2)
parser.add_argument('--cell', type=int, default=128)
parser.add_argument('--columns', type=int, default=8)
parser.add_argument('--crop', help='Static x:y:width:height source region, in pixels')
parser.add_argument('--name', default='idle')
parser.add_argument('--once', action='store_true')
args = parser.parse_args()
source = Path(args.video).resolve()
output = Path(args.out).resolve()
if output.exists() and any(output.iterdir()):
    raise SystemExit('Output exists: use a versioned directory, do not overwrite a reviewed animation.')
output.mkdir(parents=True,exist_ok=True)
probe = json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(source)],text=True))
stream = next(s for s in probe['streams'] if s['codec_type']=='video')
fps = Fraction(stream['avg_frame_rate'])
if not fps or stream['r_frame_rate'] != stream['avg_frame_rate']:
    raise SystemExit('Variable frame rate: inspect timestamps and choose a documented native timeline first.')
duration = float(probe['format']['duration'])
if args.start<0 or args.seconds<=0 or args.start+args.seconds>duration+.02:
    raise SystemExit('Requested interval exceeds clip.')
count = math.floor(args.seconds*float(fps)+1e-6)
rows = math.ceil(count/args.columns)
atlas = output/'idle-atlas.png'
filter_parts = [
    'format=rgba',
    'colorkey=0x00ff00:0.18:0.08',
    'despill=type=green:mix=0.5',
    f'scale={args.cell}:{args.cell}:force_original_aspect_ratio=decrease:flags=lanczos',
    f'pad={args.cell}:{args.cell}:(ow-iw)/2:(oh-ih)/2:color=black@0',
    f'tile={args.columns}x{rows}:nb_frames={count}:color=black@0',
]
if args.crop:
    x,y,width,height=map(int,args.crop.split(':'))
    if min(x,y)<0 or min(width,height)<=0 or x+width>stream['width'] or y+height>stream['height']:
        raise SystemExit('Invalid static crop region')
    filter_parts.insert(0,f'crop={width}:{height}:{x}:{y}')
filters = ','.join(filter_parts)
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-n','-ss',str(args.start),'-i',str(source),'-map',f'0:{stream["index"]}','-t',str(count/float(fps)),'-an','-vf',filters,'-frames:v','1',str(atlas)],check=True)
root = Path(__file__).resolve().parents[2]
relative = atlas.relative_to(root).as_posix()
parts = [f'[gd_resource type="SpriteFrames" load_steps={count+2} format=3]', '', f'[ext_resource type="Texture2D" path="res://{relative}" id="1"]','']
for i in range(count):
    x,y = (i%args.columns)*args.cell,(i//args.columns)*args.cell
    parts.extend([f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({x}, {y}, {args.cell}, {args.cell})','filter_clip = true',''])
frames = ',\n'.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}' % i for i in range(count))
parts.extend(['[resource]','animations = [{',f'"frames": [{frames}],','"loop": '+('false' if args.once else 'true')+',',f'"name": &"{args.name}",',f'"speed": {float(fps)}','}]',''])
(output/'idle.tres').write_text('\n'.join(parts),encoding='utf-8')
report = {'source':str(source),'native':{'width':stream['width'],'height':stream['height'],'fps':str(fps),'duration':duration,'frames':stream.get('nb_read_frames'),'audio_tracks':sum(s['codec_type']=='audio' for s in probe['streams'])},'atlas':{'file':relative,'cell':args.cell,'columns':args.columns,'rows':rows,'frames':count,'fps':str(fps),'interval':[args.start,args.start+count/float(fps)],'decoded_rgba_bytes':args.columns*rows*args.cell*args.cell*4},'processing':['native frame interval extraction','green chroma key','green despill','shared whole-canvas scale and padding','atlas packing'],'interpolation':False,'loop_review':'pending-native-scale-review','status':'candidate'}
report.update({'static_crop':args.crop,'animation':args.name,'loop':not args.once})
(output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
