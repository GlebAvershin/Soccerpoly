"""Original architectural screen prints for the Continental Cup board and dossiers."""
import io
from pathlib import Path
from xml.etree import ElementTree as ET

import resvg_py
from PIL import Image

ART = Path(__file__).resolve().parents[1] / "art/programme"
ROOT = ET.fromstring((ART / "grounds.svg").read_text())
ET.register_namespace("", "http://www.w3.org/2000/svg")
DRAWINGS = {node.attrib["id"]: ET.tostring(node, encoding="unicode")
            for node in ROOT.find("{*}defs")}
# Sky, sun, coloured enamel, structural shadow. Each region has a distinct air colour.
REGIONS = {
    "spain": ("F2B394","FFE8BB","B14C52","592C46"),
    "england": ("9DBFC0","F9DE98","497D82","204453"),
    "germany": ("BFD0A8","FBE3A5","62867D","294C4C"),
    "italy": ("EABCA8","FBDF9D","BA6555","613F4A"),
    "france": ("B1BBDA","F1D6B1","707BA7","414967"),
}
CLUB_GROUNDS = {
    "SEV":"brick", "ATM":"canopy", "FCB":"quilt", "RMA":"shell",
    "ARS":"shell", "LIV":"brick", "MCI":"canopy", "MUN":"brick",
    "B04":"shell", "RBL":"canopy", "BVB":"towers", "BAY":"quilt",
    "ACM":"towers", "INT":"towers", "JUV":"canopy", "NAP":"shell",
    "OL":"quilt", "OM":"canopy", "ASM":"brick", "PSG":"shell",
}
VENUES = {"SB":("spain","shell"), "OT":("england","brick"),
          "SS":("italy","towers"), "AA":("germany","quilt")}
EVENTS = {"kickoff":("germany","whistle"), "chance":("france","cards"),
          "chanceWest":("italy","cards"), "chanceEast":("germany","cards"),
          "tax":("italy","turnstile"), "tour":("england","tour"),
          "championship":("spain","trophy"), "bench":("england","bench")}


def render(key, region, motif, *, club=False):
    sky, sun, enamel, shadow = ("#"+v for v in REGIONS[region])
    event = key in EVENTS
    art = DRAWINGS[motif].replace("LIGHT",sun).replace("DARK",shadow).replace("BODY",enamel)
    position = ("translate(152 -95) scale(1.95)" if event else
                "translate(112 -2) scale(1.14)" if club else "translate(42 -14) scale(1.27)")
    # Print the oblique shadows in large shapes; there is no micro-text or baked-in lettering.
    variant = sum(map(ord,key))
    sun_x = 148 + variant % 107
    lower = 194 + variant % 14
    skyline = "".join(f'<path d="M{x} 180v-{h}h{w}v{h}z"/>'
                      for x,w,h in [(0,89,20),(77,33,33),(118,67,18),(163,72,28),(271,50,28),
                                    (339,62,21),(423,44,32),(475,71,16),(566,90,27)])
    # Alternating banks of floodlights and raked beams suggest different home grounds.
    mast_x = 530 if variant % 2 else 86
    panorama = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 256">
      <defs><linearGradient id="sky" x2="0.8" y2="1"><stop stop-color="{sky}"/><stop offset="1" stop-color="{sun}"/></linearGradient></defs>
      <rect width="640" height="256" fill="url(#sky)"/>
      <circle cx="{sun_x}" cy="83" r="60" fill="{sun}"/>
      <g fill="{enamel}" opacity=".22">{skyline}</g>
      <path d="M0 175Q182 149 301 169T640 143v114H0Z" fill="{enamel}" opacity=".38"/>
      <path d="M0 {lower}Q232 223 640 {lower-23}v88H0Z" fill="{shadow}"/>
      <path d="M0 {lower+35}Q277 197 640 {lower+29}M55 256Q300 204 640 219" fill="none" stroke="{enamel}" stroke-width="4"/>
      <g stroke="{enamel}" stroke-width="3"><path d="M{mast_x} 165v-78m-11 2l25-6m-25 2l25-6"/></g>
      <g transform="{position}">{art}</g>
      </svg>'''
    data = resvg_py.svg_to_bytes(svg_string=panorama, width=960, height=384)
    return Image.open(io.BytesIO(data)).convert("RGB")
