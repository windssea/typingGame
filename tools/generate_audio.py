"""Small original procedural spell cues; no third-party sound assets."""
import math, random, struct, wave
from pathlib import Path

destination = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
destination.mkdir(exist_ok=True)
sample_rate = 22050
for name, duration in [('fire', .28), ('storm', .35), ('ice', .36), ('build', .5), ('warning', .65), ('damage', .4)]:
    random.seed(23)
    samples = []
    low_noise = 0.0
    for i in range(int(duration * sample_rate)):
        t = i / sample_rate
        phase = t / duration
        envelope = min(1, t * 120) * (1-phase) ** 2
        noise = random.uniform(-1, 1)
        low_noise = .86 * low_noise + .14 * noise
        if name == 'fire':
            value = .5 * math.sin(2*math.pi*(420*t-430*t*t)) + .6*low_noise
        elif name == 'storm':
            value = .65*noise*(.3+.7*max(0,math.sin(t*99))) + .3*math.sin(t*650)
        elif name == 'ice':
            value = sum(math.sin(2*math.pi*f*t) for f in [880,1320,1760])/3
        elif name == 'build':
            value = sum(math.sin(2*math.pi*f*t) for f in [523.25,659.25,783.99])/3
        elif name == 'warning':
            value = math.sin(2*math.pi*(196 if int(t*8)%2==0 else 246.94)*t)*.65
        else:
            value = .7*math.sin(2*math.pi*(110*t-70*t*t)) + .8*low_noise
        samples.append(struct.pack('<h', int(max(-1, min(1, value*envelope*.55))*32767)))
    with wave.open(str(destination / (name+'.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(b''.join(samples))
print('Generated six original spell cues.')
