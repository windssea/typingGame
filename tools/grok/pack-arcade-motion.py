"""Pack reviewed native intervals from the four v0.8 Grok source clips."""
import hashlib,json,subprocess,sys
from pathlib import Path
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parents[2]
specs=[
 ('mole','mole-idle-v08','idle',0,2,False),
 ('mole','mole-hit-v08','hit',2.25,1,True),
 ('ufo','ufo-idle-v08','idle',0,2,False),
 ('ufo','ufo-hit-v08','hit',3.5,.75,True),
 ('rally-car','rally-drive-v08','idle',.5,2,False),
 ('rally-car','rally-boost-v08','boost',3,1.25,True),
 ('goblin','goblin-walk-v08','idle',0,2,False),
 ('goblin','goblin-hit-v08','hit',5.25,.75,True),
]
for source_id,asset,state,start,seconds,once in specs:
    source=root/'build/animations'/(source_id+'-motion-v08')/'v001/grok-raw.mp4'
    folder=root/'assets/animations'/asset
    command=[sys.executable,str(root/'tools/grok/pack-animation.py'),'--video',str(source),'--out',str(folder),'--start',str(start),'--seconds',str(seconds),'--cell','192','--key','ff00ff','--crop','96:96:528:528','--name',state]
    if once:command.append('--once')
    subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
    report=json.loads((folder/'report.json').read_text())
    atlas=Image.open(folder/'idle-atlas.png').convert('RGBA')
    count=report['atlas']['frames']; columns=report['atlas']['columns']
    bounds=[]; changes=[]; previous=None; edge_frames=[]
    for i in range(count):
        x=(i%columns)*192; y=(i//columns)*192
        frame=atlas.crop((x,y,x+192,y+192))
        bound=frame.getchannel('A').getbbox();bounds.append(bound)
        if not bound or min(bound[0],bound[1],192-bound[2],192-bound[3])<2:edge_frames.append(i)
        if previous: changes.append(sum(a!=b for a,b in zip(frame.tobytes(),previous.tobytes())))
        previous=frame
    if edge_frames:raise SystemExit(f'Clipped sprite {asset}: {edge_frames}')
    qa={'frames':count,'native_fps':report['atlas']['fps'],'bounds':bounds,'edge_frames':edge_frames,'changed_bytes_between_frames':changes,'interpolation':False,'status':'normalized-awaiting-in-engine-review'}
    (folder/'qa.json').write_text(json.dumps(qa,indent=2)+'\n')
    print(asset,count,'frames; minimum margin',min(min(b[0],b[1],192-b[2],192-b[3]) for b in bounds))
for source_id in ['mole','ufo','rally-car','goblin']:
    raw=root/'build/animations'/(source_id+'-motion-v08')/'v001/grok-raw.mp4'
    folder=root/'assets/animation-sources'/(source_id+'-motion-v08')
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(raw)]))
    video=next(s for s in probe['streams'] if s['codec_type']=='video' and s.get('avg_frame_rate')!='0/0')
    status={'tool':'local Grok Build / reference_to_video','status':'generated-and-normalized','provider_request_id':None,'provider_model':None,'identity':'existing approved Image Gen atlas region','output_path':str(raw),'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'actual':{'width':video['width'],'height':video['height'],'fps':video['avg_frame_rate'],'frames':video.get('nb_frames'),'duration':float(probe['format']['duration'])},'limitations':['The generation returned no separate provider request id/model in the local receipt. CLI session/request IDs are not substituted.','Native source contains audio/attached preview; runtime uses only decoded video frames.','Short idle loops may show a seam; selected intervals and runtime reactions are reviewed separately.']}
    (folder/'grok-status-v001.json').write_text(json.dumps(status,indent=2)+'\n')
    preview=folder/'motion-preview-v001.mp4'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-n','-i',str(raw),'-map','0:v:0','-c:v','copy','-an',str(preview)],check=True)
