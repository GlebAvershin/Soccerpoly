"""Prepare the two-tier grandstand matte for the replay stadium's three walls."""
from pathlib import Path
import runpy

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
pack = runpy.run_path(str(ROOT / "scripts/pack-programme.py"))["pack"]
source = Image.open(ROOT / "art/programme/matchday-grandstand.png").convert("RGB")
image = source.resize((1024, 342), Image.Resampling.LANCZOS)
# Feather the join at the repeat boundary before splitting across the three
# physical walls. The repeated clouds and canopy then meet through each corner.
edge = 80
left, right = image.crop((0, 0, edge, 342)), image.crop((1024-edge, 0, 1024, 342))
blend = Image.new("L", (edge, 1))
blend.putdata([round(255*x/(edge-1)) for x in range(edge)])
edge_band = Image.composite(left, right, blend.resize((edge,342)))
image = image.crop((0,0,1024-edge,342))
image.paste(edge_band,(0,0))
image = image.quantize(192)
(ROOT / "src/client/ReplayPanorama.luau").write_text(
    "--!strict\n-- Packed by scripts/pack-replay-panorama.py.\nreturn {\n" + pack("grandstand", image) + "\n}\n")
