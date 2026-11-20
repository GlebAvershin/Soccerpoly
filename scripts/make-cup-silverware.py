"""Build the fluted Continental Cup and export it for the stadium's scoreboard."""
import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, export_shapes

bpy.ops.wm.read_factory_settings(use_empty=True)
positions, faces, finishes = [], [], []
gold, gold_light, enamel = 0, 1, 2

def skin(rings, finish):
    base = len(positions)
    count = len(rings[0])
    for ring in rings:
        positions.extend(ring)
    for j in range(len(rings) - 1):
        for i in range(count):
            a = base + j * count + i
            b = base + j * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
            finishes.append(finish[j])

# An inward return at the rim gives the vessel a visible lip and interior.
profile = [
    (.01,0,enamel), (.86,0,enamel), (.92,.07,enamel), (.92,.26,enamel), (.86,.32,gold),
    (.84,.37,gold_light), (.65,.39,gold), (.39,.49,gold), (.26,.66,gold_light),
    (.21,.97,gold), (.32,1.07,gold_light), (.32,1.16,gold), (.25,1.20,gold),
    (.51,1.32,gold), (.81,1.52,gold), (1.01,1.85,gold), (1.13,2.24,gold),
    (1.16,2.65,gold_light), (1.23,2.69,gold), (1.23,2.76,gold_light),
    (1.15,2.80,gold), (1.09,2.73,gold), (1.04,2.35,gold), (.81,1.83,gold), (.02,1.44,gold),
]
angles = [math.tau * i / 64 for i in range(64)]
rings = []
for i, (radius, height, _) in enumerate(profile):
    flute = .058 * math.sin(math.pi * (height-1.2)/1.49) if 12 < i < 18 else 0
    rings.append([((radius + flute*math.cos(16*a))*math.cos(a),
                   (radius + flute*math.cos(16*a))*math.sin(a),height) for a in angles])
skin(rings, [p[2] for p in profile[:-1]])

for side in (-1, 1):
    # An oval sweep follows a cubic curve from the lip back to the lower bowl.
    points = [(1.12,2.55),(2.07,3.11),(1.85,1.72),(.86,1.72)]
    rings = []
    for step in range(25):
        t = step/24
        u = 1-t
        x,z = [u**3*points[0][k]+3*u*u*t*points[1][k]+3*u*t*t*points[2][k]+t**3*points[3][k] for k in (0,1)]
        dx,dz = [3*u*u*(points[1][k]-points[0][k])+6*u*t*(points[2][k]-points[1][k])+3*t*t*(points[3][k]-points[2][k]) for k in (0,1)]
        length = math.hypot(dx,dz)
        ring = []
        for k in range(10):
            a = math.tau * k / 10
            offset = (.085 + .035*math.cos(math.pi*t)**2)*math.cos(a)
            ring.append((side*(x-offset*dz/length),side*.10*math.sin(a),z+offset*dx/length))
        rings.append(list(reversed(ring)))
    skin(rings, [gold_light]*24)

mesh = bpy.data.meshes.new("Chased bowl, rolled lip and scroll handles")
mesh.from_pydata(positions, [], faces)
mesh.update()
cup = bpy.data.objects.new("continental_silverware", mesh)
bpy.context.collection.objects.link(cup)
for name, color in [("Hammered brass","D8A451"),("Polished edge","F5D789"),("Green enamel","193F36")]:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(int(color[i:i+2],16)/255 for i in (0,2,4))+(1,)
    mat.metallic, mat.roughness = .75, .27
    mesh.materials.append(mat)
for face, index in zip(mesh.polygons, finishes):
    face.material_index, face.use_smooth = index, True

cup.asset_mark()
bpy.context.view_layer.objects.active = cup
cup.select_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/continental-silverware.blend"), compress=True)
export_shapes([cup], "src/client/CupMeshData.luau", include_bounds=True)
