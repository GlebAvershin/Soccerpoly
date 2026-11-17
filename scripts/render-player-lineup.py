"""Light the exact figures exported by a Roblox Studio QA session.

Use a captured FIGURE_EXPORT log with:
    blender -b -t 6 --python scripts/render-player-lineup.py -- path/to/studio.log
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from functools import lru_cache

root = Path(__file__).resolve().parents[1]
rows = Path(sys.argv[sys.argv.index("--") + 1]).read_text().splitlines()
rows = [line.split("FIGURE_EXPORT\t", 1)[1].split("\t") for line in rows if "FIGURE_EXPORT\t" in line]
assert len(rows) > 250 and {int(row[0]) for row in rows} == set(range(1, 7))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
basis = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

figures = (
    ("LIONEL MESSI", "ARG  /  10"), ("CRISTIANO RONALDO", "POR  /  07"),
    ("KYLIAN MBAPPÉ", "FRA  /  10"), ("LAMINE YAMAL", "ESP  /  19"),
    ("ERLING HAALAND", "NOR  /  09"), ("VINÍCIUS JÚNIOR", "BRA  /  07"),
)
collections = []
for name, _ in figures:
    collection = bpy.data.collections.new(name.title())
    scene.collection.children.link(collection)
    collections.append(collection)
origins = bpy.data.collections.new("Mesh sources")
scene.collection.children.link(origins)

shapes = {}
keys = {row[2] for row in rows} - {"-"}
for file in ("pawn-shapes.blend", "stadium-kit.blend", "player-sculpts.blend"):
    with bpy.data.libraries.load(str(root / "art" / file), link=False) as (source, output):
        selected = {name.lower(): name for name in source.objects if name.lower() in keys}
        output.objects = list(selected.values())
    for source in output.objects:
        if not source:
            continue
        origins.objects.link(source)
        evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = bpy.data.meshes.new_from_object(evaluated)
        low, high = ([fn(v.co[axis] for v in mesh.vertices) for axis in range(3)] for fn in (min, max))
        for v in mesh.vertices:
            v.co = [(v.co[i] - low[i]) / (high[i] - low[i]) - .5 for i in range(3)]
        if file != "player-sculpts.blend":
            mesh.materials.clear()
        shapes[source.name.lower()] = mesh
for source in list(origins.objects):
    bpy.data.objects.remove(source, do_unlink=True)
bpy.data.collections.remove(origins)

# Roblox's primitive fallback paths use the same unit-size meshes.
bpy.ops.mesh.primitive_cube_add(size=1)
bpy.context.view_layer.objects.active.data.name = "Unit block"
primitive = {"Block": bpy.context.view_layer.objects.active.data}
bpy.data.objects.remove(bpy.context.view_layer.objects.active, do_unlink=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=.5)
primitive["Ball"] = bpy.context.view_layer.objects.active.data
for face in primitive["Ball"].polygons:
    face.use_smooth = True
bpy.data.objects.remove(bpy.context.view_layer.objects.active, do_unlink=True)
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=.5, depth=1)
primitive["Cylinder"] = bpy.context.view_layer.objects.active.data
for vertex in primitive["Cylinder"].vertices:
    nx, ny, nz = vertex.co
    vertex.co = (nz, ny, nx)
for face in primitive["Cylinder"].polygons:
    face.use_smooth = len(face.vertices) == 4
bpy.data.objects.remove(bpy.context.view_layer.objects.active, do_unlink=True)

@lru_cache(maxsize=None)
def material(rgb, metal=.12, rough=.36):
    mat = bpy.data.materials.new("Enamel %02X%02X%02X" % tuple(round(v * 255) for v in rgb))
    # Roblox Color3 is an sRGB swatch. Convert to linear before lighting in Blender.
    def linear(v):
        return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4
    mat.diffuse_color = (*map(linear, rgb), 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    return mat

turns = [-9, 13, -15, 11, -9, 12]
spacing = 3.96
for row in rows:
    n, name, shape, primitive_type = row[:4]
    figure = int(n) - 1
    values = list(map(float, row[4:]))
    rgb, dims, pos, rot = values[:3], values[3:6], values[6:9], values[9:18]
    source = shapes[shape] if shape in shapes else primitive[primitive_type]
    mesh = source.copy()
    obj = bpy.data.objects.new(name, mesh)
    collections[figure].objects.link(obj)
    orient = Matrix([rot[i:i + 3] for i in range(0, 9, 3)])
    swatch = material(tuple(rgb), .28 if name.startswith(("Turntable", "Heel")) else .07, .36 if shape != "jersey" else .48)
    if mesh.materials:
        for i, source_material in enumerate(mesh.materials):
            mesh.materials[i] = material(tuple(source_material.diffuse_color[:3]), .04, .49)
    else:
        mesh.materials.append(swatch)
    spin = Matrix.Rotation(math.radians(turns[figure]), 3, "Z")
    size = Matrix.Diagonal((dims[0], dims[2], dims[1]))
    pivot = Vector(((figure - 2.5) * spacing, 0, 0))
    transform = (spin @ basis @ orient @ basis.transposed() @ size).to_4x4()
    transform.translation = pivot + spin @ basis @ Vector(pos)
    obj.matrix_world = transform

def text(name, content, xyz, size, swatch):
    curve = bpy.data.curves.new(name, type="FONT")
    curve.body, curve.align_x, curve.size = content, "CENTER", size
    curve.extrude = .001
    obj = bpy.data.objects.new(name, curve)
    scene.collection.objects.link(obj)
    obj.location, obj.rotation_euler = xyz, (math.radians(74), 0, 0)
    curve.materials.append(swatch)

palette = material((.69, .82, .94), .12, .35)
ivory = material((.91, .94, .93), .0, .3)
floor_mat = material((.22, .22, .31), .16, .39)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.012))
floor = bpy.context.view_layer.objects.active
floor.name = "Studio graphite floor"
floor.data.materials.append(floor_mat)
for i, (name, number) in enumerate(figures):
    x = (i - 2.5) * spacing
    text(name.title() + " nameplate", name, (x, -2.08, .26), .253, ivory)
    text(name.title() + " squad number", number, (x, -2.08, .033), .185, palette)

def light(name, location, power, tint, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = power, tint, "DISK", size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

light("Large softbox", (-8, -12, 14), 4400, (1, .93, .82), 17, (0, 0, 2))
light("Cool fill", (13, -7, 10), 2200, (.67, .78, 1), 13, (0, 0, 3))
light("Violet rim", (0, 7, 11), 3900, (.65, .52, 1), 19, (0, 0, 2))
scene.world = bpy.data.worlds.new("Stadium dusk")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .30

data = bpy.data.cameras.new("Roster camera")
camera = bpy.data.objects.new("Roster camera", data)
scene.collection.objects.link(camera)
camera.location = (1.25, -31, 9.6)
camera.rotation_euler = (Vector((0, 0, 2.92)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type, camera.data.ortho_scale = "ORTHO", 25.2
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 28
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1920, 700
scene.render.resolution_percentage = 100
scene.render.threads_mode, scene.render.threads = "FIXED", 6
scene.render.filepath = "//blender-lineup-v0170.png"
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.color_type = "MATERIAL"
            area.spaces.active.overlay.show_overlays = False
            area.spaces.active.region_3d.view_perspective = "CAMERA"
bpy.ops.object.select_all(action="DESELECT")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(root / "art" / "player-lineup-v0170.blend"), compress=True)
bpy.ops.render.render(write_still=True)
