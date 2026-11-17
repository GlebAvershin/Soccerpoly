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
    "cup", "ball", "academy", "arena", "curls", "sweep", "cap", "crest", "die", "chance", "champions", "tile_case", "tile_enamel", "fade", "arena_plinth", "night_stand", "pitch_mark", "braid", "quiff", "event_card",
)
INK, NAVY, SLATE = "23334A", "254671", "3C6BA1"
TEAL, MINT, GOLD = "2679BB", "76CFE2", "EAB561"
PAPER, STEEL, WHITE = "FFF6E3", "849EB7", "FFFFFF"
GRASS, DARK_GRASS = "7FAF3A", "669733"


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
    block((0, -1.40, 0), (125.2, .43, 125.2), "704E3B", .19, 2)
    block((0, -.97, 0), (127, .72, 127), "A07150", .25, 3)
    block((0, -.55, 0), (127.2, .13, 127.2), "F2C777", .055, 2)
    block((0, .075, 0), (127.5, 1.12, 127.5), "D2A575", .49, 3)
    block((0, .67, 0), (122.10, .12, 122.10), "4B614D", .05, 2)
    for x, z in product((-61, 61), (-61, 61)):
        block((x, .735, z), (2.8, .045, 2.8), GOLD, .019)
    for side in (-1, 1):
        for i in range(-4, 5):
            block((i * 12.42, -.16, side * 63.61), (10.8, .048, .078), "B7865C", .020)
            block((side * 63.61, -.16, 12.42 * i), (.078, .048, 10.8), "B7865C", .020)
        block((0, -.08, side * 63.67), (11.32, .51, .13), "775338", .075, 2)
        block((side * 63.67, -.08, 0), (.13, .51, 11.32), "775338", .075, 2)


def club_crest():
    shape = [(-.50, -.45), (.50, -.45), (.46, .12), (.30, .36),
             (0, .53), (-.30, .36), (-.46, .12)]
    vertices = [blender((x, y, z)) for y in (-.10, .10) for x, z in shape]
    n = len(shape)
    faces = [tuple(range(n)), tuple(reversed(range(n, n * 2)))]
    faces.extend((j, j+n, (j+1) % n+n, (j+1) % n) for j in range(n))
    return bevel(from_faces(vertices, faces, None), .08, 3)


def seating():
    block((0, .27, 0), (8.65, .52, 7.65), INK, .14, 2)
    for row in range(4):
        y, z = .47 + row * .45, -2.53 + row * 1.37
        block((0, (y + .52) / 2, z), (8.43, max(.2, y - .1), 1.44), "CBD5D8", .045)
        block((0, y, z), (8.40, .14, 1.43), PAPER, .065)
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
    for side in (-1, 1):
        block((side * 3.22, 2.63, 2.16), (.23, 1.32, .29), NAVY, .065)
    block((0, 3.17, 2.18), (8.4, .31, 1.62), PAPER, .13, 2)
    block((0, 3.12, 1.43), (8.2, .21, .18), NAVY, .065)
    block((0, 3.35, 2.39), (6.4, .07, .18), GOLD, .028)


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
    if style == "fade":
        ellipsoid((0, -.085, -.08), (.98, .50, .98), None)
        ellipsoid((0, .03, -.09), (.90, .42, .90), None)
        for i in range(6):
            x = (i - 2.5) * .128
            ellipsoid((x, .145 - abs(x) * .24, .095 - abs(x) * .23),
                      (.255, .21, .57), None, -.14)
        return
    if style == "curls":
        ellipsoid((0, -.06, -.12), (.98, .44, .89), None)
        for row, z in enumerate((-.36, -.06, .24, .40)):
            for column in range(5):
                x = (column - 2) * .196 + (.065 if row % 2 else 0)
                crown_height = .18 - .39 * (abs(x) ** 1.65) - .21 * abs(z)
                ellipsoid((x, crown_height, z - abs(x) * .16),
                          (.27, .22 + .034 * sin(column * 2.1 + row), .29), None, .18 * sin(column))
        return
    ellipsoid((0, .018, -.11), (1.0, .54, 1.0), None)
    for i in range(7):
        x = (i - 3) * .122
        ellipsoid((x, .08 - i * .024, .25 - abs(x) * .42),
                  (.30 - i * .009, .24 - i * .014, .57 - i * .039), None, .48)


def chance_wheel():
    colors = ("EF3273", "F4C535", "70B643", "14A5DA", "D74793", "F4D95E")
    loft(((0, 1.02), (.06, 1.02), (.10, .98)), PAPER, 48)
    for i in range(12):
        a, b = (tau * i / 12, tau * (i + 1) / 12)
        outer = [a + (b - a) * j / 4 for j in range(5)]
        points = [(0, .109, 0), *[(.96 * cos(angle), .109, .96 * sin(angle)) for angle in outer]]
        from_faces([blender(point) for point in points], [tuple(reversed(range(len(points))))], colors[i % len(colors)])
    loft(((.109, .23), (.133, .23), (.16, .18)), "D1C4CC", 24)


def champions_arena():
    loft(((0, 1.02), (.16, 1.04), (.21, 1.04)), "E4D9DF", 36)
    loft(((.21, .66), (.24, .66)), "92AB46", 36)
    for i in range(12):
        angle = i * tau / 12
        at = cos(angle) * .83, sin(angle) * .83
        tier = .66 if i in (4, 5, 6, 7, 8) else .46
        wall = block((at[0], (tier + .15) / 2, at[1]), (.45, tier - .11, .30), PAPER, .036, 2)
        trim = block((at[0], tier, at[1]), (.42, .115, .31), "AC7194" if tier > .5 else "C5B9C7", .04, 2)
        wall.rotation_euler.z = trim.rotation_euler.z = pi / 2 - angle


def octagonal_layer(half, cut, floor, ceiling, color):
    outline = [(half - cut, half), (-half + cut, half), (-half, half - cut),
               (-half, -half + cut), (-half + cut, -half), (half - cut, -half),
               (half, -half + cut), (half, half - cut)]
    points = [blender((x, y, z)) for y in (floor, ceiling) for x, z in outline]
    faces = [tuple(range(8)), tuple(reversed(range(8, 16)))]
    faces.extend((i + 8, (i + 1) % 8 + 8, (i + 1) % 8, i) for i in range(8))
    bevel(from_faces(points, faces, color), .16, 2)


def arena_plinth():
    octagonal_layer(70, 10.5, 0, .54, "171624")
    octagonal_layer(72, 12.5, .54, 2.76, "262441")
    octagonal_layer(72.15, 12.7, 2.76, 3.03, "ACF24B")
    octagonal_layer(71.75, 12.3, 3.03, 3.83, "403F62")
    octagonal_layer(70.8, 10.1, 3.83, 4.12, "171A2B")


def night_stand():
    block((0, .35, 0), (20, .70, 6.8), "22223A", .15, 2)
    for row in range(4):
        y, z = .91 + row * .55, -2.48 + row * 1.37
        block((0, y * .5, z), (19.6, y, 1.40), "3C385E", .06)
        for seat in range(-5, 6):
            tint = "8571BD" if (seat - row * 2) % 7 in (0, 1) else "56527B"
            block((seat * 1.62, y + .09, z), (1.29, .16, .73), tint, .055)
            block((seat * 1.62, y + .27, z + .34), (1.29, .43, .16), tint, .05)
    for x in (-8.7, 8.7):
        pipe((x, 1.8, 2.6), (x, 4.75, 2.6), .13, "6A6688")
        pipe((x, 3.4, 2.6), (x, 4.46, -2.3), .085, "6A6688")
    canopy = block((0, 4.59, .18), (20.5, .36, 5.5), "2C2847", .15, 2)
    canopy.rotation_euler.x = radians(7)
    block((0, 4.22, -2.58), (19.3, .13, .14), "B8F76C", .04)


def pitch_mark():
    # A split-F pitch stencil made from flat parallelograms.
    for x, z, width, depth in ((-1.33, 0, .62, 3.5), (-.02, 1.43, 2.62, .62), (-.34, .06, 1.91, .58),
                              (1.47, 1.43, .36, .62)):
        points = [blender((x + dx * width * .5 + dz * depth * .20, .05, z + dz * depth * .5))
                  for dx, dz in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
        from_faces(points, [(0, 1, 2, 3)], None)
    # Give normalized export a shallow thickness while keeping it a field decal.
    block((-1.33, 0, 0), (.28, .09, .28))



def braided_hair():
    for row in range(8):
        y = (row - 3.5) * .187
        offset = .042 * sin(row * .75)
        for side in (-1, 1):
            ellipsoid((offset + side * .072, y, side * .032),
                      (.32 - row * .012, .27 - row * .009, .29 - row * .009), None, side * .31)


def swept_quiff():
    ellipsoid((0, .020, -.08), (1.02, .56, .98), None)
    for strand in range(7):
        x = (strand - 3) * .108
        ellipsoid((x, .06 + .027 * strand, .14 - abs(x) * .27),
                  (.32, .24 + .016 * strand, .56 - strand * .019), None, -.49)


def event_card():
    for layer in range(3):
        card = block((0, layer * .15, 0), (3.2, .16, 4.4),
                     ("383550", "555184", "9C79E6")[layer], .11, 3)
        card.rotation_euler.z = radians(14 - layer * 13)
    for x in (-.24, .24):
        glyph = block((x, .405, 0), (.18, .04, 1.36), "ECE1FF", .017, 2)
        glyph.rotation_euler.z = radians(25)



def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = (
        table_shell, lambda: block((0, 0, 0), (15.9, .42, 15.9), radius=.20, segments=3),
        seating, tunnel, dugout, goal, lights, trophy, soccer_ball,
        lambda: club_stadium(False), lambda: club_stadium(True),
        lambda: hair("curls"), lambda: hair("sweep"), lambda: hair("cap"), club_crest,
        lambda: block((0, 0, 0), (1, 1, 1), radius=.13, segments=5),
        chance_wheel, champions_arena,
        lambda: block((0, 0, 0), (12, .60, 14), radius=.27, segments=4),
        lambda: block((0, 0, 0), (12, .32, 14), radius=.145, segments=4),
        lambda: hair("fade"), arena_plinth, night_stand, pitch_mark, braided_hair, swept_quiff, event_card,
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
