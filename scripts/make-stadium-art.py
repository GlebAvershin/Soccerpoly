"""Build the Continental Cup asset kit and export it to Roblox.

To export an edited scene, open art/stadium-kit.blend in background mode and
pass -- --export. Running without that option regenerates the source scene.
"""
from itertools import product
from math import atan2, cos, pi, radians, sin, tau
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, blender, export_shapes

NAMES = (
    "table", "enamel", "stand", "tunnel", "dugout", "goal", "lights",
    "cup", "ball", "academy", "arena", "curls", "sweep", "cap",
)
INK, NAVY, SLATE = "11232D", "19323D", "2E5361"
TEAL, MINT, GOLD = "268F83", "89D5C2", "F5BE62"
PAPER, STEEL, WHITE = "E6F1DF", "537887", "FFFFFF"
GRASS, DARK_GRASS = "278B52", "217748"


def paint(obj, color, smooth=False):
    if color:
        mat = bpy.data.materials.get(color)
        if not mat:
            mat = bpy.data.materials.new(color)
            mat.diffuse_color = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1,)
        obj.data.materials.append(mat)
    if smooth:
        for face in obj.data.polygons:
            face.use_smooth = True
    return obj


def bevel(obj, width, segments):
    if width:
        modifier = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        modifier.width, modifier.segments = width, segments
        modifier = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
    return obj


def block(pos, size, color=None, radius=.0, segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1, location=blender(pos))
    obj = bpy.context.object
    width, height, depth = size
    obj.scale = width, depth, height
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return bevel(paint(obj, color), radius, segments)


def pipe(a, b, radius, color, sides=6):
    start, end = blender(a), blender(b)
    delta = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=delta.length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    paint(obj, color)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return obj


def loft(profile, color, segments=32):
    points = [blender((radius * cos(i * tau / segments), y, radius * sin(i * tau / segments)))
              for y, radius in profile for i in range(segments)]
    faces = [tuple(range(segments))]
    for layer in range(len(profile) - 1):
        for i in range(segments):
            a = layer * segments + i
            b = layer * segments + (i + 1) % segments
            faces.append((b, a, a + segments, b + segments))
    faces.append(tuple(range(len(points) - 1, len(points) - segments - 1, -1)))
    return from_faces(points, faces, color, True)


def from_faces(points, faces, color, smooth=False):
    mesh = bpy.data.meshes.new("Geometry")
    mesh.from_pydata(points, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Piece", mesh)
    bpy.context.collection.objects.link(obj)
    return paint(obj, color, smooth)


def ellipsoid(pos, size, color, scale_twist=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=.5, location=blender(pos))
    obj = bpy.context.object
    obj.scale = size[0], size[2], size[1]
    if scale_twist:
        obj.rotation_euler.z = scale_twist
    return paint(obj, color, True)


def table_shell():
    block((0, -1.26, 0), (125.2, .45, 83.5), INK, .21, 2)
    block((0, -.79, 0), (126.2, .75, 84), NAVY, .28, 3)
    block((0, -.38, 0), (126.8, .17, 84.45), GOLD, .06, 2)
    block((0, .18, 0), (127, .98, 84.5), SLATE, .46, 3)
    block((0, .67, 0), (123.6, .1, 81.2), INK, .045, 1)
    for x, z in product((-60, 60), (-39, 39)):
        block((x, .723, z), (3.8, .055, 2.55), STEEL, .023)
    for sign in (-1, 1):
        for i in range(-2, 3):
            block((i * 4.3, .16, sign * 42.20), (2.10, .23, .11), STEEL, .045)
            block((sign * 63.46, .16, 4.3 * i), (.11, .23, 2.10), STEEL, .045)


def seating():
    block((0, .27, 0), (8.65, .52, 7.65), INK, .14, 2)
    for row in range(4):
        y, z = .47 + row * .45, -2.53 + row * 1.37
        block((0, (y + .52) / 2, z), (8.43, max(.2, y - .1), 1.44), SLATE, .045)
        block((0, y, z), (8.40, .14, 1.43), STEEL, .065)
        for i in range(-2, 3):
            x = i * 1.52
            tint = MINT if row in (0, 2) and i in (-1, 0, 1) else TEAL
            block((x, y + .14, z + .02), (1.12, .18, .76), tint, .07)
            block((x, y + .36, z + .43), (1.12, .45, .19), tint, .075)
        block((-4.12, y + .1, z), (.40, .2, 1.36), PAPER, .05)
    for x in (-3.66, 3.66):
        pipe((x, 1.93, 2.63), (x, 2.72, 2.63), .05, STEEL)
        pipe((x, 2.55, .39), (x, 2.76, 2.74), .05, PAPER)
    block((0, 2.46, 2.82), (7.2, .45, .21), NAVY, .085)
    block((0, 2.47, 2.695), (5.9, .14, .06), MINT, .025)


def tunnel():
    block((0, .18, .01), (5.05, .25, 4.55), INK, .08)
    for sign in (-1, 1):
        block((sign * 1.92, .95, 0), (.66, 1.76, 4.15), SLATE, .18, 2)
        block((sign * 1.61, .95, -2.06), (.18, 1.70, .15), STEEL, .05)
    block((0, 1.94, -.04), (5.02, .44, 4.38), SLATE, .20, 3)
    block((0, 1.91, -2.17), (3.28, .12, .13), MINT, .045)
    for i in range(-2, 3):
        block((i * .50, .335, -.72), (.31, .09, 2.69), TEAL, .015)
    block((0, 1.03, 1.83), (4, 1.7, .22), NAVY, .075)


def dugout():
    block((0, .14, 0), (6.55, .23, 1.62), NAVY, .11)
    block((0, .61, .65), (6.3, 1, .23), STEEL, .10)
    block((0, 1.19, .04), (6.65, .27, 1.65), SLATE, .12, 2)
    block((0, 1.17, -.82), (6.10, .09, .06), TEAL, .023)
    for i in range(-2, 3):
        block((i * 1.15, .48, .02), (.87, .35, .61), PAPER, .085)
        block((i * 1.15, .76, .34), (.87, .42, .25), TEAL, .08)
    for x in (-3.08, 3.08):
        block((x, .66, -.54), (.26, 1.20, .27), STEEL, .09)
        block((x, .17, .70), (.53, .24, .38), INK, .045)


def goal():
    width, depth, height = 3.26, 2.85, 2.38
    for side in (-1, 1):
        z = width * side
        pipe((0, 0, z), (0, height, z), .12, PAPER, 10)
        pipe((0, 0, z), (depth, 0, z), .072, STEEL)
        pipe((0, height, z), (depth, .44, z), .062, PAPER)
    pipe((0, height, -width), (0, height, width), .12, PAPER, 10)
    pipe((depth, .08, -width), (depth, .08, width), .065, STEEL)
    for i in range(-6, 7):
        z = width * i / 6
        pipe((.055, height - .10, z), (depth, .42, z), .020, MINT, 4)
        pipe((depth, .42, z), (depth, .085, z), .020, MINT, 4)
    for row in range(1, 6):
        t = row / 5
        pipe((depth * t, height - .1 - (height - .52) * t, -width),
             (depth * t, height - .1 - (height - .52) * t, width), .024, MINT, 4)


def lights():
    for x, z in product((-.55, .55), (-.55, .55)):
        pipe((x, 0, z), (x * .7, 9.5, z * .7), .12, STEEL)
    for y in range(0, 9, 2):
        for side in (-1, 1):
            pipe((-.52, y, side * .53), (.52, y + 2, side * .53), .075, STEEL)
            pipe((side * .53, y, .53), (side * .53, y + 2, -.53), .075, STEEL)
            pipe((-.53, y + 2, side * .53), (.53, y + 2, side * .53), .07, NAVY)
    block((0, .18, 0), (1.75, .4, 1.8), NAVY, .12)
    block((0, 10.30, 0), (5.55, 1.42, .78), INK, .28, 2)
    block((0, 10.30, .385), (5.20, 1.08, .17), STEEL, .085)
    for x, y in product(range(-2, 3), (10.08, 10.53)):
        block((x * .90, y, .49), (.68, .33, .16), PAPER, .065)
    block((0, 9.56, 0), (.92, .66, .89), SLATE, .095)


def trophy():
    loft([(0, .39), (.04, .49), (.19, .49), (.26, .42), (.29, .32)], INK)
    loft([(.27, .27), (.32, .27), (.34, .13), (.61, .1), (.69, .24), (.72, .22)], GOLD)
    loft([(.63, .19), (.70, .19), (.74, .34), (.83, .49), (1.0, .57), (1.16, .61),
          (1.22, .64), (1.25, .61), (1.23, .54), (1.08, .50), (.91, .40), (.82, .28), (.75, .16)], GOLD)
    for side in (-1, 1):
        handle = bpy.data.curves.new("Cup handle", "CURVE")
        handle.dimensions, handle.resolution_u = "3D", 8
        handle.bevel_depth, handle.bevel_resolution = .06, 2
        handle.use_fill_caps = True
        spline = handle.splines.new("BEZIER")
        spline.bezier_points.add(3)
        for control, (x, y) in zip(spline.bezier_points, ((.59, 1.16), (.98, 1.10), (.87, .87), (.39, .81))):
            control.co = blender((side * x, y, 0))
            control.handle_left_type = control.handle_right_type = "AUTO"
        obj = bpy.data.objects.new("Cup handle", handle)
        bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
        paint(bpy.context.object, GOLD, True)
    block((0, .18, .471), (.34, .11, .065), GOLD, .025)


def soccer_ball():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    base = bpy.context.object
    vertices = [v.co.copy() for v in base.data.vertices]
    faces = [tuple(p.vertices) for p in base.data.polygons]
    bpy.data.objects.remove(base, do_unlink=True)
    for vertex_id, anchor in enumerate(vertices):
        neighbors = {i for tri in faces if vertex_id in tri for i in tri if i != vertex_id}
        first = (vertices[min(neighbors)] - anchor).normalized()
        up = anchor.cross(first).normalized()
        ordered = sorted(neighbors, key=lambda i: atan2((vertices[i] - anchor).dot(up), (vertices[i] - anchor).dot(first)))
        panel([(anchor * 2 + vertices[i]) / 3 for i in ordered], INK)
    for a, b, c in faces:
        edge = [(a, b), (b, a), (b, c), (c, b), (c, a), (a, c)]
        panel([(vertices[i] * 2 + vertices[j]) / 3 for i, j in edge], PAPER)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=.487)
    paint(bpy.context.object, STEEL, True)


def panel(corners, color):
    center = sum(corners, Vector()).normalized()
    border = [left.lerp(center * left.length, .028) for left in corners]
    ring = [p.normalized() * .501 for p in border]
    points = [center * .501]
    for i, left in enumerate(ring):
        points.extend((left, left.lerp(ring[(i + 1) % len(ring)], .5).normalized() * .501))
    faces = []
    for i in range(1, len(points)):
        j = 1 if i + 1 == len(points) else i + 1
        if (points[i] - points[0]).cross(points[j] - points[0]).dot(center) < 0:
            faces.append((0, j, i))
        else:
            faces.append((0, i, j))
    from_faces(points, faces, color, True)


def club_stadium(upgraded):
    block((0, .18, 0), (3.18, .32, 2.53), INK, .13, 2)
    block((0, .36, 0), (2.04, .12, 1.80), GRASS, .06)
    for i in (-1, 0, 1):
        block((0, .434, i * .55), (1.78, .035, .21), DARK_GRASS, .012)
    block((0, .453, 0), (1.85, .035, .075), PAPER, .012)
    for sign in (-1, 1):
        block((sign * 1.20, .57, 0), (.65, .55, 2.15), STEEL, .13, 2)
        block((sign * 1.03, .62, 0), (.25, .16, 1.97), MINT, .049)
        if upgraded:
            block((sign * 1.25, 1.07, 0), (.24, .70, 2.06), SLATE, .068)
            block((sign * 1.12, 1.36, 0), (.82, .25, 2.52), PAPER, .12, 2)
            block((sign * 1.02, 1.40, 0), (.64, .12, 2.05), GOLD, .056)
            for z in (-1.12, 1.12):
                block((sign * .88, .66, z), (.25, .54, .19), STEEL, .044)


def hair(style):
    if style == "cap":
        ellipsoid((0, 0, -.04), (1.0, .50, .91), None)
        ellipsoid((0, -.13, .31), (.88, .078, .74), None)
        return
    ellipsoid((0, -.045, -.07), (1.0, .43, 1.0), None)
    for i in range(7):
        x = (i - 3) * .122
        if style == "curls":
            ellipsoid((x, .07 + .068 * sin(i * 1.6), .23 - abs(x) * .16), (.31, .24, .36), None)
        else:
            ellipsoid((x, .08 - i * .024, .25 - abs(x) * .42), (.32, .22, .48 - i * .021), None, .39)


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = (
        table_shell, lambda: block((0, 0, 0), (15.9, .20, 9.95), radius=.095, segments=3),
        seating, tunnel, dugout, goal, lights, trophy, soccer_ball,
        lambda: club_stadium(False), lambda: club_stadium(True),
        lambda: hair("curls"), lambda: hair("sweep"), lambda: hair("cap"),
    )
    objects = []
    for name, build in zip(NAMES, builders):
        before = set(bpy.context.scene.objects)
        build()
        pieces = sorted(set(bpy.context.scene.objects) - before, key=lambda obj: obj.name)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in pieces:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            for modifier in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.context.view_layer.objects.active = pieces[0]
        if len(pieces) > 1:
            bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        asset = bpy.context.object
        asset.name = name
        objects.append(asset)
    objects[0].location.y = -46
    for i, obj in enumerate(objects[1:]):
        obj.location = ((i % 5 - 2) * 17, (i // 5) * 13 + 5, 0)
    for obj in objects:
        obj.asset_mark()
        obj.asset_data.description = f"Footbolapolia Continental Cup / {obj.name}"
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "MATERIAL"
                region = area.spaces.active.region_3d
                region.view_distance = 149
                region.view_location = (0, -20, 0)
                region.view_rotation = Euler((radians(32), 0, 0)).to_quaternion()
    return objects


export_only = "--" in sys.argv and "--export" in sys.argv[sys.argv.index("--") + 1:]
if export_only:
    models = [bpy.context.scene.objects[name] for name in NAMES]
else:
    models = build_scene()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"), compress=True)
export_shapes(models, "src/client/StadiumMeshData.luau")
