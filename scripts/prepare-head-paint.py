"""Prepare the six head studies for Blender. Pass a MediaPipe face_landmarker.task file."""
import subprocess
import json
import sys
from pathlib import Path

import mediapipe as mp
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, map_coordinates

root = Path(__file__).resolve().parents[1]
dest = root / "art/portraits"
master = Image.open(dest / "paint-master.png").convert("RGB")
names = ("messi", "ronaldo", "mbappe", "yamal", "haaland", "vinicius")
geom = {}
options = mp.tasks.vision.FaceLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=sys.argv[1]))
with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
    for i, name in enumerate(names):
        x, y = i % 3, i // 3
        tile = master.crop((x*512, y*512, (x+1)*512, (y+1)*512))
        rgb = np.array(tile)
        result = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
        marks = np.array([(p.x, p.y, p.z) for p in result.face_landmarks[0]])
        # Extend color into the margin to prevent white filtering seams on swept hair.
        mask = rgb.min(axis=2) < 194
        _, coords = distance_transform_edt(~mask, return_indices=True)
        filled = rgb[tuple(coords)]
        yy, xx = np.mgrid[:512, :512] / 511
        # Tile an actual strip of the painted crown around the back and temples.
        sx = 256 + 86*np.sin(2*np.pi*xx + .8*yy)
        sy = 48 + 15*np.sin(6*np.pi*xx + yy*9) + 12*np.cos(yy*17)
        if name == "haaland":
            sy += 4
        hair = np.stack([map_coordinates(filled[:,:,c], [sy, sx], order=1) for c in range(3)], axis=2)
        cheek = np.median(rgb[round(marks[50,1]*512)-3:round(marks[50,1]*512)+4,
                              round(marks[50,0]*512)-3:round(marks[50,0]*512)+4], axis=(0,1))
        nape = .80 if name == "haaland" else .63 if name == "yamal" else .59
        taper = np.clip((yy - nape + .10*(xx-.5)**2)/(.11 if name != "haaland" else .025), 0, 1)[:,:,None]
        noise = np.random.default_rng(i).normal(0, 2, (512,512,1))
        rear = np.clip((hair*.95 + noise)*(1-taper) + cheek*taper, 0, 255).astype("uint8")
        image = Image.new("RGB", (1024,512))
        image.paste(Image.fromarray(filled))
        image.paste(Image.fromarray(rear), (512,0))
        image.save(dest / (name + ".png"), optimize=True)
        # Radial contour from the cheek centre, constrained to the lower jaw
        # so the piece of neck in the study never becomes part of the head.
        oval = json.loads((root / "art/portrait-fits.json").read_text())["oval"]
        center = np.array([marks[1,0], (marks[10,1]+marks[152,1])/2])
        contour = []
        for index in oval:
            point = marks[index,:2]
            direction = point - center
            limit = 1.88 if direction[1] < -.085 else 1.045
            r = np.arange(1,limit,.004)
            test = np.clip(((center+r[:,None]*direction)*511).astype(int),0,511)
            valid = r[mask[test[:,1],test[:,0]]]
            contour.append((center + direction*(max(1, valid[-1]-.009) if len(valid) else 1)).tolist())
        geom[name] = {"points": marks.round(6).tolist(), "outline": np.round(contour,6).tolist()}
(dest / "landmarks.json").write_text(json.dumps(geom, separators=(",",":")))
subprocess.run([sys.executable, str(root / "scripts/pack-player-atlases.py")], check=True)
