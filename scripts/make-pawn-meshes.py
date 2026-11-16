"""Generate the shared sculpted figure pieces with Blender 4.5+.

Run from the project root:
    blender -b -t 2 --python-exit-code 1 --python scripts/make-pawn-meshes.py
After editing the saved shapes:
    blender -b art/pawn-shapes.blend -t 2 --python-exit-code 1 --python scripts/make-pawn-meshes.py -- --export
"""
import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
SEGMENTS = 20

# Height, width radius, depth radius and forward offset in the Roblox orientation.
PROFILES = {
    "head": (
        (-.53, .17, .23, .048), (-.48, .30, .35, .035), (-.36, .43, .45, .050),
        (-.19, .53, .51, .030), (.00, .56, .51, .016), (.19, .55, .49, -.010),
        (.35, .49, .44, -.035), (.46, .36, .32, -.053), (.54, .13, .13, -.055),
    ),
    "jersey": (
        (-.52, .35, .38, -.02), (-.48, .38, .42, -.02), (-.36, .395, .445, -.018),
        (-.16, .425, .465, -.012), (.08, .49, .48, .00), (.28, .535, .46, .012),
        (.40, .51, .41, .00), (.47, .37, .315, -.010), (.52, .19, .235, -.030),
    ),
    "shorts": (
        (-.54, .36, .38, .016), (-.51, .47, .47, .017), (-.42, .51, .50, .010),
        (-.17, .53, .52, .00), (.14, .525, .50, -.028), (.40, .47, .44, -.018),
        (.51, .37, .36, -.006),
    ),
    "forearm": (
        (-.53, .24, .25, .10), (-.45, .39, .40, .11), (-.28, .43, .43, .11),
        (-.10, .48, .48, .045), (.16, .53, .51, -.02), (.36, .49, .46, -.075), (.52, .25, .28, -.10),
    ),
    "sock": (
        (-.54, .26, .28, .045), (-.50, .35, .37, .035), (-.36, .40, .44, .015),
        (-.10, .46, .50, -.035), (.16, .53, .51, -.025), (.41, .52, .48, -.005),
        (.50, .47, .45, .015), (.54, .39, .39, .015),
    ),
    "sleeve": (
        (-.54, .41, .40, .027), (-.49, .48, .49, .036), (-.37, .49, .52, .027),
        (-.11, .53, .55, -.012), (.17, .49, .48, -.04), (.41, .36, .34, -.060), (.53, .21, .22, -.073),
    ),
    "glove": (
        (-.54, .23, .29, .07), (-.45, .44, .45, .08), (-.28, .50, .51, .08),
        (-.08, .53, .52, .04), (.14, .50, .47, -.012), (.32, .37, .40, -.065), (.54, .31, .33, -.10),
    ),
    "boot": (
        (-.54, .35, .43, .06), (-.50, .50, .55, .064), (-.40, .55, .58, .062),
        (-.20, .55, .58, .051), (-.025, .51, .53, .028), (.11, .45, .43, -.030),
        (.29, .35, .31, -.13), (.45, .33, .24, -.20), (.55, .26, .19, -.202),
    ),
}

COLORS = {
    "head": (.41, .24, .14, 1), "jersey": (.12, .53, .30, 1),
    "forearm": (.41, .24, .14, 1), "sock": (.25, .64, .46, 1), "glove": (.79, .83, .72, 1),
    "shorts": (.064, .13, .12, 1), "sleeve": (.15, .52, .72, 1), "boot": (.05, .08, .076, 1),
}


def build(name, profile):
    vertices = []
    for height, radius_x, radius_z, center_z in profile:
        for index in range(SEGMENTS):
            angle = index * math.tau / SEGMENTS
            x = radius_x * math.sin(angle)
            z = center_z + radius_z * math.cos(angle)
            if name == "head" and math.cos(angle) > 0:
                # Central nose bridge tapers into separate cheek and brow volumes.
                z += .125 * math.exp(-((x / .13) ** 2) - (((height + .057) / .155) ** 2))
                z += .026 * math.exp(-(((abs(x) - .26) / .12) ** 2) - (((height + .16) / .14) ** 2))
            if name == "jersey" and math.cos(angle) > 0:
                z += .014 * math.cos((x + height * .45) * 21) * (1 - abs(height)) ** 2
            if name == "glove" and math.cos(angle) > 0:
                z += .056 * math.exp(-((height + .21) / .14) ** 2) * math.cos(x * 19) ** 2
            vertices.append((x, -z, height))
    faces = [tuple(range(SEGMENTS - 1, -1, -1))]
    for row in range(len(profile) - 1):
        for j in range(SEGMENTS):
            lower = row * SEGMENTS
            nxt = (j + 1) % SEGMENTS
            faces.append((lower + j, lower + nxt, lower + nxt + SEGMENTS, lower + j + SEGMENTS))
    faces.append(tuple(range((len(profile) - 1) * SEGMENTS, len(profile) * SEGMENTS)))
    mesh = bpy.data.meshes.new(name.title())
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    model = bpy.data.objects.new(name.title(), mesh)
    bpy.context.collection.objects.link(model)
    for face in mesh.polygons:
        face.use_smooth = True
    material = bpy.data.materials.new(name.title())
    material.diffuse_color = COLORS[name]
    model.data.materials.append(material)
    modifier = model.modifiers.new("Sculpt smoothing", "SUBSURF")
    modifier.levels = 1
    modifier.render_levels = 1
    return model


def export(model):
    evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    def axis(v):
        return (v.x, v.z, -v.y)
    coords = [axis(v.co) for v in mesh.vertices]
    lower = [min(v[i] for v in coords) for i in range(3)]
    upper = [max(v[i] for v in coords) for i in range(3)]
    points = [
        round(((v[i] - lower[i]) / (upper[i] - lower[i]) - .5) * 10000)
        for v in coords for i in range(3)
    ]
    normals = [round(axis(vertex.normal)[i] * 10000) for vertex in mesh.vertices for i in range(3)]
    triangles = [index + 1 for triangle in mesh.loop_triangles for index in triangle.vertices]
    assert 0 < len(coords) < 900 and 0 < len(triangles) // 3 < 1600
    evaluated.to_mesh_clear()
    return points, normals, triangles


def lua_array(name, values):
    rows = [", ".join(str(v) for v in values[i:i + 24]) for i in range(0, len(values), 24)]
    return f"\t\t{name} = {{\n" + "".join(f"\t\t\t{row},\n" for row in rows) + "\t\t},\n"


export_only = "--" in sys.argv and "--export" in sys.argv[sys.argv.index("--") + 1:]
if export_only:
    parts = {name: bpy.context.scene.objects[name.title()] for name in PROFILES}
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = {name: build(name, profile) for name, profile in PROFILES.items()}
    for i, model in enumerate(parts.values()):
        model.location = ((i % 4 - 1.5) * 1.50, (i // 4) * 1.5, 0)

lines = ["--!strict\n-- Generated by scripts/make-pawn-meshes.py in Blender.\nreturn table.freeze({\n"]
for name, model in parts.items():
    points, normals, triangles = export(model)
    print(f"{name}: {len(points) // 3} vertices, {len(triangles) // 3} triangles")
    lines.append(f"\t{name} = {{\n")
    lines.extend(lua_array(key, numbers) for key, numbers in (("points", points), ("normals", normals), ("triangles", triangles)))
    lines.append("\t},\n")
lines.append("})\n")
(ROOT / "src/client/PawnMeshData.luau").write_text("".join(lines))
if not export_only:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/pawn-shapes.blend"), compress=True)
