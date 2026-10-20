"""Persist bounded evidence; raw Grok receipts and media stay in ignored build/."""
from pathlib import Path
import hashlib,json
from PIL import Image
root=Path(__file__).resolve().parents[1]
items=[('knight-v18','knight-v18','knight-v18'),('sub-v18','sub-v18','sub-v18'),('robot-v18','robot-v18','robot-v18'),('chef-v18c','chef-v18','chef-stir-v18'),('balloon-v18','balloon-v18','balloon-pop-v18')]
report=[]
for job,seed,clip in items:
    folder=root/'build/animations'/job
    data=json.loads((folder/'status.json').read_text(encoding='utf-8-sig'))
    atlas=root/'assets/animations'/clip
    proof=json.loads((atlas/'report.json').read_text(encoding='utf-8'))
    proof['generation']=data
    proof['source_sha256']=hashlib.sha256((folder/'grok-raw.mp4').read_bytes()).hexdigest()
    proof['seed_sha256']=hashlib.sha256((root/'assets/animation-sources'/seed/'seed.png').read_bytes()).hexdigest()
    proof['status']='integrated-reviewed-at-game-scale'
    proof['loop_review']='short native-frame clip; transitions may retain generated pose drift; reduced motion uses frame zero'
    (atlas/'report.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding='utf-8')
    (root/'assets/animation-sources'/seed/f'{job}-status.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    report.append({'job':job,'runtime':clip,'native':proof['native'],'frames':proof['atlas']['frames'],'source_sha256':proof['source_sha256']})
for job,reason in [('chef-v18','flying food clipped at source frame edge'),('chef-v18b','skin shifts to green after about two seconds')]:
    status=root/'build/animations'/job/'status.json'
    if status.exists():
        data=json.loads(status.read_text(encoding='utf-8-sig'))
        data.update({'qa_status':'rejected','qa_reason':reason})
        (root/'assets/animation-sources/chef-v18'/f'{job}-rejected.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
for folder in [root/'assets/generated/v18',*[root/'assets/animations'/clip for _,_,clip in items]]:
    for path in folder.glob('*.png.import'):
        text=path.read_text(encoding='utf-8')
        path.write_text(text.replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
(root/'docs/ANIMATION_V18.evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Archived',len(report),'real Grok clips; rejected two chef candidates; enabled mipmaps.')
