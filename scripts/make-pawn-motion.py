"""Create editable keyframed figure motion and sample it for the Luau rig."""
from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, blender, studio

def point(x, y, z):
    if y > 2.20:
        y = 2.865 + (y - 2.20) * 1.035
    elif y > .45:
        y = .45 + (y - .45) * 1.38
    return x * .87, y, z * .94


JOINTS = {name: point(*at) for name, at in {
    "Torso": (0, 2.18, 0), "Head": (0, 3.97, 0),
    "Left arm": (-.96, 3.45, 0), "Right arm": (.96, 3.45, 0),
    "Left leg": (-.43, 2.14, 0), "Right leg": (.43, 2.14, 0),
    "Left elbow": (-1.239, 3.00, .08), "Right elbow": (1.239, 3.00, .08),
    "Left knee": (-.43, 1.419, .014), "Right knee": (.43, 1.419, .014),
    "Left ankle": (-.43, .698, .014), "Right ankle": (.43, .698, .014),
}.items()}
PARENTS = {
    "Left elbow": "Left arm", "Right elbow": "Right arm",
    "Left knee": "Left leg", "Right knee": "Right leg",
    "Left ankle": "Left knee", "Right ankle": "Right knee",
}
HINGES = {
    "idle": {0: (-8, -6, 4, 7, -4, -7), .33: (-5, -13, 3, 6, -3, -6),
             .67: (-11, -4, 7, 4, -7, -4), 1: (-8, -6, 4, 7, -4, -7)},
    "stride": {0: (-54, -29, 17, 49, -17, -20), .25: (-35, -55, 52, 22, -17, -18),
               .50: (-28, -53, 47, 18, -22, -17), .75: (-57, -38, 24, 49, -16, -22),
               1: (-54, -29, 17, 49, -17, -20)},
    "cheer": {0: (0, 0, 0, 0, 0, 0), .18: (-16, -25, 25, 29, -21, -23),
              .40: (-42, -59, 12, 26, -8, -18), .63: (-48, -64, 8, 14, -8, -13),
              1: (0, 0, 0, 0, 0, 0)},
    "launch": {0: (0, 0, 0, 0, 0, 0), .60: (-32, -44, 23, 35, -17, -20),
               1: (-36, -35, 22, 24, -12, -10)},
    "land": {0: (-28, -22, 12, 20, -10, -11), .34: (-53, -19, 34, 19, -23, -13),
             .72: (-11, -10, 14, 5, -14, -5), 1: (0, 0, 0, 0, 0, 0)},
    "kick": {0: (-20, -24, 16, 28, -9, -9), .30: (-38, -42, 19, 69, -12, -13),
             .43: (-39, -48, 19, 89, -11, -16), .52: (-32, -48, 14, 15, -12, 4),
             .65: (-36, -41, 12, 29, -8, -12), .84: (-19, -31, 12, 36, -9, -14),
             1: (0, 0, 0, 0, 0, 0)},
    "save": {0: (-44, -44, 39, 39, -19, -19), .24: (-41, -52, 37, 25, -18, -20),
             .49: (-20, -14, 25, 39, -10, -19), .72: (-40, -42, 39, 42, -20, -22),
             1: (0, 0, 0, 0, 0, 0)},
}


def local_offset(name):
    return blender(JOINTS[name]) - (blender(JOINTS[PARENTS[name]]) if name in PARENTS else blender((0, 0, 0)))

RANGES = {
    "idle": (1, 25), "stride": (33, 57), "cheer": (65, 89),
    "launch": (97, 121), "land": (129, 153), "kick": (161, 185), "save": (193, 217),
}
BASIS = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
NEUTRAL = [(0, 0, 0)] * 6
# Each pose is articulated in the same 12 channels as the run and the shot.
CELEBRATIONS = {
    "messi": (
        [(3, -9, -6), (-4, 7, 2), (-41, -4, -19), (-52, 5, 14), (-12, 0, 4), (15, 0, -4)],
        [(-7, 7, 1), (-25, 2, -2), (-112, -21, -25), (-115, 18, 25), (8, 0, 5), (-6, 0, -3)],
        [(-3, 4, 0), (-17, 8, 1), (-104, -20, -21), (-109, 21, 27), (4, 0, 4), (-5, 0, -3)],
        (-39, -36, 18, 24, -10, -14), (-43, -47, 8, 12, -3, -5),
    ),
    "ronaldo": (
        [(17, 11, 6), (8, -9, -2), (-28, -12, -36), (-41, 10, 39), (-21, 0, -8), (-24, 0, 8)],
        [(-15, 36, -2), (-6, -25, 5), (-143, -24, -40), (-148, 19, 41), (-30, 4, 18), (-35, -7, -19)],
        [(2, -4, 2), (5, 5, -2), (10, 0, -57), (15, 0, 60), (-14, 4, 16), (-14, -5, -16)],
        (-66, -57, 64, 68, -20, -19), (-12, -15, 28, 26, -13, -11),
    ),
    "mbappe": (
        [(4, -10, -1), (1, 9, 3), (-52, 9, -13), (-61, -13, 14), (-9, 0, 5), (12, 0, -3)],
        [(-4, 8, 4), (-5, -7, -6), (-73, -13, -23), (-59, 15, 25), (5, 0, 4), (-8, 1, -5)],
        [(-6, 8, 4), (-5, -7, -6), (-72, -11, -20), (-56, 13, 24), (5, 0, 4), (-8, 1, -5)],
        (-79, -93, 9, 18, -10, -7), (-87, -97, 12, 14, -9, -7),
    ),
    "yamal": (
        [(8, -19, -10), (0, 14, 5), (-43, 3, -24), (-54, -3, 18), (-11, 0, 6), (19, 0, -7)],
        [(-4, 15, 8), (-6, -16, -5), (-55, -20, -18), (-151, 17, 23), (5, 0, 11), (-25, 0, -15)],
        [(2, -10, -7), (-7, 11, 5), (-120, -12, -22), (-57, 13, 17), (-15, 0, 10), (12, 0, -12)],
        (-74, -44, 8, 49, -7, -18), (-52, -78, 41, 17, -14, -7),
    ),
    "haaland": (
        [(8, 6, -2), (8, -4, 1), (5, 12, -31), (4, -17, 30), (-15, 0, 7), (-11, 0, -8)],
        [(1, 1, 0), (10, 0, 0), (-14, -22, -33), (-14, 22, 33), (-8, 0, 11), (-8, 0, -11)],
        [(1, -1, 0), (11, 0, 0), (-13, -25, -32), (-13, 25, 32), (-10, 0, 12), (-10, 0, -12)],
        (-92, -92, 30, 30, -12, -12), (-93, -93, 31, 31, -12, -12),
    ),
    "vinicius": (
        [(9, -20, -13), (1, 12, 9), (-64, -4, -21), (18, 0, 20), (-18, 0, 12), (11, 0, -9)],
        [(4, 24, 18), (-3, -14, -9), (-23, 22, -44), (-86, 13, 38), (8, 0, 14), (-37, -6, -15)],
        [(-5, -21, -12), (4, 13, 5), (-94, -16, -23), (-29, -8, 34), (-42, 7, 14), (12, 0, -7)],
        (-57, -74, 16, 61, -4, -16), (-73, -51, 61, 17, -19, -5),
    ),
}
for index, name in enumerate(CELEBRATIONS):
    start = 225 + index * 32
    RANGES[name] = (start, start + 24)



def record(rig, clip, time, angles, torso_y=0):
    start, end = RANGES[clip]
    frame = start + (end - start) * time
    turns = [*angles, *[(value, 0, 0) for value in HINGES[clip][time]]]
    for (name, joint), turn in zip(rig.items(), turns):
        rotation = Euler(tuple(radians(degree) for degree in turn), "ZYX").to_matrix()
        joint.rotation_euler = (BASIS @ rotation @ BASIS.transposed()).to_euler()
        position = (0, torso_y if name in ("Torso", "Head", "Left arm", "Right arm") else 0, 0)
        joint.location = local_offset(name) + blender(position)
        joint.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        joint.keyframe_insert(data_path="location", frame=frame, group=name)


def figure_rig():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.render.fps = 1, max(end for _, end in RANGES.values()), 24
    rig = {}
    for name, at in JOINTS.items():
        joint = bpy.data.objects.new(name, None)
        scene.collection.objects.link(joint)
        if name in PARENTS:
            joint.parent = rig[PARENTS[name]]
        joint.location = local_offset(name)
        joint.empty_display_size = .22
        rig[name] = joint
    # Use the production sculpts for the torso and head in the animation scene.
    sculpt_file = ROOT / "art/player-sculpts.blend"
    with bpy.data.libraries.load(str(sculpt_file), link=False) as (_, imported):
        imported.objects = ["messi_jersey", "messi"]
    for mesh, joint, y in zip(imported.objects, ("Torso", "Head"), (3.00, 4.59)):
        scene.collection.objects.link(mesh)
        mesh.parent = rig[joint]
        mesh.location = blender(point(0, y, 0)) - blender(JOINTS[joint])
        if joint == "Torso":
            mesh.scale = (1.97, 1.30, 1.65)
        else:
            mesh.scale = (1.44 * .87, 1.48 * .94, 1.21 * 1.035)
    previews = {"Torso": [((0, 3.82, 0), (.58, .45, .63), "Skin")]}
    for label, side in (("Left", -1), ("Right", 1)):
        previews[label + " arm"] = [((side * 1.10, 3.24, 0), (.76, .83, .80), "Kit")]
        previews[label + " elbow"] = [((side * 1.34, 2.68, .17), (.52, .91, .60), "Skin")]
        previews[label + " leg"] = [((side * .44, 1.93, 0), (.81, .87, .84), "Hair")]
        previews[label + " knee"] = [((side * .47, 1.17, .05), (.49, .99, .55), "Kit")]
        previews[label + " ankle"] = [((side * .49, .63, .26), (.76, .52, 1.04), "Hair")]
    colors = {"Kit": (.78, .91, .94, 1), "Skin": (.80, .57, .43, 1), "Hair": (.09, .16, .22, 1)}
    for name, pieces in previews.items():
        for pos, size, surface in pieces:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.5)
            model = bpy.context.object
            model.parent = rig[name]
            model.location = blender(point(*pos)) - blender(JOINTS[name])
            model.scale = size[0] * .87, size[2] * .94, size[1] * (1.38 if pos[1] < 2.20 else 1.035)
            material = bpy.data.materials.get(surface)
            if not material:
                material = bpy.data.materials.new(surface)
                material.diffuse_color = colors[surface]
            model.data.materials.append(material)
            for face in model.data.polygons:
                face.use_smooth = True
    for clip, (start, _) in RANGES.items():
        scene.timeline_markers.new(clip.capitalize(), frame=start)
    record(rig, "idle", 0, [(0, 0, -2), (0, -4, 1), (2, 0, -5), (-2, 0, 4), (0, 0, 1), (0, 0, -1)])
    record(rig, "idle", .33, [(2, 3, 2), (-3, 7, -3), (-4, 0, -7), (5, 0, 5), (0, 0, 0), (0, 0, -1)], .045)
    record(rig, "idle", .67, [(1, -2, 1), (1, 3, -2), (-2, 0, -4), (3, 0, 5), (0, 0, 0), (0, 0, 0)], .023)
    record(rig, "idle", 1, [(0, 0, -2), (0, -4, 1), (2, 0, -5), (-2, 0, 4), (0, 0, 1), (0, 0, -1)])
    contact = [(9, -8, -3), (-4, 4, 1), (52, 5, -16), (-47, 1, 17), (-43, 0, 5), (38, 0, -7)]
    record(rig, "stride", 0, contact)
    record(rig, "stride", .25, [(5, 1, 1), (3, -3, -2), (3, 6, -12), (-9, 3, 7), (9, 0, 1), (-12, 0, -7)], -.062)
    record(rig, "stride", .50, [(11, 7, 3), (-4, -4, -1), (-47, -1, -18), (50, -4, 16), (42, 0, 6), (-46, 0, -3)])
    record(rig, "stride", .75, [(6, 1, -1), (2, 3, 2), (-10, -2, -7), (4, -4, 11), (-13, 0, 5), (8, 0, -3)], -.053)
    record(rig, "stride", 1, contact)
    record(rig, "cheer", 0, NEUTRAL)
    record(rig, "cheer", .18, [(15, -8, -4), (7, 0, 1), (20, 0, -18), (23, 0, 14), (-8, 0, 3), (-12, 0, -3)], -.13)
    record(rig, "cheer", .40, [(-9, 10, 2), (-13, 0, -5), (-137, 12, -28), (-117, -10, 35), (15, 0, 4), (-18, 0, -4)], .19)
    record(rig, "cheer", .63, [(-3, 7, -3), (-8, -9, -2), (-105, 5, -57), (-130, -11, 40), (5, 0, 4), (-9, 0, -4)], .042)
    record(rig, "cheer", 1, NEUTRAL)
    record(rig, "launch", 0, NEUTRAL)
    record(rig, "launch", .60, [(25, -9, 5), (7, 4, -2), (39, 0, -17), (34, 0, 18), (-21, 0, 5), (-29, 0, -4)], -.29)
    record(rig, "launch", 1, [(10, 0, -2), (0, 0, -2), (29, 0, -8), (-22, 0, 8), (-21, 0, 5), (20, 0, -5)])
    record(rig, "land", 0, [(12, -7, -2), (0, 0, 0), (21, 0, -15), (-16, 0, 13), (-19, 0, 2), (17, 0, -3)])
    record(rig, "land", .34, [(26, 0, 3), (11, 0, 0), (29, 0, -30), (22, 0, 28), (-16, 0, 9), (-15, 0, -9)], -.31)
    record(rig, "land", .72, [(-4, 2, 0), (-8, 0, 0), (-10, 0, -7), (-9, 0, 7), (0, 0, 0), (0, 0, 0)], .035)
    record(rig, "land", 1, NEUTRAL)
    record(rig, "kick", 0, [(11, 4, -3), (-4, -4, 6), (-21, 2, -15), (30, 0, 13), (-23, 0, 8), (32, 0, -3)])
    record(rig, "kick", .30, [(6, 18, -5), (2, -14, 4), (-9, 6, -38), (42, -2, 38), (-13, 0, 7), (60, 0, -3)], -.09)
    record(rig, "kick", .43, [(4, 6, -4), (0, -6, 2), (7, 4, -48), (-14, 8, 42), (0, 0, 8), (27, 0, -3)], -.065)
    record(rig, "kick", .52, [(-7, -18, 4), (-4, 10, -4), (21, 1, -66), (-52, 13, 40), (5, 0, 6), (-76, 0, -7)], .016)
    record(rig, "kick", .65, [(-12, -30, 8), (-5, 19, -4), (26, 7, -47), (-43, 12, 25), (9, 0, 6), (-89, 5, -11)], .057)
    record(rig, "kick", .84, [(2, -19, 6), (1, 14, -3), (14, 4, -23), (-22, 8, 17), (4, 0, 3), (-25, 2, -5)], .025)
    record(rig, "kick", 1, NEUTRAL)
    record(rig, "save", 0, [(12, 0, 0), (3, 0, 0), (-21, -5, -19), (-21, 5, 19), (-12, 0, 11), (-12, 0, -11)], -.19)
    record(rig, "save", .24, [(9, -5, 13), (7, 7, -4), (-56, 0, -34), (-71, 2, 27), (-14, 4, 17), (-7, 0, -10)], -.10)
    record(rig, "save", .49, [(-16, 4, 36), (-11, -8, -17), (-115, 5, -43), (-100, -17, 24), (15, 3, 13), (22, 4, -8)], .11)
    record(rig, "save", .72, [(4, -5, 25), (7, 6, -11), (-72, 5, -15), (-69, -7, 12), (-17, 4, 13), (-20, 2, -10)], -.16)
    record(rig, "save", 1, NEUTRAL)
    for name, (gather, peak, land, peak_hinges, land_hinges) in CELEBRATIONS.items():
        HINGES[name] = {
            0: (0, 0, 0, 0, 0, 0), .18: (-33, -33, 30, 30, -11, -11),
            .45: peak_hinges, .74: land_hinges, .91: land_hinges, 1: (0, 0, 0, 0, 0, 0),
        }
        record(rig, name, 0, NEUTRAL)
        record(rig, name, .18, gather, -.12)
        record(rig, name, .45, peak, .19 if name == "ronaldo" else .03)
        record(rig, name, .74, land, -.13 if name == "ronaldo" else .02)
        record(rig, name, .91, land)
        record(rig, name, 1, NEUTRAL)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "MATERIAL"
                region = area.spaces.active.region_3d
                region.view_rotation = Euler((radians(77), 0, radians(16)), "XYZ").to_quaternion()
                region.view_location = blender((0, 2.75, 0))
                region.view_distance = 10
    bpy.ops.object.select_all(action="DESELECT")
    scene.frame_set(173)
    return rig


export_only = "--" in sys.argv and "--export" in sys.argv[sys.argv.index("--") + 1:]
if export_only:
    joints = {key: bpy.context.scene.objects[key] for key in JOINTS}
else:
    joints = figure_rig()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/pawn-motion.blend"), compress=True)

scene = bpy.context.scene
lines = ["--!strict\n-- Sampled from Blender's pawn-motion.blend.\nreturn {\n"]
for clip, (start, end) in RANGES.items():
    lines.append(f"\t{clip} = {{\n")
    for frame in range(start, end + 1, 2):
        scene.frame_set(frame)
        values = []
        for name, joint in joints.items():
            offset = studio(joint.location - local_offset(name))
            rotation = (BASIS.transposed() @ joint.rotation_euler.to_matrix() @ BASIS).to_quaternion()
            values.extend(round(value, 5) for value in (*offset, rotation.x, rotation.y, rotation.z, rotation.w))
        lines.append("\t\t{" + ", ".join(map(str, values)) + "},\n")
    lines.append("\t},\n")
lines.append("}\n")
(ROOT / "src/client/PawnMotionData.luau").write_text("".join(lines))
print("Exported", ", ".join(RANGES), "as 13 samples per clip")
