"""Render 4 photorealistic promo screenshots in Blender Cycles for Roblox Store page."""
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


def spot_light(name, at, target, color, energy, angle=0.8):
    data = bpy.data.lights.new(name, "SPOT")
    data.energy, data.color, data.spot_size = energy, color, angle
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = at
    light.rotation_euler = (Vector(target) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    return light


# ==========================================
# SCREEN 1: MATCHDAY STADIUM & CUP (HERO)
# ==========================================
def render_screen_1():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    for mat in bpy.data.materials:
        gold = "F5" in mat.name or "BE" in mat.name
        surface(mat, tuple(mat.diffuse_color), .18 if gold else .40, .85 if gold else .06)

    gold_mat = surface(bpy.data.materials.new("ObsidianGold"), (.96, .78, .26, 1), .14, .88)
    obsidian_mat = surface(bpy.data.materials.new("ObsidianDark"), (.04, .04, .06, 1), .08, .35)
    floor_mat = surface(bpy.data.materials.new("PitchGrass"), (.11, .35, .21, 1), .65, .02)

    # Turf ground plane
    bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, -0.05))
    bpy.context.object.data.materials.append(floor_mat)

    # Central Cup (Hero size)
    if "cup" in scene.objects:
        cup = scene.objects["cup"]
        cup.scale = (2.2, 2.2, 2.2)
        cup.location = (0, 0.5, 0)
        cup.data.materials.clear()
        cup.data.materials.append(gold_mat)

    # Megastadium behind
    if "megastadium" in scene.objects:
        stadium = scene.objects["megastadium"]
        stadium.scale = (2.0, 2.0, 2.0)
        stadium.location = (0, 7.5, 0)

    if "arena" in scene.objects:
        arena_l = scene.objects["arena"]
        arena_l.scale = (1.4, 1.4, 1.4)
        arena_l.location = (-6.5, 4.0, 0)

    if "academy" in scene.objects:
        acad_r = scene.objects["academy"]
        acad_r.scale = (1.4, 1.4, 1.4)
        acad_r.location = (6.5, 4.0, 0)

    # Dice in foreground
    die_a = create_die("DieHeroA", (-2.6, -2.4, 0.65), 1.15, obsidian_mat, gold_mat)
    die_a.rotation_euler = Euler((radians(32), radians(-28), radians(20)))

    die_b = create_die("DieHeroB", (2.8, -2.1, 0.65), 1.1, gold_mat, obsidian_mat)
    die_b.rotation_euler = Euler((radians(-24), radians(36), radians(-35)))

    # Lighting
    area_light("KeyGold", (-7, -11, 12), (1.0, .92, .76), 5500, 11.0)
    area_light("FillCyan", (9, -8, 9), (.35, .82, 1.0), 3200, 9.5)
    area_light("RimTop", (0, 9, 12), (.90, .95, 1.0), 4200, 8.5)

    scene.world = bpy.data.worlds.new("S1_Ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.26

    # 1920x1080 camera
    cam_loc = Vector((0, -11.5, 5.8))
    view_rot = (-cam_loc + Vector((0, 0, 1.2))).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 45

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 20, True
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT_DIR / "store_screenshot_1_matchday.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: store_screenshot_1_matchday.png rendered")


# ==========================================
# SCREEN 2: PENALTY SHOOTOUT DRAMA
# ==========================================
def render_screen_2():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    for mat in bpy.data.materials:
        surface(mat, tuple(mat.diffuse_color), .35, .15)

    gold_mat = surface(bpy.data.materials.new("BallGold"), (.98, .82, .32, 1), .12, .85)
    obsidian_mat = surface(bpy.data.materials.new("ObsidianMat"), (.04, .04, .06, 1), .10, .30)
    pitch_mat = surface(bpy.data.materials.new("PenaltyTurf"), (.10, .32, .18, 1), .70, .01)

    # Turf
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -0.05))
    bpy.context.object.data.materials.append(pitch_mat)

    # Goal in position
    if "goal" in scene.objects:
        goal = scene.objects["goal"]
        goal.scale = (1.8, 1.8, 1.8)
        goal.location = (0, 8.0, 0)

    # Official Match Ball on penalty spot
    if "ball" in scene.objects:
        ball = scene.objects["ball"]
        ball.scale = (1.7, 1.7, 1.7)
        ball.location = (0, -1.8, 0.42)
        ball.data.materials.clear()
        ball.data.materials.append(gold_mat)

    # Flanking floodlight towers
    if "lights" in scene.objects:
        l1 = scene.objects["lights"]
        l1.scale = (1.8, 1.8, 1.8)
        l1.location = (-9.0, 7.0, 0)

    # Striker & Goalkeeper pawns (using die + sculpts)
    gk = create_die("GK", (0.5, 7.5, 1.4), 0.9, obsidian_mat, gold_mat)
    gk.rotation_euler = Euler((radians(15), radians(-10), radians(20)))

    # Intense stadium night lighting & godrays
    spot_light("GoalSpotL", (-7, 2, 9), (0, 8, 1.5), (1.0, .94, .85), 6500, 0.9)
    spot_light("GoalSpotR", (7, 2, 9), (0, 8, 1.5), (.40, .85, 1.0), 4500, 0.9)
    area_light("BallKey", (-2, -5, 6), (1.0, .88, .60), 2800, 4.0)

    scene.world = bpy.data.worlds.new("S2_Ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.20

    # Camera aiming from behind ball towards goal
    cam_loc = Vector((0, -5.8, 1.9))
    view_rot = (-cam_loc + Vector((0, 8.0, 1.2))).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 35

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 20, True
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT_DIR / "store_screenshot_2_penalty.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: store_screenshot_2_penalty.png rendered")


# ==========================================
# SCREEN 3: 32 CLUBS & ARENA PLINTH (OVERVIEW)
# ==========================================
def render_screen_3():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    for mat in bpy.data.materials:
        surface(mat, tuple(mat.diffuse_color), .30, .20)

    gold_mat = surface(bpy.data.materials.new("GoldMetal"), (.96, .78, .26, 1), .14, .88)
    plinth_mat = surface(bpy.data.materials.new("PlinthEnamel"), (.08, .14, .18, 1), .40, .15)
    turf_mat = surface(bpy.data.materials.new("ArenaTurf"), (.12, .38, .23, 1), .60, .05)

    if "arena_plinth" in scene.objects:
        plinth = scene.objects["arena_plinth"]
        plinth.scale = (1.5, 1.5, 1.5)
        plinth.location = (0, 0, -0.6)
        plinth.data.materials.clear()
        plinth.data.materials.append(plinth_mat)

    # Stand and stadium surrounding
    if "megastadium" in scene.objects:
        s = scene.objects["megastadium"]
        s.scale = (1.6, 1.6, 1.6)
        s.location = (0, 6.2, 0.4)

    if "arena" in scene.objects:
        a = scene.objects["arena"]
        a.scale = (1.3, 1.3, 1.3)
        a.location = (-5.5, -2.5, 0.4)

    if "academy" in scene.objects:
        ac = scene.objects["academy"]
        ac.scale = (1.3, 1.3, 1.3)
        ac.location = (5.5, -2.5, 0.4)

    # Central Cup
    if "cup" in scene.objects:
        cup = scene.objects["cup"]
        cup.scale = (1.8, 1.8, 1.8)
        cup.location = (0, 0, 0.4)
        cup.data.materials.clear()
        cup.data.materials.append(gold_mat)

    # Lighting
    area_light("OverheadSun", (0, -4, 16), (1.0, .94, .82), 6500, 14.0)
    area_light("SideFill", (12, 6, 10), (.38, .75, 1.0), 3400, 10.0)
    area_light("AccentRim", (-12, 6, 10), (.92, .88, .65), 3400, 10.0)

    scene.world = bpy.data.worlds.new("S3_Ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32

    # High isometric view
    cam_loc = Vector((0, -16.0, 12.5))
    view_rot = (-cam_loc + Vector((0, 1.5, 0.5))).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 42

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 20, True
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT_DIR / "store_screenshot_3_board.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: store_screenshot_3_board.png rendered")


# ==========================================
# SCREEN 4: CONTINENTAL CHAMPION'S TROPHY (CUP)
# ==========================================
def render_screen_4():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/stadium-kit.blend"))
    scene = bpy.context.scene

    gold_mat = surface(bpy.data.materials.new("TrophyPureGold"), (.97, .80, .24, 1), .10, .92)
    obsidian_mat = surface(bpy.data.materials.new("ObsidianPedestal"), (.05, .05, .08, 1), .15, .40)

    # Keep only cup, crest, die
    keep = {"cup", "crest"}
    for obj in list(scene.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Pedestal
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.8, depth=0.6, location=(0, 0, -0.3))
    stage = bpy.context.object
    stage.data.materials.append(obsidian_mat)

    # Giant Hero Cup
    cup = scene.objects["cup"]
    cup.scale = (3.2, 3.2, 3.2)
    cup.location = (0, 0, 0)
    cup.data.materials.clear()
    cup.data.materials.append(gold_mat)

    # Two gold & obsidian dice flanking
    die_l = create_die("DieGoldL", (-2.8, -1.2, 0.6), 1.1, gold_mat, obsidian_mat)
    die_l.rotation_euler = Euler((radians(30), radians(-35), radians(15)))

    die_r = create_die("DieObsidianR", (2.8, -1.0, 0.6), 1.15, obsidian_mat, gold_mat)
    die_r.rotation_euler = Euler((radians(-25), radians(30), radians(-30)))

    # Hero lighting
    area_light("GoldKey", (-5, -9, 8), (1.0, .90, .70), 5000, 7.5)
    area_light("CyanFill", (6, -7, 6), (.35, .80, 1.0), 3000, 6.0)
    area_light("TopRim", (0, 6, 8), (1.0, 1.0, 1.0), 4000, 5.0)

    scene.world = bpy.data.worlds.new("S4_Ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22

    # Camera
    cam_loc = Vector((0, -9.0, 4.2))
    view_rot = (-cam_loc + Vector((0, 0, 1.5))).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=cam_loc, rotation=view_rot)
    scene.camera = bpy.context.object
    scene.camera.data.lens = 52

    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 20, True
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT_DIR / "store_screenshot_4_trophy.png")
    bpy.ops.render.render(write_still=True)
    print("SUCCESS: store_screenshot_4_trophy.png rendered")


if __name__ == "__main__":
    print("Rendering Roblox Store Pack...")
    render_screen_1()
    render_screen_2()
    render_screen_3()
    render_screen_4()
    print("ALL 4 STORE SCREENSHOTS RENDERED SUCCESSFULLY!")
