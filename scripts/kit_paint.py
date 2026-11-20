"""Wrap original knitted national-color kits and numerals around the jersey mesh."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

KITS = {
    "messi": ("ARG", "MESSI", 10, "E8EDF0", "76BBDF", "1A293A"),
    "ronaldo": ("POR", "RONALDO", 7, "AC1D38","76223E","F8E4A9"),
    "mbappe": ("FRA", "MBAPPÉ", 10, "283D77","28305A","FFF6DF"),
    "yamal": ("ESP", "YAMAL", 19, "C92C2B","9E2328","FFD663"),
    "haaland": ("NOR", "HAALAND", 9, "E8E8DE","213753","243450"),
    "vinicius": ("BRA", "VINI JR.", 7, "F3CC43","DAA937","195947"),
}


def kit_paint(name):
    country, surname, number, main, alt, ink = KITS[name]
    color = lambda value: np.array(list(bytes.fromhex(value)))
    y,x = np.mgrid[:512,:1024]
    side = np.sin(2*np.pi*(x-256)/1024)
    mask = {
        "messi": np.cos(2*np.pi*x/1024*9)>.03,
        "ronaldo": (y > 265+125*side) & (y < 307+126*side),
        "mbappe": (y > 135+60*abs(side)) & (y < 194+50*abs(side)),
        "yamal": ((x+7*np.sin(y/34))%52<7) & (abs(side)>.42),
        "haaland": (side > -.86) & (side < -.70),
        "vinicius": ((x+y)%83<7) | ((x-y)%83<7),
    }[name]
    cloth = np.where(mask[:,:,None], color(alt), color(main)).astype(float)
    # A contrast shoulder yoke, vent panels and knit hem frame the squad number.
    # Keep large colour fields readable from the elevated board camera.
    shoulder = y < 56 + 36*np.abs(side)
    flank = np.abs(side) > .935 + .034*np.sin(y/95)
    cloth[shoulder] = .72*color(alt) + .28*color(ink)
    cloth[flank] = .66*color(alt) + .34*color(ink)
    seam = np.abs(y-(56+36*np.abs(side)))<3
    cloth[seam] = .72*color(main)+.28*color(ink)
    cloth[y>477] = .68*color(main)+.32*color(alt)
    if name=="haaland": cloth[(side>-.74)&(side<-.69)]=[178,46,59]
    if name=="mbappe": cloth[(y>174+57*abs(side)) & (y<183+57*abs(side))]=[178,69,81]
    knit = 1.5*np.sin(x*.76+y*.57)*np.cos(y*1.47) + 1.4*np.sin(x*.14+y*.47)
    ribs = np.cos(y*.65)*np.where(shoulder | flank, 3, .5)
    cloth += (knit+ribs)[:,:,None]
    image=Image.fromarray(np.clip(cloth,0,255).astype("uint8"))
    draw=ImageDraw.Draw(image)
    font_path=Path("/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf")
    bold=lambda size: ImageFont.truetype(str(font_path),size)
    # Seam lies under the left arm. Front centre is at U=.25, back at U=.75.
    for cx, height, top in ((256,157,204),(768,183,182)):
        draw.text((cx,top),str(number),font=bold(height),anchor="mt",fill="#"+ink,
                  stroke_width=1,stroke_fill="#"+main)
    draw.text((768,131),surname,font=bold(34),anchor="mt",fill="#"+ink)
    # Woven shield, cuff-to-collar stitching and twin-needle hem.
    rim, field = "#"+ink, "#"+alt
    draw.polygon([(285,113),(334,113),(331,148),(310,162),(289,147)],fill=rim)
    draw.polygon([(290,118),(329,118),(326,145),(310,155),(294,145)],fill=field)
    # Three folded chevrons read as a sewn badge even on a small pawn.
    for offset in (0,9,18):
        draw.line([(297,124+offset),(310,130+offset),(322,124+offset)],fill=rim,width=3)
    draw.text((197,119),country,font=bold(24),anchor="mt",fill=rim)
    draw.line((181,148,213,148),fill=rim,width=3)
    for x0 in (114,398,625,910):
        sign = 1 if x0 in (114,625) else -1
        for step in range(28):
            y0=18+step*5
            sx=x0+int(sign*31*(1-step/28)**2)
            draw.line((sx,y0,sx+1,y0+2),fill=rim,width=2)
    for hem in (477,483):
        for stitch in range(0,1024,9):
            draw.line((stitch,hem,stitch+4,hem),fill=field,width=2)
    return image
