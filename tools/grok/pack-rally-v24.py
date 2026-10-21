"""Pack reviewed native Grok kart intervals with a common 384px canvas; no interpolation."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
for name,source,state,start,seconds,once in [
 ('rally-mint-idle-v24','rally-mint-v24','idle',.5,2,False),
 ('rally-mint-boost-v24','rally-mint-v24','boost',2.5,1,True),
 ('rally-coral-idle-v24','rally-coral-v24','idle',.5,2,False)]:
 command=[sys.executable,str(root/'tools/grok/pack-animation.py'),'--video',str(root/f'build/animations/{source}/grok-raw.mp4'),'--out',str(root/f'assets/animations/{name}'),'--start',str(start),'--seconds',str(seconds),'--cell','384','--inset','8','--key','ff00ff','--name',state]
 if once:command+=['--once']
 subprocess.run(command,check=True)
