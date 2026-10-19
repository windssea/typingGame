"""Build the redistributable UI font from the SIL OFL licensed Noto Sans SC."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1]
chars = ''.join(chr(i) for i in range(32, 127)) + '✓→·—…，。！？：；（）【】'
for extension in ('*.gd', '*.json'):
    for path in root.rglob(extension):
        if '.godot' not in path.parts and 'addons' not in path.parts:
            chars += path.read_text(encoding='utf-8')
font = TTFont(root / 'assets/NotoSansSC-source.ttf')
font = instantiateVariableFont(font, {'wght': 400}, inplace=True)
options = subset.Options()
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=chars)
subsetter.subset(font)
font.save(root / 'assets/ui-font.ttf')
print('Saved ui-font.ttf:', (root / 'assets/ui-font.ttf').stat().st_size, 'bytes')
