"""App Store screenshots from real app screens, in the listing's style with extra flair.

The listing's look (dark warm stage, amber accents) plus: a three-line headline with an
amber last line, one long swooping ribbon, a tilted sticker, a piece of the real screen
popping out of the phone, and amber callouts with dotted leader lines. The phone holds a
real screen (raw/*.jpg, 920 x 2000) at its native size; pop-outs are cut from it.

Writes src/*.html (1320 x 2868, the 6.9" size); render.sh renders them and also writes
1206 x 2622 copies for the "iPhone with Dynamic Island" slot.
"""
from pathlib import Path

HERE = Path(__file__).parent
PHONE_LEFT, PHONE_TOP, BEZEL = 174, 600, 26

# Each shot:
#   lines    three headline lines; the last is amber
#   pop      a piece of the screen (x, y, w, h in raw pixels) shown larger outside the
#            phone: (crop, left, top, scale, degrees)
#   sticker  (text, left, top, degrees, round)
#   callouts (text, left, top, side the dotted leader points to, leader length)
#   ribbon   SVG path drawn behind the phone
SHOTS = [
    dict(name="1-designer", lines=("Design", "Your Own", "Widgets"),
         pop=((100, 450, 720, 100), 60, 1060, 1.42, -4),
         sticker=("iOS 27", 860, 430, -12, False),
         callouts=[("Drag, resize, save", 640, 1760, "left", 90), ("Up to 12 apps", 40, 2380, "right", 110)],
         ribbon="M-60 560 C 260 300, 520 980, 860 620 S 1300 300, 1380 520"),
    dict(name="2-block-style", lines=("Style", "Every Block", "Your Way"),
         pop=((60, 1555, 580, 100), 380, 1960, 1.55, 5),
         sticker=None,
         callouts=[("Font · size · colour", 40, 2460, "right", 120)],
         ribbon="M1380 560 C 1060 300, 800 980, 460 620 S 20 300, -60 520"),
    dict(name="3-templates", lines=("Start From", "Ready-Made", "Templates"),
         pop=((30, 335, 820, 335), 40, 900, 1.2, -3),
         sticker=("NEW", 1000, 470, 10, True),
         callouts=[("One tap to use", 700, 1960, "left", 110)],
         ribbon="M-60 600 C 300 260, 640 1000, 980 640 S 1320 360, 1380 560"),
    dict(name="4-home", lines=("All Your", "Designs in", "One Place"),
         pop=((35, 340, 850, 530), 40, 1180, 1.12, -3),
         sticker=None,
         callouts=[("Live preview", 760, 2280, "left", 100)],
         ribbon="M1380 600 C 1020 260, 680 1000, 340 640 S 0 360, -60 560"),
    dict(name="5-settings", lines=("Blends Into", "Your Own", "Wallpaper"),
         pop=((70, 900, 780, 280), 300, 1500, 1.3, 4),
         sticker=("2 screenshots", 620, 450, -8, False),
         callouts=[("Light & Dark Mode", 40, 2280, "right", 110)],
         ribbon="M-60 560 C 260 300, 520 980, 860 620 S 1300 300, 1380 520"),
]

PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{name}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@600;700;800;900&display=swap">
<style>
*{{box-sizing:border-box}}
body{{margin:0;width:1320px;height:2868px;overflow:hidden;position:relative;font-family:Inter,-apple-system,sans-serif;color:#fff;
 background:radial-gradient(75% 40% at 50% 62%,rgba(214,120,70,.34) 0%,rgba(214,120,70,0) 70%),radial-gradient(60% 22% at 50% 0%,rgba(255,199,102,.12) 0%,rgba(255,199,102,0) 70%),#120c09}}
.head{{position:absolute;top:110px;left:0;right:0;text-align:center;z-index:6}}
h1{{font-size:116px;line-height:1.04;font-weight:900;letter-spacing:-3px;margin:0}}
h1 span{{display:block}}
h1 em{{display:block;font-style:normal;background:linear-gradient(90deg,#FFD58A,#FF9A4A);-webkit-background-clip:text;background-clip:text;color:transparent}}
.ribbon{{position:absolute;inset:0;z-index:1;pointer-events:none}}
.phone{{position:absolute;left:{phone_left}px;top:{phone_top}px;width:972px;height:2052px;border-radius:150px;background:#0b0b0d;padding:{bezel}px;z-index:2;
 box-shadow:0 80px 160px rgba(0,0,0,.65),0 0 0 2px rgba(255,255,255,.08),inset 0 0 0 4px #3b3a3f}}
.phone img{{display:block;width:920px;height:2000px;border-radius:124px}}
.pop{{position:absolute;z-index:7;border-radius:44px;background-repeat:no-repeat;
 box-shadow:0 50px 90px rgba(0,0,0,.6),0 0 0 5px rgba(255,213,138,.85)}}
.sticker{{position:absolute;z-index:9;white-space:nowrap;padding:26px 46px;border-radius:40px;font-size:76px;font-weight:900;letter-spacing:-1px;
 background:linear-gradient(180deg,#E8783A,#B9471B);color:#fff;border:7px solid #FFE3B8;box-shadow:0 24px 50px rgba(0,0,0,.55)}}
.sticker.round{{width:250px;height:250px;padding:0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:84px}}
.callout{{position:absolute;z-index:8;display:flex;align-items:center}}
.pill{{padding:22px 40px;border-radius:999px;font-size:46px;font-weight:800;white-space:nowrap;box-shadow:0 20px 44px rgba(0,0,0,.5);
 background:linear-gradient(180deg,#FFD58A,#FFBE5C);color:#1A1306}}
.leader{{border-top:5px dotted #FFD58A;height:0}}
</style></head><body>
<svg class="ribbon" width="1320" height="2868" viewBox="0 0 1320 2868"><defs><linearGradient id="rb" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFD58A"/><stop offset=".55" stop-color="#E8783A"/><stop offset="1" stop-color="#9C3A17"/></linearGradient></defs><path d="{ribbon}" fill="none" stroke="url(#rb)" stroke-width="16" stroke-linecap="round" opacity=".95"/></svg>
<div class="head"><h1><span>{l1}</span><span>{l2}</span><em>{l3}</em></h1></div>
<div class="phone"><img src="../raw/{name}.jpg" alt=""></div>
{pop}
{sticker}
{callouts}
</body></html>
"""


def pop_html(name, pop):
    (x, y, w, h), left, top, scale, degrees = pop
    return (f'<div class="pop" style="left:{left}px;top:{top}px;width:{w * scale:.0f}px;height:{h * scale:.0f}px;'
            f'background-image:url(../raw/{name}.jpg);background-size:{920 * scale:.0f}px {2000 * scale:.0f}px;'
            f'background-position:-{x * scale:.0f}px -{y * scale:.0f}px;transform:rotate({degrees}deg)"></div>')


def sticker_html(sticker):
    if not sticker:
        return ""
    text, left, top, degrees, round_ = sticker
    cls = "sticker round" if round_ else "sticker"
    return f'<div class="{cls}" style="left:{left}px;top:{top}px;transform:rotate({degrees}deg)">{text}</div>'


def callout_html(text, left, top, side, length):
    leader = f'<div class="leader" style="width:{length}px"></div>'
    pill = f'<div class="pill">{text}</div>'
    inner = leader + pill if side == "left" else pill + leader
    return f'<div class="callout" style="left:{left}px;top:{top}px">{inner}</div>'


for shot in SHOTS:
    name = shot["name"]
    l1, l2, l3 = shot["lines"]
    html = PAGE.format(
        name=name, l1=l1, l2=l2, l3=l3, ribbon=shot["ribbon"],
        phone_left=PHONE_LEFT, phone_top=PHONE_TOP, bezel=BEZEL,
        pop=pop_html(name, shot["pop"]), sticker=sticker_html(shot["sticker"]),
        callouts="\n".join(callout_html(*c) for c in shot["callouts"]))
    (HERE / "src" / f"{name}.html").write_text(html, encoding="utf-8")
    print("wrote", name)
