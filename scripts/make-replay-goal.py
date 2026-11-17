"""Build the replay goal's fixed rig. The back net is strung and animated in Luau."""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, blender, export_shapes


def tube(a, b, radius, pigment, sides=8):
    start, end = blender(a), blender(b)
    delta = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=delta.length,
                                        location=(start + end) * .5)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    material = bpy.data.materials.get(pigment)
    if material is None:
        material = bpy.data.materials.new(pigment)
        material.diffuse_color = tuple(int(pigment[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1,)
    obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4


name = "replay_goal_frame"
if "--export" in sys.argv:
    frame = bpy.data.objects[name]
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ivory, alloy, twine, navy = "FCFAEB", "9BAAB7", "D5E6DC", "304457"
    for side in (-1, 1):
        z = 13.5 * side
        tube((0, 0, z), (0, 10.4, z), .19, ivory, 16)
        tube((0, 10.4, z), (6, 8.9, z), .12, ivory, 12)
        tube((6, .14, z), (6, 8.9, z), .095, alloy, 10)
        tube((0, .14, z), (6, .14, z), .14, alloy)
        tube((0, .12, z), (0, .51, z), .23, navy, 16)
        tube((6, .14, z), (4.25, 1.92, z), .082, alloy)
        for i in range(1, 4):
            x = 1.5 * i
            tube((x, .14, z), (x, 10.4 - x * .25, z), .036, twine, 6)
        for i in range(1, 7):
            t = i / 7
            tube((0, .14 + 10.26 * t, z), (6, .14 + 8.76 * t, z), .036, twine, 6)
    tube((0, 10.4, -13.69), (0, 10.4, 13.69), .19, ivory, 16)
    tube((6, 8.9, -13.5), (6, 8.9, 13.5), .074, alloy)
    tube((6, .14, -13.5), (6, .14, 13.5), .095, alloy)
    for i in range(-7, 8):
        z = 13.5 * i / 8
        tube((0, 10.4, z), (6, 8.9, z), .036, twine, 6)
    for i in range(1, 4):
        x = 1.5 * i
        tube((x, 10.4 - x * .25, -13.5), (x, 10.4 - x * .25, 13.5), .036, twine, 6)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    frame = bpy.context.object
    frame.name = name
    frame.asset_mark()
    frame.asset_data.description = "Matchday goal — enamel tubes, heel braces, sleeves and woven roof"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/matchday-goal.blend"), compress=True)

export_shapes([frame], "src/client/ReplayMeshData.luau", include_bounds=True)
