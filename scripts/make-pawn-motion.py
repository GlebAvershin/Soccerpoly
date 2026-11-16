"""Create editable keyframed figure motion and sample it for the Luau rig."""
from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, blender, studio

JOINTS = {
    "Torso": (0, 2.18, 0), "Head": (0, 3.97, 0),
    "Left arm": (-.96, 3.45, 0), "Right arm": (.96, 3.45, 0),
    "Left leg": (-.43, 2.09, 0), "Right leg": (.43, 2.09, 0),
}
RANGES = {"idle": (1, 25), "stride": (33, 57), "cheer": (65, 89)}
BASIS = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
NEUTRAL = [(0, 0, 0)] * 6


def record(rig, clip, time, angles, torso_y=0):
    start, end = RANGES[clip]
    frame = start + (end - start) * time
    for (name, joint), turn in zip(rig.items(), angles):
        rotation = Euler(tuple(radians(degree) for degree in turn), "ZYX").to_matrix()
        joint.rotation_euler = (BASIS @ rotation @ BASIS.transposed()).to_euler()
        position = (0, torso_y if name in ("Torso", "Head", "Left arm", "Right arm") else 0, 0)
        joint.location = blender(JOINTS[name]) + blender(position)
        joint.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        joint.keyframe_insert(data_path="location", frame=frame, group=name)


def figure_rig():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.render.fps = 1, 89, 24
    rig = {}
    for name, at in JOINTS.items():
        joint = bpy.data.objects.new(name, None)
        scene.collection.objects.link(joint)
        joint.location = blender(at)
        joint.empty_display_size = .22
        rig[name] = joint
    previews = {
        "Torso": [((0, 3.05, 0), (2.12, 1.65, 1.31), "Kit")],
        "Head": [((0, 4.59, .04), (1.76, 1.62, 1.58), "Skin"),
                 ((0, 5.13, -.05), (1.82, .64, 1.55), "Hair"),
                 ((0, 4.47, .76), (.26, .26, .35), "Skin")],
    }
    for label, side in (("Left", -1), ("Right", 1)):
        previews[label + " arm"] = [((side * 1.10, 3.24, 0), (.76, .83, .80), "Kit"),
                                     ((side * 1.34, 2.68, .17), (.52, .91, .60), "Skin")]
        previews[label + " leg"] = [((side * .44, 1.93, 0), (.89, .93, .89), "Hair"),
                                     ((side * .50, 1.17, .05), (.60, 1.13, .61), "Kit"),
                                     ((side * .52, .63, .26), (.76, .52, 1.04), "Hair")]
    colors = {"Kit": (.13, .72, .48, 1), "Skin": (.64, .38, .22, 1), "Hair": (.11, .12, .15, 1)}
    for name, pieces in previews.items():
        for pos, size, surface in pieces:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.5)
            model = bpy.context.object
            model.parent = rig[name]
            model.location = blender(pos) - blender(JOINTS[name])
            model.scale = size[0], size[2], size[1]
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
    contact = [(9, -8, -3), (-4, 4, 1), (43, 5, -9), (-35, 1, 7), (-36, 0, 2), (31, 0, -5)]
    record(rig, "stride", 0, contact)
    record(rig, "stride", .25, [(5, 1, 1), (3, -3, -2), (3, 6, -12), (-9, 3, 7), (9, 0, 1), (-12, 0, -7)], -.062)
    record(rig, "stride", .50, [(11, 7, 3), (-4, -4, -1), (-38, -1, -10), (40, -4, 8), (34, 0, 6), (-38, 0, -2)])
    record(rig, "stride", .75, [(6, 1, -1), (2, 3, 2), (-10, -2, -7), (4, -4, 11), (-13, 0, 5), (8, 0, -3)], -.053)
    record(rig, "stride", 1, contact)
    record(rig, "cheer", 0, NEUTRAL)
    record(rig, "cheer", .18, [(15, -8, -4), (7, 0, 1), (20, 0, -18), (23, 0, 14), (-8, 0, 3), (-12, 0, -3)], -.13)
    record(rig, "cheer", .40, [(-9, 10, 2), (-13, 0, -5), (-137, 12, -28), (-117, -10, 35), (11, 0, 4), (-15, 0, -4)], .10)
    record(rig, "cheer", .63, [(-3, 7, -3), (-8, -9, -2), (-105, 5, -57), (-130, -11, 40), (5, 0, 4), (-9, 0, -4)], .042)
    record(rig, "cheer", 1, NEUTRAL)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "MATERIAL"
                region = area.spaces.active.region_3d
                region.view_rotation = Euler((radians(77), 0, radians(16)), "XYZ").to_quaternion()
                region.view_location = blender((0, 2.75, 0))
                region.view_distance = 10
    bpy.ops.object.select_all(action="DESELECT")
    scene.frame_set(45)
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
            offset = studio(joint.location - blender(JOINTS[name]))
            rotation = (BASIS.transposed() @ joint.rotation_euler.to_matrix() @ BASIS).to_quaternion()
            values.extend(round(value, 5) for value in (*offset, rotation.x, rotation.y, rotation.z, rotation.w))
        lines.append("\t\t{" + ", ".join(map(str, values)) + "},\n")
    lines.append("\t},\n")
lines.append("}\n")
(ROOT / "src/client/PawnMotionData.luau").write_text("".join(lines))
print("Exported", ", ".join(RANGES), "as 13 samples per clip")
