"""Resolve proposal tokens for the standalone design prototype, never mutate source."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = json.loads((ROOT / "docs/five_world_design_tokens_v0.2.json").read_text(encoding="utf-8-sig"))
resolved = {
    "metadata": {"name": "Keybound design v2", "version": "2.0.0", "status": "review-prototype", "source": "../five_world_design_tokens_v0.2.json", "unit": "logical dp", "date": "2026-10-19"},
    "core": source["core"],
    "themes": source["themes"],
    "world_order": source["world_order"],
    "project_overrides": {
        "type_dp": {"hero": 40, "page": 32, "title": 24, "body": 18, "hint": 16, "caption": 14, "target": 36},
        "surfaces": {"shell": "#192B42", "frame": "#273950", "reading": "#F2E6CF", "reading_bright": "#FFF8E8", "ink": "#243044", "muted_ink": "#536078", "ink_on_dark": "#FFFFFF"},
        "action": {"face": "#F0C46B", "edge": "#846029", "ink": "#243044", "focus_inner": "#192B42", "focus_outer": "#FFE2A0"},
        "layout": {"reference": [1280, 800], "safe_margin": 32, "topbar": 80, "footer": 56, "breakpoint_compact": 1100, "breakpoint_narrow": 780},
        "accessibility": {"text_contrast_min": 4.5, "focus_contrast_min": 3, "target_min": 48, "text_scale": [1, 1.25, 1.5], "reduced_motion": True}
    },
    "mode_worlds": {"castle": "royal_fantasy", "fighter": "royal_fantasy", "aliens": "sci_fi", "rain": "sci_fi", "racing": "modern", "sprint": "modern", "dojo": "ancient", "moles": "ancient", "balloons": "fairytale", "bubbles": "fairytale"},
    "status_policy": {"concept": "方向参考，非运行精灵", "prototype": "可操作交互，演示状态", "production_ready": "需通过技术检查与真实引擎验收"}
}

def luminance(value):
    rgb = [int(value[i:i+2], 16)/255 for i in (1, 3, 5)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    return sum(a*b for a,b in zip(rgb, [.2126,.7152,.0722]))

def contrast(a,b):
    x,y = sorted([luminance(a),luminance(b)])
    return round((y+.05)/(x+.05),2)

pairs = [("body", "#243044", "#F2E6CF"), ("secondary", "#536078", "#F2E6CF"), ("action", "#243044", "#F0C46B"), ("on_dark", "#FFFFFF", "#273950"), ("focus", "#FFE2A0", "#192B42")]
report = {label: {"foreground":a,"background":b,"ratio":contrast(a,b),"pass":contrast(a,b)>=4.5} for label,a,b in pairs}
assert all(item["pass"] for item in report.values())
out = ROOT / "docs/design-v2"
(out / "tokens.resolved.json").write_text(json.dumps(resolved,ensure_ascii=False,indent=2),encoding="utf-8")
(out / "contrast-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
# Direct-file preview must work without fetch/CORS or external dependencies.
(out / "tokens.js").write_text("window.KEYBOUND_TOKENS = "+json.dumps(resolved,ensure_ascii=False)+";\n",encoding="utf-8")
curriculum = json.loads((ROOT / "data/curriculum.json").read_text(encoding="utf-8-sig"))
with (out / "tokens.js").open("a",encoding="utf-8") as stream:
    stream.write("window.KEYBOUND_LESSONS = "+json.dumps(curriculum["lessons"],ensure_ascii=False)+";\n")
print(json.dumps(report,ensure_ascii=False))
