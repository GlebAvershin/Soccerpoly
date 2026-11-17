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
SEGMENTS = 16

# Height, width radius, depth radius and forward offset in the Roblox orientation.
PROFILES = {
    "head": (
        (-.53, .17, .23, .048), (-.48, .26, .35, .035), (-.39, .38, .43, .050),
        (-.27, .47, .48, .030), (-.15, .53, .51, .022), (-.04, .56, .51, .012),
        (.08, .55, .49, .005), (.19, .54, .49, -.014), (.30, .51, .46, -.027),
        (.39, .45, .40, -.042), (.48, .33, .30, -.056), (.54, .13, .13, -.055),
    ),
    "jersey": (
        (-.52, .34, .33, -.02), (-.48, .38, .38, -.02), (-.36, .395, .385, -.018),
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
    "ear": (
        (-.52, .13, .14, -.05), (-.43, .33, .29, -.04), (-.19, .47, .39, -.03),
        (.06, .53, .48, .035), (.30, .50, .46, .08), (.49, .29, .28, .07), (.54, .11, .10, .05),
    ),
    "outsole": (
        (-.52, .40, .32, .095), (-.47, .51, .48, .035), (-.20, .56, .56, .015),
        (.21, .56, .56, .015), (.47, .51, .51, .025), (.52, .45, .43, .045),
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
    "shorts": (.064, .13, .12, 1), "sleeve": (.15, .52, .72, 1), "boot": (.05, .08, .076, 1), "ear": (.41, .24, .14, 1), "outsole": (.12, .13, .16, 1),
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
                z += .165 * math.exp(-((x / .112) ** 2) - (((height + .069) / .097) ** 2))
                z += .062 * math.exp(-((x / .096) ** 2) - (((height - .02) / .18) ** 2))
                cheek = abs(x) - .31
                z += .063 * math.exp(-((cheek / .17) ** 2) - (((height + .145) / .113) ** 2))
                z -= .059 * math.exp(-((cheek / .14) ** 2) - (((height - .090) / .081) ** 2))
                z += .047 * math.exp(-((cheek / .23) ** 2) - (((height - .21) / .06) ** 2))
                z += .035 * math.exp(-((x / .21) ** 2) - (((height + .29) / .104) ** 2))
                # Plane changes at the jaw and cheek are visible under the stadium rim light.
                jaw = max(0, min(1, (-height - .19) * 3.0))
                x *= 1.0 - .13 * jaw
                z += .032 * math.exp(-(((abs(x) - .35) / .11) ** 2) - (((height + .08) / .14) ** 2))
            if name == "jersey" and math.cos(angle) > 0:
                hem = math.exp(-((height + .32 + x * .54) / .18) ** 2)
                z += .038 * math.cos((x + height * .57) * 26) * hem
                z += .058 * math.exp(-((height - .18) / .27) ** 2) * math.cos(angle)
                z -= .045 * math.exp(-((x / .12) ** 2) - (((height - .22) / .24) ** 2))
                x *= .91 + .12 * math.exp(-((height - .30) / .24) ** 2)
            if name == "glove" and math.cos(angle) > 0:
                z += .07 * math.exp(-((height + .21) / .18) ** 2) * math.cos(x * 24) ** 2
                z += .09 * math.exp(-((x + .39) / .14) ** 2 - ((height + .04) / .24) ** 2)
            if name == "ear" and math.cos(angle) > 0:
                z -= .24 * math.exp(-((x / .24) ** 2) - (((height - .09) / .28) ** 2))
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


def accent_mesh(name, outlines, color):
    """Form painted raised details with closed geometry and soft edges."""
    points, faces = [], []
    for outline in outlines:
        start = len(points)
        count = len(outline)
        for depth in (-.035, .035):
            points.extend((x, -z - depth, y) for x, y, z in outline)
        faces.extend((tuple(range(start + count - 1, start - 1, -1)),
                      tuple(range(start + count, start + 2 * count))))
        for edge in range(count):
            a, b = start + edge, start + (edge + 1) % count
            faces.append((a, b, b + count, a + count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    model = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(model)
    material = bpy.data.materials.new(name + " enamel")
    material.diffuse_color = color
    mesh.materials.append(material)
    bevel = model.modifiers.new("Tool radius", "BEVEL")
    bevel.width, bevel.segments = .021, 2
    return model


def geometric_parts():
    v_collar = [(-.62, .50, -.17), (-.42, .54, -.02), (0, -.50, .48), (.42, .54, -.02),
                (.62, .50, -.17), (.38, .20, .19), (0, -.71, .53), (-.38, .20, .19)]
    keeper_padding = [
        [(-.48, .42, 0), (-.12, .55, .15), (.36, .31, .18), (.49, -.14, .06),
         (.22, -.52, .12), (-.38, -.37, -.04)],
    ]
    boot_panel = [(-.55, -.08, -.17), (-.22, .68, .12), (.53, .26, .13),
                  (.38, -.15, .29), (-.44, -.52, -.10)]
    smile = [(-.52, .20, -.10), (-.24, .01, .04), (.11, .005, .075), (.51, .34, -.10),
             (.37, -.24, .02), (.09, -.49, .09), (-.23, -.40, .04)]
    return {
        "collar": accent_mesh("Collar", [v_collar], (.92, .96, .90, 1)),
        "glovepad": accent_mesh("Glovepad", keeper_padding, (.70, .94, .21, 1)),
        "bootpanel": accent_mesh("Bootpanel", [boot_panel], (.70, .94, .21, 1)),
        "smile": accent_mesh("Smile", [smile], (.22, .12, .11, 1)),
    }


def sculpt_hand(side):
    """Fuse the palm, folded fingers and thumb into a single articulated hand."""
    from mathutils import Euler
    name = "Hand_Left" if side < 0 else "Hand_Right"
    pieces = []

    def volume(x, y, z, size, angles=(0, 0, 0)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, location=(x * side, -z, y))
        piece = bpy.context.object
        piece.scale = (size[0], size[2], size[1])
        piece.rotation_euler = Euler((angles[0], angles[1] * side, angles[2] * side))
        pieces.append(piece)

    # Wrist blends into the forearm. Four knuckles wrap around a relaxed palm.
    volume(0, .275, -.005, (.258, .318, .230))
    volume(.025, -.015, .025, (.369, .351, .272))
    for i, length in enumerate((.161, .198, .190, .144)):
        x = -.205 + i * .164
        volume(x, -.268 + abs(i - 1.5) * .040, .101, (.128, length, .151), (-.26, 0, 0))
        volume(x, -.127, .210, (.115, .114, .161), (-.33, 0, 0))
    volume(-.292, .063, .077, (.165, .245, .175), (-.19, -.31, -.22))
    volume(-.330, -.101, .207, (.132, .165, .153), (.26, -.40, -.24))
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    model = pieces[0]
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    model.name = name
    remesh = model.modifiers.new("Sculpt union", "REMESH")
    remesh.mode, remesh.voxel_size, remesh.use_smooth_shade = "VOXEL", .037, True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = model.modifiers.new("Soft knuckle contours", "SMOOTH")
    smooth.factor, smooth.iterations = .42, 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    simplify = model.modifiers.new("Game mesh", "DECIMATE")
    simplify.ratio = min(1, 1020 / (len(model.data.polygons) * 2))
    bpy.ops.object.modifier_apply(modifier=simplify.name)
    for face in model.data.polygons:
        face.use_smooth = True
    material = bpy.data.materials.get("Palm resin") or bpy.data.materials.new("Palm resin")
    material.diffuse_color = (.47, .28, .19, 1)
    model.data.materials.append(material)
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
detail_names = ("collar", "glovepad", "bootpanel", "smile", "hand_left", "hand_right")
if export_only:
    parts = {name: bpy.context.scene.objects[name.title()] for name in (*PROFILES, *detail_names)}
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = {name: build(name, profile) for name, profile in PROFILES.items()}
    parts.update(geometric_parts())
    parts["hand_left"], parts["hand_right"] = sculpt_hand(-1), sculpt_hand(1)
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
