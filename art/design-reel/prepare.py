"""Prepare Remotion stills from the two game checkouts with Python and Pillow."""
from pathlib import Path
import argparse
from PIL import Image

project = Path(__file__).resolve().parent
soccer = project.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--freight", type=Path, default=soccer.parent / "Blackout Freight")
freight = parser.parse_args().freight
shots = {
    "players": (soccer / "art/matchday-roster.png", 1960),
    "board": (soccer / "art/programme/board-print-studio.png", 1360),
    "club": (soccer / "art/programme/club-print-studio.png", 1140),
    "sentinel": (freight / "assets/sentinel/Sentinel.png", 1750),
    "drone": (freight / "dist/Blackout Freight Patrol.jpg", 1360),
    "receiver": (freight / "dist/Blackout Freight Receiver.jpg", 1360),
}
output = project / "public"
output.mkdir(exist_ok=True)
for name, (source, limit) in shots.items():
    with Image.open(source) as image:
        rgb = image.convert("RGB")
        rgb.thumbnail((limit, limit), Image.Resampling.LANCZOS)
        rgb.save(output / (name + ".jpg"), quality=92, optimize=True)
