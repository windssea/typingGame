"""Original deterministic SFX and two phase-aligned musical stems for the game."""
from pathlib import Path
import math
import random
import struct
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/v10"
RAW = ROOT / "build/audio-v10"
RATE = 22050

def write(path, samples, gain=.7):
    peak = max(abs(x) for x in samples) or 1
    factor = min(gain / peak, 1)
    with wave.open(str(path), "wb") as f:
        f.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes(b"".join(struct.pack("<h", round(max(-1, min(1, x*factor))*32767)) for x in samples))

def tone(t, freq, decay):
    return math.sin(2*math.pi*freq*t) * math.exp(-t*decay)

def sfx(name, seconds):
    rng = random.Random(520+sum(map(ord,name)))
    values, low = [], 0
    for i in range(round(seconds*RATE)):
        t = i/RATE
        p = t/seconds
        noise = rng.uniform(-1,1)
        low = low*.8+noise*.2
        attack = min(1,t*700)
        tail = min(1,(1-p)*60)
        if name == "key": value = .2*tone(t,1050,95)+noise*.14*math.exp(-t*160)
        elif name == "error": value = .24*tone(t,245,24)+.13*tone(t,280,28)
        elif name == "focus": value = .2*tone(t,784,45)+.06*tone(t,1568,55)
        elif name == "confirm": value = .22*tone(t,660,24)+.18*tone(max(0,t-.04),990,30)*(t>.04)
        elif name == "pop": value = .75*tone(t,180+800*math.exp(-t*50),30)+noise*.12*math.exp(-t*40)
        elif name == "mallet": value = .65*tone(t,155,32)+.25*tone(t,430,40)+noise*.25*math.exp(-t*65)
        elif name == "laser": value = .4*math.sin(2*math.pi*(1500*t-1800*t*t))*math.exp(-t*22)+.15*low*math.exp(-t*15)
        elif name == "engine": value = .32*(math.sin(2*math.pi*(85*t+110*t*t))+.4*math.sin(2*math.pi*(170*t+220*t*t)))*math.sin(math.pi*p)+.2*low*(1-p)
        elif name == "punch": value = .65*tone(t,75,22)+low*.65*math.exp(-t*28)+noise*.16*math.exp(-t*85)
        elif name == "block": value = .3*tone(t,720,24)+.24*tone(t,1140,30)+noise*.1*math.exp(-t*55)
        elif name == "combo": value = sum(.16*tone(t-j*.055,f,16)*(t>=j*.055) for j,f in enumerate([660,880,1320]))
        elif name == "skill": value = sum(.12*tone(t-j*.045,f,12)*(t>=j*.045) for j,f in enumerate([440,660,880,1100,1320]))
        elif name == "win": value = sum(.18*tone(t-j*.12,f,7)*(t>=j*.12) for j,f in enumerate([523.25,659.25,783.99,1046.5]))
        else: value = sum(.13*tone(t-j*.15,f,8)*(t>=j*.15) for j,f in enumerate([440,392,329.63]))
        values.append(value*attack*tail)
    write(OUT/(name+".wav"),values,.65)

def add_note(samples, start, frequency, length, volume, timbre="bell"):
    for i in range(round(length*RATE)):
        t=i/RATE
        if timbre=="bell": value=(math.sin(2*math.pi*frequency*t)+.22*math.sin(2*math.pi*frequency*2*t))*math.exp(-t*6)
        else: value=math.sin(2*math.pi*frequency*t)*math.exp(-t*10)
        samples[(round(start*RATE)+i)%len(samples)] += value*volume*min(1,t*350)

def music():
    beat=60/105
    frames=round(32*beat*RATE)
    base=[0.0]*frames
    rhythm=[0.0]*frames
    # An original eight-bar pentatonic phrase, not an arrangement of an existing song.
    melody=[0,2,4,None,7,4,2,None,5,7,9,7,4,None,2,None,
            0,4,7,None,9,7,4,2,5,4,2,None,0,None,2,None]
    scale={0:523.25,2:587.33,4:659.25,5:698.46,7:783.99,9:880}
    roots=[130.81,130.81,174.61,174.61,164.81,164.81,146.83,130.81]
    rng=random.Random(701)
    for index, note in enumerate(melody):
        if note is not None: add_note(base,index*beat,scale[note],.8,.12)
    for bar,root in enumerate(roots):
        for quarter in [0,2]: add_note(base,(bar*4+quarter)*beat,root,.5,.11,"bass")
        for half in range(8):
            start=round((bar*4+half*.5)*beat*RATE)
            for j in range(round(.07*RATE)):
                t=j/RATE
                hit=rng.uniform(-1,1)*math.exp(-t*85)*.035
                if half%4==0: hit+=math.sin(2*math.pi*(80*t-190*t*t))*math.exp(-t*35)*.18
                rhythm[(start+j)%frames]+=hit*min(1,t*1000)
    for name, samples in [("explore",base),("rhythm",rhythm)]:
        path=RAW/(name+".wav")
        write(path,samples,.55)
        subprocess.run(["ffmpeg","-y","-hide_banner","-loglevel","error","-i",str(path),"-c:a","libvorbis","-q:a","4",str(OUT/(name+".ogg"))],check=True)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    RAW.mkdir(parents=True,exist_ok=True)
    for name, duration in {"key":.055,"error":.14,"focus":.07,"confirm":.18,"pop":.2,"mallet":.18,"laser":.21,"engine":.42,"punch":.24,"block":.23,"combo":.32,"skill":.48,"win":1.1,"retry":.8}.items(): sfx(name,duration)
    music()
    print("14 original SFX and two aligned 18.286-second music stems generated")

if __name__ == "__main__": main()
