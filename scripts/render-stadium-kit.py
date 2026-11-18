"""Render six in-game Blender assets on plinths for the portfolio."""
from math import pi
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT

PROPS = ("club_flag", "academy", "arena", "megastadium", "night_stand", "lights")


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def surface(mat, rgba, roughness, metal=0):
    mat.use_nodes = True
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*[linear(c) for c in rgba[:3]], 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    return mat


def cylinder(name, at, radius, height, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=72, radius=radius, depth=height, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Rounded edge", "BEVEL")
    bevel.width, bevel.segments = .06, 3
    normal = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    normal.keep_sharp = True


def area(name, at, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location, light.rotation_euler = at, (-Vector(at)).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
scene = bpy.context.scene
for obj in list(scene.objects):
    if obj.name not in PROPS:
        bpy.data.objects.remove(obj, do_unlink=True)
for mat in bpy.data.materials:
    gold = mat.name == "F5BE62"
    surface(mat, tuple(mat.diffuse_color), .26 if gold else .44, .72 if gold else .08)
base = surface(bpy.data.materials.new("Painted aluminium"), (.14, .22, .27, 1), .37, .28)
rim = surface(bpy.data.materials.new("Brass trim"), (.61, .43, .21, 1), .27, .62)
floor = surface(bpy.data.materials.new("Studio floor"), (.079, .14, .19, 1), .61)

eye = Vector((7, -19, 17))
view = (Vector((0, 0, .43)) - eye).to_track_quat("-Z", "Y")
right = view @ Vector((1, 0, 0))
up = view @ Vector((0, 1, 0))
away = Vector((up.x, up.y, 0)).normalized()
for index, name in enumerate(PROPS):
    obj = scene.objects[name]
    at = right * ((index % 3 - 1) * 4.43) + away * ((.5 - index // 3) * 5.6)
    cylinder("Plinth", at + Vector((0, 0, .17)), 1.93, .32, base)
    cylinder("Inlay", at + Vector((0, 0, .27)), 1.945, .064, rim)
    bounds = [Vector(corner) for corner in obj.bound_box]
    low = Vector([min(p[i] for p in bounds) for i in range(3)])
    high = Vector([max(p[i] for p in bounds) for i in range(3)])
    edge = max(high - low)
    scale = (2.45 if name in ("cup", "ball") else 3.22) / edge
    obj.scale = (scale,) * 3
    obj.rotation_euler.z = pi if name in ("stand", "tunnel", "night_stand") else 0
    mid = (high + low) / 2
    obj.location = at + Vector((0, 0, .32 - low.z * scale)) - obj.rotation_euler.to_matrix() @ Vector((mid.x, mid.y, 0)) * scale

bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(floor)
bpy.ops.object.camera_add(location=eye)
scene.camera = bpy.context.object
scene.camera.rotation_euler = view.to_euler()
scene.camera.data.type, scene.camera.data.ortho_scale = "ORTHO", 15.9
area("Softbox", (-4, -8, 15), (1, .92, .80), 2700, 11)
area("Skylight", (8, -1, 10), (.62, .83, 1), 1700, 9)
area("Rim", (0, 10, 12), (.71, .90, 1), 2500, 8)
scene.world = bpy.data.worlds.new("Studio ambient")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .24
scene.render.engine = "CYCLES"
scene.cycles.samples, scene.cycles.use_denoising = 18, True
scene.render.resolution_x, scene.render.resolution_y = 1440, 940
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "art/blender-stadium-kit.png")
bpy.ops.render.render(write_still=True)
