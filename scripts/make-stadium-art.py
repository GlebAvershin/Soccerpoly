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
    "cup", "ball", "academy", "arena", "curls", "sweep", "cap", "crest", "die", "chance", "champions",
    "tile_case", "tile_enamel", "fade", "arena_plinth", "night_stand", "pitch_mark", "braid", "quiff", "event_card",
    "club_flag", "megastadium",
)
INK, NAVY, SLATE = "23334A", "254671", "3C6BA1"
TEAL, MINT, GOLD = "2679BB", "76CFE2", "EAB561"
PAPER, STEEL, WHITE = "FFF6E3", "849EB7", "FFFFFF"
GRASS, DARK_GRASS = "448E63", "317350"
LIME, GLASS, PLINTH_DARK = "B8F76C", "63B8E8", "1B1D30"


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
    # Sculpted European stadium truss floodlight pylon with angled twin light banks.
    block((0, .24, 0), (2.25, .48, 2.25), "1E2036", .14, 2)
    block((0, .56, 0), (1.72, .22, 1.72), "373658", .08, 2)
    for x, z in product((-.62, .62), (-.62, .62)):
        pipe((x, .45, z), (x * .56, 9.75, z * .56), .12, STEEL, 8)
    for y in range(1, 9, 2):
        t0, t1 = y / 9.75, (y + 2) / 9.75
        r0, r1 = .60 * (1 - .42 * t0), .60 * (1 - .42 * t1)
        for side in (-1, 1):
            pipe((-r0, y, side * r0), (r1, y + 2, side * r1), .068, STEEL)
            pipe((r0, y, side * r0), (-r1, y + 2, side * r1), .058, NAVY)
            pipe((side * r0, y, r0), (side * r1, y + 2, -r1), .068, STEEL)
            pipe((-r1, y + 2, side * r1), (r1, y + 2, side * r1), .07, "4A4972")
    # Maintenance platform and structural neck
    block((0, 9.65, .18), (4.6, .22, 1.35), "292B45", .07, 2)
    block((0, 9.90, -.32), (1.25, .65, .85), SLATE, .09, 2)
    # Angled twin floodlight bank housing
    head = block((0, 10.65, .12), (6.10, 1.95, .74), PLINTH_DARK, .22, 2)
    head.rotation_euler.x = radians(16)
    bezel = block((0, 10.62, .45), (5.72, 1.58, .18), STEEL, .06)
    bezel.rotation_euler.x = radians(16)
    # Bright twin-row stadium LED projectors
    for row_idx, y_off in enumerate((-.38, .38)):
        for col in range(-3, 4):
            lamp = block((col * .76, 10.62 + y_off, .54 - y_off * .28), (.58, .50, .14), WHITE, .045)
            lamp.rotation_euler.x = radians(16)
    # Top lime accent bar
    crest_bar = block((0, 11.62, -.12), (5.45, .14, .18), LIME, .04)
    crest_bar.rotation_euler.x = radians(16)


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


def club_flag():
    # Level 0: Owned club plinth with mini manicured pitch seal and sculpted waving pennant.
    block((0, .14, 0), (2.40, .28, 2.00), PLINTH_DARK, .10, 2)
    block((0, .29, 0), (2.12, .06, 1.72), GOLD, .025)
    block((0, .34, 0), (1.84, .06, 1.42), GRASS, .02)
    block((0, .375, 0), (1.70, .02, .08), PAPER, .008)
    # Metallic flagpole + finial
    loft([(.34, .22), (.42, .18), (.46, .10)], STEEL, 16)
    pipe((-.42, .36, -.28), (-.42, 2.15, -.28), .068, PAPER, 10)
    ellipsoid((-.42, 2.22, -.28), (.20, .20, .20), GOLD)
    # Waving 3D club pennant (5 curved vertical panels)
    for i in range(5):
        t0, t1 = i / 5, (i + 1) / 5
        x0, x1 = -.36 + t0 * 1.18, -.36 + t1 * 1.18
        z0, z1 = -.28 + .11 * sin(t0 * pi * 1.6), -.28 + .11 * sin(t1 * pi * 1.6)
        h0, h1 = .64 * (1 - .38 * t0), .64 * (1 - .38 * t1)
        cy = 1.74 - .03 * sin(t0 * pi)
        tint = LIME if i % 2 == 0 else PAPER
        pts = [
            blender((x0, cy - h0 * .5, z0 - .035)), blender((x1, cy - h1 * .5, z1 - .035)),
            blender((x1, cy + h1 * .5, z1 - .035)), blender((x0, cy + h0 * .5, z0 - .035)),
            blender((x0, cy - h0 * .5, z0 + .035)), blender((x1, cy - h1 * .5, z1 + .035)),
            blender((x1, cy + h1 * .5, z1 + .035)), blender((x0, cy + h0 * .5, z0 + .035)),
        ]
        fcs = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (2, 6, 7, 3), (0, 3, 7, 4), (1, 5, 6, 2)]
        from_faces(pts, fcs, tint, True)


def club_stadium(upgraded):
    # Level 1 (academy) and Level 2 (covered arena) with detailed stepped terraces and trusses.
    block((0, .18, 0), (3.40, .34, 2.75), PLINTH_DARK, .13, 2)
    block((0, .36, 0), (2.20, .12, 1.92), GRASS, .05)
    for i in (-1, 0, 1):
        block((0, .43, i * .58), (1.92, .035, .24), DARK_GRASS, .01)
    block((0, .45, 0), (1.96, .03, .07), PAPER, .01)
    # Mini goals inside the club stadium
    for z in (-.84, .84):
        block((0, .54, z), (.58, .18, .06), PAPER, .02)
    for sign in (-1, 1):
        # Stepped lower seating tiers
        block((sign * 1.24, .54, 0), (.74, .46, 2.30), "353658", .10, 2)
        block((sign * 1.12, .64, 0), (.24, .18, 2.10), MINT, .04)
        block((sign * 1.38, .80, 0), (.24, .20, 2.10), SLATE, .04)
        if not upgraded:
            # Level 1 Academy: training dugout & twin floodlight posts
            for z in (-.96, .96):
                pipe((sign * 1.48, .55, z), (sign * 1.48, 1.42, z), .05, STEEL)
                block((sign * 1.42, 1.45, z), (.22, .14, .26), WHITE, .03)
        else:
            # Level 2 Covered Arena: upper VIP glass band, sweeping cantilevered roof & gold crown
            block((sign * 1.44, 1.14, 0), (.30, .56, 2.34), GLASS, .06)
            for z in (-1.05, -.35, .35, 1.05):
                pipe((sign * 1.56, .62, z), (sign * 1.56, 1.54, z), .06, STEEL)
                pipe((sign * 1.56, 1.54, z), (sign * .82, 1.60, z), .055, PAPER)
            roof = block((sign * 1.22, 1.62, 0), (1.02, .20, 2.66), PAPER, .09, 2)
            roof.rotation_euler.y = radians(sign * 7)
            trim = block((sign * 1.02, 1.72, 0), (.72, .09, 2.34), GOLD, .04)
            trim.rotation_euler.y = radians(sign * 7)
            block((sign * .86, 1.50, 0), (.10, .09, 2.48), LIME, .02)


def megastadium():
    # Level 3 Flagship Champions Bowl: 4-sided enclosed modern European stadium with 4 light pylons.
    block((0, .20, 0), (3.85, .38, 3.25), PLINTH_DARK, .16, 2)
    block((0, .40, 0), (2.25, .12, 1.78), GRASS, .05)
    for i in (-1, 0, 1):
        block((0, .47, i * .54), (2.05, .03, .22), DARK_GRASS, .01)
    block((0, .49, 0), (2.08, .03, .065), PAPER, .01)
    # 4-sided enclosed bowl facade (double-tier seating + glass ring + aerodynamic roof ring)
    for sign in (-1, 1):
        # Long sides (East/West)
        block((sign * 1.44, .76, 0), (.78, .82, 2.74), "34355B", .11, 2)
        block((sign * 1.22, .86, 0), (.24, .18, 2.36), MINT, .04)
        block((sign * 1.48, 1.08, 0), (.24, .22, 2.44), GLASS, .04)
        block((sign * 1.56, 1.38, 0), (.38, .44, 2.84), "282A46", .08, 2)
        roof_s = block((sign * 1.32, 1.82, 0), (1.08, .22, 3.06), PAPER, .10, 2)
        roof_s.rotation_euler.y = radians(sign * 8)
        block((sign * .88, 1.72, 0), (.10, .10, 2.50), LIME, .02)
        # End stands (North/South)
        block((0, .74, sign * 1.22), (2.48, .78, .66), "34355B", .10, 2)
        block((0, .86, sign * 1.02), (2.10, .18, .22), GOLD, .04)
        block((0, 1.28, sign * 1.32), (2.56, .42, .42), GLASS, .07)
        roof_e = block((0, 1.74, sign * 1.12), (2.78, .20, .88), PAPER, .09, 2)
        roof_e.rotation_euler.x = radians(-sign * 8)
        block((0, 1.66, sign * .76), (2.10, .09, .10), LIME, .02)
    # Golden architectural crown arches over the long stands
    for sign in (-1, 1):
        pipe((sign * 1.36, 1.94, -1.25), (sign * 1.36, 2.26, 0), .085, GOLD, 8)
        pipe((sign * 1.36, 2.26, 0), (sign * 1.36, 1.94, 1.25), .085, GOLD, 8)
    # Four corner Champions League floodlight pylons
    for sx, sz in product((-1, 1), (-1, 1)):
        pipe((sx * 1.68, .38, sz * 1.38), (sx * 1.56, 2.46, sz * 1.26), .075, STEEL, 8)
        head = block((sx * 1.48, 2.54, sz * 1.18), (.42, .26, .42), WHITE, .06)
        head.rotation_euler.z = atan2(-sz, -sx)


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
    octagonal_layer(70.2, 10.6, 0, .62, "141523")
    octagonal_layer(72.0, 12.5, .62, 2.66, "23243E")
    octagonal_layer(72.35, 12.8, 2.66, 3.04, "B8F76C")
    octagonal_layer(71.85, 12.3, 3.04, 3.84, "3A3B5E")
    octagonal_layer(70.9, 10.2, 3.84, 4.14, "16192B")


def night_stand():
    # Double-deck European arena grandstand with VIP glass box tier & steel cantilevered roof.
    block((0, .38, 0), (20.4, .76, 7.2), "1D1E34", .16, 2)
    # Front concrete fascia with glowing accent stripe
    block((0, .86, -3.32), (20.0, .44, .32), "35365A", .07)
    block((0, .92, -3.50), (19.4, .11, .08), GOLD, .025)
    # Lower seating deck (3 stepped rows)
    for row in range(3):
        y, z = .92 + row * .52, -2.55 + row * 1.18
        block((0, y * .5, z), (19.8, y, 1.24), "343458", .05)
        for seat in range(-6, 7):
            tint = "9483D4" if (seat - row * 2) % 5 == 0 else ("676296" if (seat + row) % 2 == 0 else "4D4A76")
            block((seat * 1.44, y + .11, z), (1.16, .16, .68), tint, .05)
            block((seat * 1.44, y + .30, z + .30), (1.16, .42, .16), tint, .045)
    # Mid-tier VIP Glass Box Skybox band
    block((0, 2.55, 1.35), (19.8, .92, 1.55), "242640", .08)
    block((0, 2.58, .54), (19.0, .62, .16), GLASS, .03)
    for mullion in range(-6, 7, 2):
        block((mullion * 1.50, 2.58, .48), (.16, .68, .22), STEEL, .02)
    # Upper seating deck (2 high rows)
    for row in range(2):
        y, z = 3.18 + row * .54, 1.32 + row * 1.16
        block((0, y, z), (19.8, .38, 1.18), "3F3E68", .05)
        for seat in range(-6, 7):
            tint = "A595E4" if (seat + row) % 4 == 0 else "5E598C"
            block((seat * 1.44, y + .24, z), (1.16, .24, .64), tint, .045)
    # Structural roof columns & cantilevered rafters
    for x in (-8.9, -3.0, 3.0, 8.9):
        pipe((x, 1.95, 3.05), (x, 5.15, 3.05), .14, STEEL, 8)
        pipe((x, 4.95, 3.05), (x, 4.72, -2.55), .10, "878DB0", 6)
        pipe((x, 3.65, 3.05), (x, 4.82, .60), .08, "6D7396", 6)
    # Sleek aerodynamic canopy roof + inner lime LED strip
    canopy = block((0, 5.02, .28), (20.8, .34, 6.2), "282848", .15, 2)
    canopy.rotation_euler.x = radians(6)
    block((0, 5.18, .28), (19.8, .12, 4.8), "3C3C66", .06)
    block((0, 4.58, -2.74), (19.8, .15, .16), LIME, .04)


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



def ticket_shell(height, corner, radius, inset):
    # The game board tiles have clipped shoulders and a shallow polished edge.
    x, z = 6, 8.4
    outline = [(-x + corner, -z), (x - corner, -z), (x, -z + corner),
               (x, z - corner), (x - corner, z), (-x + corner, z),
               (-x, z - corner), (-x, -z + corner)]
    points = [
        blender((px * scale, y, pz * scale))
        for y, scale in [(-height / 2, 1 - inset), (-height * .20, 1), (height / 2, 1 - inset * .70)]
        for px, pz in outline
    ]
    faces = [tuple(range(8)), tuple(reversed(range(16, 24)))]
    for ring in range(2):
        for i in range(8):
            a, b = ring * 8 + i, ring * 8 + (i + 1) % 8
            faces.append((b, a, a + 8, b + 8))
    return bevel(from_faces(points, faces, None), radius, 3)


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = (
        table_shell, lambda: block((0, 0, 0), (15.9, .42, 15.9), radius=.20, segments=3),
        seating, tunnel, dugout, goal, lights, trophy, soccer_ball,
        lambda: club_stadium(False), lambda: club_stadium(True),
        lambda: hair("curls"), lambda: hair("sweep"), lambda: hair("cap"), club_crest,
        lambda: block((0, 0, 0), (1, 1, 1), radius=.13, segments=5),
        chance_wheel, champions_arena,
        lambda: ticket_shell(.64, .71, .12, .024),
        lambda: ticket_shell(.37, .68, .065, .013),
        lambda: hair("fade"), arena_plinth, night_stand, pitch_mark, braided_hair, swept_quiff, event_card,
        club_flag, megastadium,
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
        obj.asset_data.description = f"Soccerpoly Continental Cup / {obj.name}"
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
export_fbx = "--" in sys.argv and "--fbx" in sys.argv[sys.argv.index("--") + 1:]
if export_only:
    models = [bpy.context.scene.objects[name] for name in NAMES]
else:
    models = build_scene()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"), compress=True)
export_shapes(models, "src/client/StadiumMeshData.luau")
if export_fbx:
    fbx_dir = ROOT / "art/fbx"
    fbx_dir.mkdir(parents=True, exist_ok=True)
    fbx_targets = ("club_flag", "academy", "arena", "megastadium", "night_stand", "lights", "arena_plinth", "cup", "ball")
    for obj in models:
        if obj.name not in fbx_targets:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        saved_loc = obj.location.copy()
        obj.location = (0, 0, 0)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(
            filepath=str(fbx_dir / f"{obj.name}.fbx"),
            use_selection=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_ALL",
            mesh_smooth_type="FACE",
        )
        obj.location = saved_loc
    print(f"Exported {len(fbx_targets)} FBX assets to art/fbx/")
