"""Paint the six match kits and pack their portrait and kit textures for Roblox."""
import base64
import subprocess
from pathlib import Path

from PIL import Image

from kit_paint import KITS, kit_paint

root = Path(__file__).resolve().parents[1]
portraits = root / "art/portraits"
rows = [
    "--!strict",
    "-- Built by scripts/pack-player-atlases.py (Zstd indexed pixels).",
    "return {",
]


def pack_atlas(key, master, size):
    image = master.resize(size, Image.Resampling.LANCZOS)
    indexed = image.quantize(colors=256, dither=Image.Dither.NONE)
    pixels = indexed.tobytes()
    # Roblox's decoder reads the decompressed content size from the Zstd header.
    packed = subprocess.run(
        ["zstd", "-14", f"--stream-size={len(pixels)}", "-q", "-c"],
        input=pixels, capture_output=True, check=True,
    ).stdout
    palette = base64.b64encode(bytes(indexed.getpalette())).decode("ascii")
    indices = base64.b64encode(packed).decode("ascii")
    width, height = size
    return f'    {key} = {{width={width}, height={height}, palette="{palette}", pixels="{indices}"}},'


for name in KITS:
    jersey = kit_paint(name)
    jersey.save(portraits / f"{name}_jersey.png", optimize=True)
    with Image.open(portraits / f"{name}.png") as head:
        rows.append(pack_atlas(name, head, (768, 384)))
    rows.append(pack_atlas(f"{name}_jersey", jersey, (640, 320)))

(root / "src/client/HeadPaint.luau").write_text("\n".join(rows) + "\n}\n")
