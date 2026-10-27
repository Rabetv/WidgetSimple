"""App Store screenshots (6.9", 1320 x 2868) from real app screens.

Each shot: a bold headline and one short line on a warm background, and the app
screen (raw/*.jpg, 920 x 2000) at its native size in a phone frame. Writes
src/*.html; render them with render.sh (headless Chrome).
"""
from pathlib import Path

HERE = Path(__file__).parent

SHOTS = [
    ("1-designer", "Build your own widget", "Clocks, dates, greetings and up to 12 apps — placed where you want them.", "#F3E3D3", "#E7C9AE"),
    ("2-block-style", "Style every block", "Its own font, size and colour — or the whole design at once.", "#F1DFCF", "#DDB898"),
    ("3-templates", "Start from a template", "Blank, clock hubs, app grids, type specimens and more.", "#F4E6D8", "#E3C2A4"),
    ("4-home", "All your designs in one place", "Pick one per widget: touch and hold › Edit Widget.", "#F2E1D1", "#D9B392"),
    ("5-settings", "Matched to your wallpaper", "Two screenshots, and every widget blends into your Home Screen.", "#F3E4D6", "#E0BE9F"),
]

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<style>
  html, body {{ margin: 0; width: 1320px; height: 2868px; overflow: hidden; }}
  body {{
    background: linear-gradient(170deg, {top} 0%, {bottom} 100%);
    font-family: "Segoe UI", "SF Pro Display", Arial, sans-serif;
    color: #2B1A10;
    position: relative;
  }}
  .copy {{ position: absolute; top: 170px; left: 110px; right: 110px; text-align: center; }}
  h1 {{ margin: 0; font-size: 118px; line-height: 1.02; font-weight: 900; letter-spacing: -3px; }}
  p {{ margin: 34px auto 0; max-width: 1000px; font-size: 50px; line-height: 1.25; font-weight: 600; color: #6B4A36; }}
  .phone {{
    position: absolute; left: 50%; top: 660px; transform: translateX(-50%);
    width: 920px; height: 2000px; padding: 26px;
    background: #141010; border-radius: 150px;
    box-shadow: 0 60px 120px rgba(60, 30, 10, 0.35), 0 0 0 4px #3A2A22 inset;
  }}
  .phone img {{ display: block; width: 920px; height: 2000px; border-radius: 126px; }}
</style></head>
<body>
  <div class="copy"><h1>{title}</h1><p>{line}</p></div>
  <div class="phone"><img src="../raw/{name}.jpg" alt=""></div>
</body></html>
"""

for name, title, line, top, bottom in SHOTS:
    (HERE / "src" / f"{name}.html").write_text(
        PAGE.format(name=name, title=title, line=line, top=top, bottom=bottom), encoding="utf-8")
    print("wrote", name)
