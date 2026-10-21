"""Extract reviewed native poses, removing unwanted chroma-connected residue.

Raw videos remain untouched. No interpolation, per-frame recentering, or pose synthesis.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

root = Path(__file__).resolve().parents[2]
jobs = [
    ('chef-idle-v22', 'chef-cook-v22', 'idle', 0, 1, False),
    ('chef-stir-v22', 'chef-cook-v22', 'stir', 1, 2, True),
    ('chef-toss-v22', 'chef-cook-v22', 'toss', 3, 2, True),
    ('chef-serve-v22', 'chef-serve-v22', 'serve', 2, 2, True),
    ('chef-walk-v22', 'chef-walk-v22', 'walk', 2.25, 26/24, False),
]
parser = argparse.ArgumentParser()
parser.add_argument('--only', choices=[job[0] for job in jobs])
args = parser.parse_args()
for name, source, state, start, seconds, once in jobs:
    if args.only and args.only != name:
        continue
    out = root / 'assets/animations' / name
    command = [sys.executable, str(root / 'tools/grok/pack-animation.py'),
               '--video', str(root / 'build/animations' / source / 'grok-raw.mp4'),
               '--out', str(out), '--start', str(start), '--seconds', str(seconds),
               '--cell', '384', '--inset', '6', '--key', 'ff00ff', '--name', state]
    if once:
        command.append('--once')
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
    image = np.array(Image.open(out / 'idle-atlas.png').convert('RGBA'))
    report = json.loads((out / 'report.json').read_text(encoding='utf-8'))
    removed = 0
    margins = []
    for index in range(report['atlas']['frames']):
        x, y = index % 8 * 384, index // 8 * 384
        cell = image[y:y+384, x:x+384]
        rgb = cell[:, :, :3].astype(np.int16)
        # The generator added pink steam and detached stars against the brief.
        # This character has no magenta costume; remove that chroma contamination
        # and only disconnected exterior components, retaining the whole chef.
        magenta = (rgb[:, :, 0] > 170) & (rgb[:, :, 2] > 170) & (np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1] > 55)
        cell[:, :, 3][magenta] = 0
        opaque = cell[:, :, 3] > 24
        points = np.argwhere(opaque)
        anchor = points[np.argmin(np.sum((points-np.array([192,192]))**2, axis=1))]
        connected = Image.fromarray((opaque*255).astype('uint8')).copy()
        ImageDraw.floodfill(connected, (int(anchor[1]),int(anchor[0])), 128)
        body = np.array(connected) == 128
        # Keep antialiased silhouette edges, never resize/recenter individual poses.
        keep = np.array(Image.fromarray((body*255).astype('uint8')).filter(ImageFilter.MaxFilter(5))) > 0
        removed += int(np.count_nonzero((cell[:, :, 3] > 0) & ~keep))
        cell[:, :, 3][~keep] = 0
        cell[:, :, :3][cell[:, :, 3] == 0] = 0
        points = np.argwhere(cell[:, :, 3] > 32)
        ymin, xmin = points.min(axis=0); ymax, xmax = points.max(axis=0)
        margins.append(int(min(xmin, ymin, 383-xmax, 383-ymax)))
        if margins[-1] < 6:
            raise ValueError(f'Unsafe edge: {name}:{index}')
    Image.fromarray(image).save(out / 'idle-atlas.png', compress_level=9)
    report.update({'status': 'reviewed-native-source', 'minimum_frame_margin_px': min(margins),
                   'removed_disconnected_pixels': removed,
                   'limitations': ['Cook source adds magenta steam and detached star decorations despite the motion brief; runtime alpha excludes them. Engine supplies order-bound steam and fire.'],
                   'loop_review': 'idle native interval reviewed; action clips play once and recover to idle'})
    report['processing'] += ['magenta-only residue alpha removal', 'retain connected chef silhouette and two-pixel antialias border']
    (out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(name, report['atlas']['frames'], 'native frames; margin', min(margins), flush=True)
