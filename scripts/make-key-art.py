"""Generate editable original key art from the in-game land mask and club catalog."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
WHITE, MINT, NAVY = "#fff8e6", "#80e3a8", "#19364d"
GOLD, TEAL = "#ffbf50", "#23596b"
DEFS = """
<linearGradient id="night" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#e5f6ef"/><stop offset="1" stop-color="#94cfdb"/></linearGradient>
<linearGradient id="pool" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#4c7890"/><stop offset="1" stop-color="#80b5bc"/></linearGradient>
<linearGradient id="lime" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#f1a634"/><stop offset="1" stop-color="#ffe2a2"/></linearGradient>
<radialGradient id="beam"><stop stop-color="#fff8d5" stop-opacity=".75"/><stop offset="1" stop-color="#1f5076" stop-opacity="0"/></radialGradient>
<pattern id="grid" width="38" height="38" patternUnits="userSpaceOnUse"><path d="M0 38V0H38" fill="none" stroke="#719aaf" stroke-opacity=".17"/></pattern>
"""


def rect(x, y, w, h, fill, r=0, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" {extra}/>'


def label(x, y, value, size, fill=WHITE, weight=700, extra=""):
    return f'<text x="{x}" y="{y}" fill="{fill}" font-family="Helvetica Neue, Arial, sans-serif" font-size="{size}" font-weight="{weight}" {extra}>{value}</text>'


def ball(cx, cy, scale, fill, back):
    def poly(cx, cy, radius, n, turns=0):
        return " ".join(f"{cx + radius * math.cos(turns + 2*math.pi*i/n):.2f},{cy + radius * math.sin(turns + 2*math.pi*i/n):.2f}" for i in range(n))
    pieces = [f'<circle r="49" fill="{fill}"/>']
    for j in range(5):
        angle = -math.pi / 2 + j * 2 * math.pi / 5
        x, y = 44 * math.cos(angle), 44 * math.sin(angle)
        pieces.append(f'<path d="M{x:.2f} {y:.2f}L{16*math.cos(angle):.2f} {16*math.sin(angle):.2f}" stroke="{back}" stroke-width="3"/>')
        pieces.append(f'<polygon points="{poly(x,y,11,5,angle)}" fill="{back}"/>')
    pieces.append(f'<polygon points="{poly(0,0,17,5,-math.pi/2)}" fill="{back}"/>')
    return f'<g transform="translate({cx} {cy}) scale({scale})"><defs><clipPath id="ball-{cx}"><circle r="49"/></clipPath></defs><g clip-path="url(#ball-{cx})">{"".join(pieces)}</g></g>'


def shield(x, y, s, lines=True):
    art = '<path d="M-102 -115H102V5Q99 72 0 119Q-99 72-102 5Z" fill="#091620" stroke="#83cbb3" stroke-width="3"/>'
    art += '<path d="M-90 -103H90V3Q86 61 0 103Q-86 61-90 3Z" fill="url(#lime)"/>'
    art += '<path d="M-77 -90H77V-45H-77ZM-66 59Q-30 84 0 95Q30 84 66 59Z" fill="#89d8a3"/>'
    if lines:
        art += label(0, -63, "W D", 20, NAVY, 900, 'text-anchor="middle" letter-spacing="5"')
    return (
        f'<g transform="translate({x} {y}) scale({s})">{art}{ball(0, 0, 1.11, NAVY, GOLD)}'
        '<path d="M-44 64H44" stroke="#273b43" stroke-width="3" stroke-linecap="round"/></g>'
    )


def token(x, y, s, kit, trim, skin, hair, number, longhair=False):
    body = [
        '<ellipse cy="4" rx="55" ry="17" fill="#000" opacity=".25"/>',
        '<path d="M-48-9Q0-29 48-9V2Q42 16 0 16T-48 2Z" fill="#112231"/>',
        f'<ellipse cy="-9" rx="48" ry="14" fill="{kit}"/>',
        '<ellipse cy="-10" rx="40" ry="9" fill="#232c42" opacity=".65"/>',
        f'<path d="M-26-52h20v33h-20zM7-52h20v33H7z" fill="{kit}"/>',
        '<path d="M-30-22H-5v9h-27zM6-22h25l4 9H5z" fill="#0f1824" stroke="#93a9b6" stroke-width="1"/>',
        f'<path d="M-30-76h59v28H5l-5-8-6 8h-24z" fill="{trim}"/>',
        f'<path d="M-31-104l-19 33 12 6 17-25M29-104l22 29-11 8-19-24" fill="{skin}"/>',
        f'<path d="M-32-111l16-9H17l15 10 14 19-19 11-3-7v18h-51v-18l-4 7-17-10Z" fill="{kit}"/>',
        f'<path d="M-25-83H24v14h-51zM-12-121h25l-4 12H-8Z" fill="{trim}"/>',
        rect(-18, -106, 36, 25, trim, 4),
        label(0, -87, number, 16, WHITE, 900, 'text-anchor="middle"'),
        rect(-27, -168, 55, 48, skin, 10),
        f'<path d="M-29-148l1-18q3-13 27-13 26 0 30 15v11l-9-8-15 3-18-4-12 14z" fill="{hair}"/>',
        '<path d="M-13-143h3m21 0h3M-4-130q5 3 9-1" fill="none" stroke="#231a23" stroke-width="3" stroke-linecap="round"/>',
        '<path d="M-28-161q-6 4-5 13v9h7" fill="#fff" opacity=".16"/>',
    ]
    if longhair:
        body.insert(-4, f'<path d="M18-164q36-8 24 29l-8 17-12-8 8-16-6-8Z" fill="{hair}"/>')
    return f'<g transform="translate({x:.1f} {y:.1f}) scale({s})">{"".join(body)}</g>'


def canvas(width, height, vw, vh, elements, title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {vw} {vh}" role="img"><title>{title}</title><defs>{DEFS}</defs>{elements}</svg>\n'


land = [tuple(map(int, row)) for row in re.findall(r"\{(\d+), (\d+), (\d+)\},", (ROOT / "src/server/MapData.luau").read_text())]
catalog = (ROOT / "src/shared/Board.luau").read_text()
leagues, board = catalog.split("Board.tiles =", 1)
palette = ["#" + color for color in re.findall(r"color = 0x([0-9A-Fa-f]{6})", leagues)]
board = board.split("for _, tile", 1)[0]
tiles = []
for row in board.splitlines():
    if m := re.search(r'club\("[^"]+", "([^"]+)", "[^"]+", (\d+), (\d+),', row):
        code, group, price = m.groups()
        tiles.append((code, palette[int(group) - 1], price))
    elif m := re.search(r'stop\("([^"]+)", "[^"]+", "([^"]+)"', row):
        kind, code = m.groups()
        tiles.append((code, {"kickoff": MINT, "tactics": "#eb9df7", "whistle": "#f78c81"}.get(kind, "#ffd47a"), ""))
path = ([(i, 6) for i in range(7)] + [(6, 6-i) for i in range(1, 7)]
        + [(6-i, 0) for i in range(1, 7)] + [(0, i) for i in range(1, 6)])
assert len(path) == len(tiles) == 24

# Perspective keeps rectangular tiles readable and the route orientation follows the game.
def iso(x, y):
    return 678 + x + 0.31 * y, 236 - 0.27 * x + 0.76 * y


top = [rect(0, 0, 655, 550, "url(#pool)", 18, 'stroke="#4f8c91" stroke-width="5"'),
       rect(12, 12, 631, 526, "#275469", 14, 'stroke="#a4ebbc" stroke-width="1.2"'),
       rect(104, 88, 447, 358, "#8ccadb", 8)]
for i in range(115, 545, 21):
    top.append(f'<path d="M{i} 93V439" stroke="#e6f2f3" opacity=".48"/>')
for i in range(93, 444, 21):
    top.append(f'<path d="M109 {i}H548" stroke="#e6f2f3" opacity=".48"/>')
for y, x, length in land:
    top.append(rect(112 + x * 6, 110 + y * 9.6, length * 6 + 0.2, 9.8,
                    ["#77bda0", "#86c198", "#a2cf8c"][y % 3]))
europe_x = 112 + (9 + 180) * 72 * 6 / 360
europe_y = 110 + (83 - 48) * 30 * 9.6 / 141
top.append(f'<circle cx="{europe_x}" cy="{europe_y}" r="9" fill="{GOLD}" opacity=".40"/>'
           f'<circle cx="{europe_x}" cy="{europe_y}" r="4.7" fill="{GOLD}"/>')

for (col, row), (code, accent, price) in zip(path, tiles):
    x, y = 21 + col * 88, 18 + row * 74
    top += [
        rect(x, y, 82, 65, WHITE, 6, f'stroke="{accent}" stroke-width="2"'),
        rect(x, y, 82, 4, accent, 2),
        label(x + 41, y + 34, code, 22, NAVY, 900, 'text-anchor="middle"'),
        label(x + 41, y + 53, (price + " CR") if price else "", 11, NAVY, 700, 'text-anchor="middle"'),
    ]
top += [rect(228, 408, 199, 32, NAVY, 5), label(327, 430, "CONTINENTAL CUP", 14, WHITE, 850, 'text-anchor="middle" letter-spacing="1"')]
lines = ''.join(f'<path d="M{x} 0L{x-305} 900" stroke="#35839b" opacity=".25" stroke-width="1"/>' for x in [1130, 1190, 1250, 1310, 1370, 1430, 1490, 1550, 1610, 1670, 1730, 1790])
ground = '<ellipse cx="1135" cy="430" rx="640" ry="530" fill="url(#beam)"/>'
shadow = '<path d="M623 643L1333 463L1540 596L839 824Z" fill="#225673" opacity=".26"/>'
platform = f'<g transform="matrix(1 -.27 .31 .76 678 236)">{rect(0,30,655,550,"#25485d",18)}{rect(0,15,655,550,GOLD,18)}{"".join(top)}</g>'
tokens = [
    token(*iso(310, 35), 0.62, "#f4d46b", "#39453f", "#cf9269", "#3b2a27", "CT"),
    token(*iso(170, 169), 0.62, "#f588a5", "#402a49", "#bd785b", "#262132", "RF"),
    token(*iso(546, 122), 0.62, "#6cbfff", "#29315a", "#f4bd93", "#233653", "17"),
    token(*iso(107, 422), 0.86, "#ff9f69", "#57263b", "#ac6244", "#30182c", "09", True),
    token(*iso(345, 384), 1.09, "#7bfaaa", "#193f37", "#c88d62", "#251820", "08"),
    token(*iso(568, 453), 1.00, "#ebacff", "#492a67", "#885341", "#221c2c", "01"),
]
cup = '''
<g transform="translate(1148 563) scale(.83)">
<ellipse cy="58" rx="52" ry="13" fill="#01060c" opacity=".45"/>
<path d="M-20 1H-43Q-47 31-12 30M20 1H43Q47 31 12 30" fill="none" stroke="#ffc962" stroke-width="9"/>
<path d="M-29-8H29L22 24Q18 37 5 38v11h14v9h-38v-9h14V38Q-18 37-22 24Z" fill="#ffe492"/>
<path d="M-24-3H24" stroke="#fff4bb" stroke-width="4"/>
</g>'''
left = (
    shield(114, 148, 0.38)
    + label(179, 145, "FOOTBOLAPOLIA", 29, NAVY, 900, 'letter-spacing="2"')
    + label(72, 373, "THE WORLD", 88, NAVY, 900, 'letter-spacing="-3"')
    + label(65, 503, "DRAFT", 147, TEAL, 900, 'letter-spacing="-5"')
    + rect(77, 542, 86, 6, GOLD, 3)
    + label(77, 608, "Build your football empire.", 29, NAVY, 650)
)
art = rect(0, 0, 1600, 900, "url(#night)") + ground + lines + shadow + platform + "".join(tokens) + cup + left
(ART / "world-draft-thumb.svg").write_text(canvas(1920, 1080, 1600, 900, art, "Footbolapolia: The World Draft — cover"))
icon = (
    rect(0, 0, 512, 512, "url(#night)")
    + rect(0, 0, 512, 512, "url(#grid)")
    + '<ellipse cx="254" cy="241" rx="285" ry="244" fill="url(#beam)"/>'
    + '<circle cx="256" cy="227" r="187" fill="none" stroke="#65b6a6" stroke-opacity=".65" stroke-width="2" stroke-dasharray="6 9"/>'
    + '<path d="M48 222H464M256 30V424" stroke="#70bcab" stroke-opacity=".38" stroke-width="2"/>'
    + shield(256, 220, 1.36)
    + label(256, 452, "WORLD DRAFT", 40, NAVY, 900, 'text-anchor="middle" letter-spacing="1.5"')
    + label(256, 479, "F O O T B O L A P O L I A", 12, TEAL, 700, 'text-anchor="middle"')
)
(ART / "world-draft-icon.svg").write_text(canvas(512, 512, 512, 512, icon, "World Draft — game icon"))
print(f"Created key art for {len(tiles)} tiles and {len(land)} map spans")
