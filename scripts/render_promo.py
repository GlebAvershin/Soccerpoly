"""Render promotional game icon and banner in Blender Cycles for GitHub & Roblox."""
from math import pi, radians
from pathlib import Path
import sys

import bpy
from mathutils import Vector, Euler

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT

OUT_DIR = ROOT / "art/promo"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def surface(mat, rgba, roughness=0.3, metal=0.0):
    mat.use_nodes = True
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*[linear(c) for c in rgba[:3]], 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    return mat


def create_die(name, at, scale, mat_core, mat_pip):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    die = bpy.context.object
    die.name = name
    die.scale = (scale,) * 3
    die.data.materials.append(mat_core)
    bevel = die.modifiers.new("Bevel", "BEVEL")
    bevel.width, bevel.segments = 0.08, 3
    normal = die.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return die


def area_light(name, at, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = at
    light.rotation_euler = (-Vector(at)).to_track_quat("-Z", "Y").to_euler()
    return light


def render_icon():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    # Retain megastadium and arena
    keep = {"megastadium", "arena", "club_flag"}
    for obj in list(scene.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)

    for mat in bpy.data.materials:
        gold = "F5" in mat.name or "BE" in mat.name
        surface(mat, tuple(mat.diffuse_color), .18 if gold else .42, .85 if gold else .05)

    gold_mat = surface(bpy.data.materials.new("ObsidianGold"), (.96, .78, .26, 1), .15, .88)
    obsidian_mat = surface(bpy.data.materials.new("ObsidianDark"), (.04, .04, .06, 1), .08, .35)
    pedestal_mat = surface(bpy.data.materials.new("PedestalDark"), (.08, .12, .16, 1), .38, .12)

    # Base display stage
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.2, depth=0.42, location=(0, 0, -0.21))
    plinth = bpy.context.object
    plinth.data.materials.append(pedestal_mat)

    # Center hero megastadium
    stadium = scene.objects["megastadium"]
    stadium.scale = (1.45, 1.45, 1.45)
    stadium.location = (0, 0, 0.0)

    # Obsidian Gold and Champions Gold Dice flanking
    die_a = create_die("DieObsidian", (-2.1, -1.2, 0.45), 0.9, obsidian_mat, gold_mat)
    die_a.rotation_euler = Euler((radians(28), radians(35), radians(-18)))

    die_b = create_die("DieGold", (2.1, -1.0, 0.45), 0.85, gold_mat, obsidian_mat)
    die_b.rotation_euler = Euler((radians(-22), radians(40), radians(45)))

    # Lighting
    area_light("KeyGold", (-3.5, -7.0, 8.5), (1.0, .88, .65), 3200, 7.0)
    area_light("FillCyan", (6.5, -4.0, 6.0), (.38, .75, 1.0), 1800, 6.0)
    area_light("RimTop", (0, 5.0, 7.5), (.92, .95, 1.0), 2800, 5.5)

    scene.world = bpy.data.worlds.new("PromoAmbient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22

    # Camera (square 512x512)
    cam_loc = Vector((0, -8.6, 5.4))
    view_rot = (-cam_loc).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 65

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 24, True
    scene.render.resolution_x, scene.render.resolution_y = 512, 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT_DIR / "game_icon.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: game_icon.png rendered")


def render_banner():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    for mat in bpy.data.materials:
        gold = "F5" in mat.name or "BE" in mat.name
        surface(mat, tuple(mat.diffuse_color), .20 if gold else .40, .80 if gold else .08)

    gold_mat = surface(bpy.data.materials.new("ObsidianGold"), (.96, .78, .26, 1), .15, .88)
    obsidian_mat = surface(bpy.data.materials.new("ObsidianDark"), (.04, .04, .06, 1), .08, .35)
    floor_mat = surface(bpy.data.materials.new("BannerFloor"), (.05, .08, .11, 1), .55, .10)

    # Floor ground
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -0.05))
    bpy.context.object.data.materials.append(floor_mat)

    # Array of buildings
    buildings = ("club_flag", "academy", "arena", "megastadium")
    for idx, name in enumerate(buildings):
        if name in scene.objects:
            obj = scene.objects[name]
            obj.scale = (1.35, 1.35, 1.35)
            obj.location = ((idx - 1.5) * 4.6, 0.5, 0.0)

    # Dice in the foreground
    die_a = create_die("DieLeft", (-4.2, -3.2, 0.65), 1.25, obsidian_mat, gold_mat)
    die_a.rotation_euler = Euler((radians(35), radians(-25), radians(15)))

    die_b = create_die("DieRight", (4.2, -3.0, 0.65), 1.2, gold_mat, obsidian_mat)
    die_b.rotation_euler = Euler((radians(-30), radians(32), radians(-40)))

    # Lighting
    area_light("BannerKey", (-6, -12, 14), (1.0, .92, .82), 4800, 10.0)
    area_light("BannerFill", (10, -6, 10), (.35, .80, 1.0), 2800, 9.0)
    area_light("BannerRim", (0, 8, 11), (.85, .92, 1.0), 3600, 8.0)

    scene.world = bpy.data.worlds.new("BannerAmbient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.28

    # Camera (1920x1080)
    cam_loc = Vector((0, -14.5, 7.2))
    view_rot = (-cam_loc).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 48

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 24, True
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT_DIR / "game_banner.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: game_banner.png rendered")


if __name__ == "__main__":
    render_icon()
    render_banner()
