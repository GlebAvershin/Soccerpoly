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
    if name=="haaland": cloth[(side>-.74)&(side<-.69)]=[178,46,59]
    if name=="mbappe": cloth[(y>174+57*abs(side)) & (y<183+57*abs(side))]=[178,69,81]
    weave = 2*np.sin(x*2.4)*np.cos(y*2.7) + 1.1*np.sin(x*.28+y*.90)
    cloth += weave[:,:,None]
    image=Image.fromarray(np.clip(cloth,0,255).astype("uint8"))
    draw=ImageDraw.Draw(image)
    font_path=Path("/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf")
    bold=lambda size: ImageFont.truetype(str(font_path),size)
    # Seam lies under the left arm. Front centre is at U=.25, back at U=.75.
    for cx, height, top in ((256,157,204),(768,183,182)):
        draw.text((cx,top),str(number),font=bold(height),anchor="mt",fill="#"+ink,
                  stroke_width=1,stroke_fill="#"+main)
    draw.text((768,131),surname,font=bold(34),anchor="mt",fill="#"+ink)
    draw.text((305,134),country,font=bold(21),anchor="mt",fill="#"+ink)
    return image
