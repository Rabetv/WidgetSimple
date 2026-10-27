"""App Store screenshots from real app screens, in the listing's own style.

Same look as AppStore/screenshots/src: a dark warm stage, a white headline with one
amber word, an amber ribbon, amber callout pills and a phone. The phone holds a real
screen (raw/*.jpg, 920 x 2000) at its native size.

Writes src/*.html (1320 x 2868, the 6.9" size); render.sh renders them and also writes
1206 x 2622 copies for the "iPhone with Dynamic Island" slot.
"""
from pathlib import Path

HERE = Path(__file__).parent

# name, headline (one <em> word in amber), line, pills [(text, left, top)], badges,
# ribbon path
SHOTS = [
    ("1-designer", "Build <em>your own</em><br>widget", "Clocks, dates, greetings and up to 12 apps.",
     [("Drag &#183; resize &#183; save", 760, 1180), ("Up to 12 apps", 40, 2140)],
     ["<b>iOS 27</b>", "Liquid Glass", "No ads"],
     "M1150 560 C 1290 700, 1230 860, 1150 760 C 1090 680, 1230 640, 1260 760"),
    ("2-block-style", "Style <em>every</em><br>block", "Its own font, size and colour — or all at once.",
     [("This block", 40, 1980), ("Whole design", 820, 2130)],
     [],
     "M170 560 C 30 700, 90 860, 170 760 C 230 680, 90 640, 60 760"),
    ("3-templates", "Start from a<br><em>template</em>", "Blank, clock hubs, app grids, type and more.",
     [("Ready in one tap", 780, 1500)],
     [],
     "M1150 560 C 1290 700, 1230 860, 1150 760 C 1090 680, 1230 640, 1260 760"),
    ("4-home", "All your designs,<br><em>one place</em>", "Pick one per widget in Edit Widget.",
     [("Live preview", 40, 1300)],
     [],
     "M170 560 C 30 700, 90 860, 170 760 C 230 680, 90 640, 60 760"),
    ("5-settings", "Matched to your<br><em>wallpaper</em>", "Two screenshots, and every widget blends in.",
     [("Light &amp; Dark Mode", 790, 1520)],
     ["No account", "No tracking", "<b>Public API</b>"],
     "M1150 560 C 1290 700, 1230 860, 1150 760 C 1090 680, 1230 640, 1260 760"),
]

PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{name}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@500;700;800&display=swap">
<style>
*{{box-sizing:border-box}}
body{{margin:0;width:1320px;height:2868px;overflow:hidden;position:relative;font-family:Inter,-apple-system,sans-serif;color:#fff;
 background:radial-gradient(70% 38% at 50% 64%,rgba(214,120,70,.30) 0%,rgba(214,120,70,0) 70%),radial-gradient(60% 25% at 50% 0%,rgba(255,199,102,.10) 0%,rgba(255,199,102,0) 70%),#120c09}}
.head{{position:absolute;top:140px;left:0;right:0;text-align:center;padding:0 70px;z-index:6}}
h1{{font-size:124px;line-height:1.02;font-weight:800;letter-spacing:-3.5px;margin:0}}
h1 em{{font-style:normal;background:linear-gradient(90deg,#FFD58A,#FFB45C);-webkit-background-clip:text;background-clip:text;color:transparent}}
.sub{{font-size:48px;line-height:1.25;margin:28px 0 0;color:rgba(255,255,255,.78);font-weight:500}}
.ribbon{{position:absolute;inset:0;z-index:1;pointer-events:none}}
.phone{{position:absolute;left:174px;top:{phone_top}px;width:972px;height:2052px;border-radius:150px;background:#0b0b0d;padding:26px;z-index:2;
 box-shadow:0 80px 160px rgba(0,0,0,.65),0 0 0 2px rgba(255,255,255,.08),inset 0 0 0 4px #3b3a3f}}
.phone img{{display:block;width:920px;height:2000px;border-radius:124px}}
.pill{{position:absolute;z-index:8;padding:24px 40px;border-radius:999px;font-size:44px;font-weight:700;white-space:nowrap;box-shadow:0 20px 44px rgba(0,0,0,.5);
 background:linear-gradient(180deg,#FFD58A,#FFBE5C);color:#1A1306}}
.badges{{position:absolute;left:0;right:0;top:2740px;display:flex;justify-content:center;gap:22px;z-index:8}}
.badges span{{padding:18px 32px;border-radius:999px;font-size:36px;font-weight:700;background:rgba(18,12,9,.85);border:2px solid rgba(255,255,255,.22);color:#fff}}
.badges span b{{color:#FFC766}}
</style></head><body>
<svg class="ribbon" width="1320" height="2868" viewBox="0 0 1320 2868"><defs><linearGradient id="rb" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFD58A"/><stop offset="1" stop-color="#D9783E"/></linearGradient></defs><path d="{ribbon}" fill="none" stroke="url(#rb)" stroke-width="12" stroke-linecap="round" opacity=".95"/></svg>
<div class="head"><h1>{title}</h1><p class="sub">{line}</p></div>
<div class="phone"><img src="../raw/{name}.jpg" alt=""></div>
{pills}
{badges}
</body></html>
"""

for name, title, line, pills, badges, ribbon in SHOTS:
    pill_html = "\n".join(f'<div class="pill" style="left:{x}px;top:{y}px">{text}</div>' for text, x, y in pills)
    badge_html = f'<div class="badges">{"".join(f"<span>{b}</span>" for b in badges)}</div>' if badges else ""
    # With badges the phone sits a little higher so they fit below it.
    phone_top = 640 if badges else 680
    (HERE / "src" / f"{name}.html").write_text(
        PAGE.format(name=name, title=title, line=line, pills=pill_html, badges=badge_html,
                    ribbon=ribbon, phone_top=phone_top), encoding="utf-8")
    print("wrote", name)
