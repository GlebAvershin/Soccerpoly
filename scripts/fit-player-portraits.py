"""Measure neutralized face geometry and pigment from the DCC reference set.

Run with MediaPipe, NumPy and Pillow in an isolated Python environment. Pass the
reference directory and output path. Source JPEGs are used during fitting.
"""
from argparse import ArgumentParser
import json
from pathlib import Path

import mediapipe as mp
import numpy as np
from PIL import Image

REFERENCES = {
    "messi": "messi-uefa.jpg",
    "ronaldo": "ronaldo-2021.jpg",
    "mbappe": "mbappe-uefa.jpg",
    "yamal": "yamal-uefa.jpg",
    "haaland": "haaland-uefa.jpg",
    "vinicius": "vinicius-uefa.jpg",
}
STABLE = [10, 33, 133, 263, 362, 168, 8, 6, 197, 234, 454, 127, 356, 50, 280, 152]
OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377,
        152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]


def fit(detector, image, canonical):
    image = image.convert("RGB")
    image.thumbnail((1000, 1000))
    rgb = np.asarray(image)
    detected = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
    if len(detected.face_landmarks) != 1:
        raise ValueError(f"Expected a single head, found {len(detected.face_landmarks)}")
    marks = np.array([(p.x, p.y, p.z) for p in detected.face_landmarks[0]])
    w, h = image.size
    cloud = marks * [w, -h, -w]
    anchor = cloud[STABLE]
    hint = canonical[STABLE]
    # Orthogonal fit removes the tilt of the camera while leaving individual
    # proportions and expressions in the measured points.
    u, _, vh = np.linalg.svd((anchor - anchor.mean(axis=0)).T @ (hint - hint.mean(axis=0)))
    u[:, -1] *= np.linalg.det(u @ vh)
    cloud = (cloud - anchor.mean(axis=0)) @ (u @ vh)
    chin, crown = cloud[152, 1], cloud[10, 1]
    scale = 1.20 / (crown - chin)
    cx = np.mean(cloud[[234, 454], 0])
    cz = np.mean(cloud[[234, 454, 127, 356], 2])
    cloud = (cloud - [cx, chin, cz]) * scale + [0, -.63, -.025]
    cloud[:, 2] *= 1.16

    colors = []
    for x, y, _ in marks:
        i = min(w-3, max(2, round(x*w)))
        j = min(h-3, max(2, round(y*h)))
        colors.append(rgb[j-1:j+2, i-1:i+2].mean(axis=(0, 1)))
    colors = np.asarray(colors)
    # Portrait lights vary between players. Softly compress shadows and specular peaks.
    reference = np.median(colors[[50, 101, 118, 280, 330, 347, 108, 337]], axis=0)
    colors = reference + (colors - reference) * .79
    colors = np.clip(colors, 0, 255).astype(int)
    # Hide hard patches at the seam where the modeled temporal and rear volumes begin.
    for index in OVAL:
        colors[index] = .20 * colors[index] + .80 * reference
    return {"points": np.round(cloud, 5).tolist(), "pigment": colors.tolist(),
            "base": reference.astype(int).tolist()}


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("reference_dir", type=Path)
    parser.add_argument("output", type=Path)
    opt = parser.parse_args()
    topology = (opt.reference_dir / "canonical_face_model.obj").read_text().splitlines()
    canonical = np.array([[float(v) for v in row.split()[1:]] for row in topology if row.startswith("v ")])
    faces = [[int(item.split("/")[0])-1 for item in row.split()[1:]] for row in topology if row.startswith("f ")]
    options = mp.tasks.vision.FaceLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(opt.reference_dir / "face_landmarker.task")),
        num_faces=1,
    )
    with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
        models = {}
        for name, filename in REFERENCES.items():
            models[name] = fit(detector, Image.open(opt.reference_dir / filename), canonical)
            print(f"{name}: {len(models[name]['points'])} landmarks")
    opt.output.write_text(json.dumps({"faces": faces, "oval": OVAL, "players": models}, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
