"""Lossy WebP transport copies of existing art; original 24 fps Grok frame grids stay intact."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'web'
SOURCES = {
    'loading-scene-v191.webp': 'assets/generated/academy-lobby-v10.png',
    'loading-cloud-v191.webp': 'assets/generated/v18/cloud.png',
    'loading-robot-v191.webp': 'assets/animations/robot-v18/idle-atlas.png',
    'loading-knight-v191.webp': 'assets/animations/knight-v18/idle-atlas.png',
    'loading-robot-pose-v191.webp': 'assets/animations/robot-v18/idle-atlas.png',
    'loading-knight-pose-v191.webp': 'assets/animations/knight-v18/idle-atlas.png',
}
records = []
for name, source in SOURCES.items():
    crop = ['-vf', 'crop=256:256:0:0'] if '-pose-' in name else []
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(ROOT / source), *crop,
                    '-frames:v', '1', '-c:v', 'libwebp', '-quality', '78', '-compression_level', '6',
                    str(DEST / name)], check=True)
    records.append({'file': name, 'source': source, 'bytes': (DEST/name).stat().st_size,
                    'source_sha256': hashlib.sha256((ROOT/source).read_bytes()).hexdigest(), 'first_frame_crop': bool(crop)})
(DEST / 'loading-assets.json').write_text(json.dumps({'format': 'static WebP frame atlases; 24 fps playback, no interpolation', 'assets': records}, indent=2)+'\n', encoding='utf-8')
print(json.dumps(records, indent=2))
