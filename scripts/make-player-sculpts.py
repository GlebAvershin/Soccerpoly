"""Author the six portrait sculpts in Blender and export local mesh geometry.

Run with Blender's --background --python flags. Open player-sculpts.blend and
rerun with -- --export to export edits to the saved mesh objects.
"""
from dataclasses import dataclass
import json
from math import atan2, cos, exp, pi, sin, sqrt, tau
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_export import ROOT, blender, export_shapes, portrait_shader

FITS = json.loads((ROOT / "art/portrait-fits.json").read_text())


@dataclass(frozen=True)
class Portrait:
    skin: int
    hair: int
    style: str
    width: float
    length: float
    jaw: float
    nose: float
    eye: float
    mouth: float
    beard: bool = False


PLAYERS = {
    "messi": Portrait(0xCE926F, 0x48312C, "part", 1.02, .93, .95, .154, .22, .010, True),
    "ronaldo": Portrait(0xBF815E, 0x2A2225, "quiff", .99, 1.05, 1.15, .132, .24, -.013),
    "mbappe": Portrait(0x92573C, 0x251D21, "crop", 1.05, .97, 1.01, .100, .24, .031),
    "yamal": Portrait(0xAF7152, 0x302529, "curls", .94, 1.02, .91, .118, .216, .018),
    "haaland": Portrait(0xE7A78B, 0xB28758, "tied", 1.06, 1.10, 1.19, .155, .233, -.027),
    "vinicius": Portrait(0x884D37, 0x231B21, "highfade", .97, 1.06, .99, .108, .227, .048),
}
GOALKEEPER = Portrait(0x955C43, 0x24232C, "crop", 1.01, 1.04, 1.13, .136, .245, -.007)

# Brow, cheek and jaw cross-sections. Vertical positions are shared with the
# mouth and eyelids so narrowing a particular face also moves its details.
PROFILE = [
    (-.65, .095, .12, .050), (-.615, .21, .23, .095), (-.55, .32, .29, .075),
    (-.44, .40, .338, .031), (-.32, .457, .366, -.002), (-.18, .503, .397, -.021),
    (-.04, .525, .415, -.039), (.10, .512, .413, -.049), (.25, .505, .416, -.060),
    (.39, .483, .391, -.076), (.52, .406, .327, -.080), (.61, .281, .233, -.081),
    (.667, .114, .109, -.082), (.683, .012, .012, -.081),
]


def section(y):
    for a, b in zip(PROFILE, PROFILE[1:]):
        if y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return tuple(left + (right - left) * t for left, right in zip(a[1:], b[1:]))
    return PROFILE[-1][1:]


def radius(p, y):
    w, d, c = section(y)
    return w * p.width * (1 + (p.jaw - 1) * min(1, max(0, -y * 2.2))), d, c


def bulge(x, y, cx, cy, w, h):
    return exp(-((x - cx) / w) ** 2 - ((y - cy) / h) ** 2)


def face_depth(p, x, y, front):
    w, d, c = radius(p, y)
    if not front:
        return c - d * sqrt(max(0, 1 - (x / w) ** 2))
    a = abs(x)
    z = c + d * sqrt(max(0, 1 - (x / w) ** 2))
    z += p.nose * bulge(x, y, 0, -.083, .085, .168)
    z += .066 * bulge(a, y, .062, -.164, .065, .058)
    z += .055 * bulge(a, y, .272, -.145, .15, .127)
    z -= .082 * bulge(a, y, p.eye, .032, .123, .072)
    z += .042 * bulge(a, y, p.eye, .138, .17, .066)
    z += .035 * bulge(x, y, 0, -.37, .20, .107)
    return z


class Sculpt:
    def __init__(self, name, p):
        self.name, self.p = name, p
        self.points, self.faces, self.indices, self.colors = [], [], [], []
        self.pigment = {}
        self.skin = self.color(p.skin)
        self.hair = self.color(p.hair)
        self.brow = self.color(0x36251F if p.style == "tied" else p.hair)
        self.lip = self.color(0x72423B if p.skin >= 0xA00000 else 0x5B3028)
        self.eye = self.color(0x9D9186)
        self.iris = self.color(0x405660 if p.style == "tied" else 0x37241D)
        self.outline = self.color(0x281B19)

    def color(self, color):
        if color not in self.colors:
            self.colors.append(color)
        return self.colors.index(color)

    def band(self, rows, color, capped=True):
        start = len(self.points)
        steps = len(rows[0])
        self.points.extend(blender(point) for row in rows for point in row)
        for row in range(len(rows) - 1):
            for side in range(steps):
                a = start + row * steps + side
                b = start + row * steps + (side + 1) % steps
                self.faces.append((a, b, b + steps, a + steps))
                self.indices.append(color)
        if capped:
            self.faces.extend((tuple(reversed(range(start, start + steps))),
                               tuple(range(len(self.points) - steps, len(self.points)))))
            self.indices.extend((color, color))

    def oval(self, x, y, z, w, h, d, color, steps=12):
        self.band([
            [(x + w * cos(phi) * sin(tau * i / steps),
              y + h * sin(phi), z + d * cos(phi) * cos(tau * i / steps)) for i in range(steps)]
            for phi in [-1.54, -.90, -.43, 0, .43, .90, 1.54]
        ], color)

    def ribbon(self, x1, x2, curve, width, color, depth=.009):
        start = len(self.points)
        for i in range(11):
            t = i / 10
            x = x1 + (x2 - x1) * t
            y = curve(t)
            span = width * max(.09, sin(pi * t) ** .58)
            for yy in (y - span, y + span):
                self.points.append(blender((x, yy * self.p.length, face_depth(self.p, x, yy, True) + depth)))
        for i in range(10):
            a = start + 2 * i
            self.faces.append((a, a + 2, a + 3, a + 1))
            self.indices.append(color)

    def colors_rgb(self, index):
        return tuple((self.colors[index] >> shift) & 255 for shift in (16, 8, 0))

    def build_face(self):
        p = self.p
        layers = sorted({y for y, *_ in PROFILE} | {-.372, -.265, -.12, -.083, -.012, .035, .071, .152})
        rows = []
        for y in layers:
            w, _, _ = radius(p, y)
            ring = []
            for i in range(44):
                angle = tau * i / 44
                x = w * sin(angle)
                ring.append((x, y * p.length, face_depth(p, x, y, cos(angle) > 0)))
            rows.append(ring)
        self.band(rows, self.skin)

        for side in (-1, 1):
            x = side * .475 * p.width
            self.oval(x, -.084 * p.length, -.034, .095, .162 * p.length, .089, self.skin)
            self.oval(x + side * .019, -.084 * p.length, .027, .040, .080, .017, self.lip, 8)
            x = side * p.eye
            z = face_depth(p, x, .037, True)
            self.oval(x, .037 * p.length, z - .010, .096, .037, .034, self.eye)
            self.oval(x + side * .006, .037 * p.length, z + .019, .036, .037, .013, self.iris, 10)
            self.oval(x - .010, .046 * p.length, z + .030, .010, .012, .006, self.eye, 8)
            self.ribbon(x - .105, x + .105, lambda t: .065 + .022 * sin(pi * t), .011, self.outline, .022)
            self.ribbon(x - .12, x + .12, lambda t: .151 + .032 * sin(pi * t) + side * .030 * t, .018, self.brow)
            self.ribbon(side * .052 - .027, side * .052 + .027, lambda t: -.179 + .016 * sin(pi * t),
                        .009, self.lip)
        self.ribbon(-.167, .167, lambda t: -.325 - .020 * sin(pi * t) + p.mouth * (t - .5), .014, self.lip, .012)
        self.ribbon(-.117, .117, lambda t: -.375 + .011 * sin(pi * t), .012, self.lip)
        if p.beard:
            self.beard()

    def beard(self):
        p = self.p
        start = len(self.points)
        steps = 28
        for row in range(7):
            t = row / 6
            for index in range(steps):
                angle = (-1 + 2 * index / (steps - 1)) * 1.89
                # High at the sideburns, away from the mouth at the centre.
                upper = -.459 + .382 * abs(sin(angle)) ** 2
                y = -.64 + (upper + .64) * t
                w, _, _ = radius(p, y)
                x = w * sin(angle)
                z = face_depth(p, x, y, abs(angle) < pi / 2)
                self.points.append(blender((x + .012 * sin(angle), (y - .016) * p.length,
                                            z + .037 * cos(angle))))
        for row in range(6):
            for index in range(steps - 1):
                a = start + row * steps + index
                self.faces.append((a, a + 1, a + 1 + steps, a + steps))
                self.indices.append(self.hair)
        self.ribbon(-.17, -.018, lambda t: -.29 + .040 * t, .023, self.hair, .014)
        self.ribbon(.018, .17, lambda t: -.25 - .040 * t, .023, self.hair, .014)

    def haircut(self):
        p = self.p
        # Front, temple, nape, height. Fade sides sit high over the ear.
        front_line, temple, nape, volume = {
            "part": (.493, .153, -.042, .067),
            "quiff": (.475, .193, .001, .128),
            "crop": (.465, .270, .119, .028),
            "curls": (.399, .210, .063, .160),
            "tied": (.538, .256, .020, .043),
            "highfade": (.449, .279, .116, .133),
        }[p.style]

        def hairline(angle):
            side, facing = sin(angle), cos(angle)
            front = max(0, facing)
            edge = (temple + (front_line - temple) * sqrt(front) if facing >= 0
                    else temple + (nape - temple) * facing * facing)
            if p.style == "part":
                edge += .042 * side * front
            elif p.style == "quiff":
                edge += .018 * cos(angle * 3 - .62) * front
            elif p.style in ("curls", "highfade"):
                edge += .016 * front * cos(angle * 19)
            elif p.style == "tied":
                edge += .034 * exp(-(side / .13) ** 2) * front
            return edge

        rows = []
        steps = 56
        for row in range(13):
            t = row / 12
            ring = []
            for i in range(steps):
                angle = tau * i / steps
                side, facing = sin(angle), cos(angle)
                front = max(0, facing)
                edge = hairline(angle)
                ridge = .007 * sin(angle * 11 - t * 7)
                lift = sin(pi * t) ** .76
                if p.style == "part":
                    ridge += .026 * front * sin(side * 6 + t * 6)
                elif p.style == "quiff":
                    ridge += .054 * front * exp(-((side + .40) / .54) ** 2) * lift
                elif p.style in ("curls", "highfade", "crop"):
                    curl = cos(angle * 13 + row * 1.18) + sin(angle * 7 - row)
                    ridge += (.004 if p.style == "crop" else .016 if p.style == "curls" else .012) * curl * lift
                elif p.style == "tied":
                    ridge *= 1.7
                y = edge + (.682 - edge) * t
                w, d, c = radius(p, y)
                padding = (.012 + ridge) * (1 - t * .45)
                x = (w + padding + (.024 * sin(pi * t) if p.style == "curls" else 0)) * side
                z = c + (d + .013 + padding) * facing
                tuft = volume * (t + .45 * lift * front) + ridge * lift
                yy = y * p.length + tuft
                ring.append((x, yy, z))
            rows.append(ring)
        first = len(self.indices)
        self.band(rows, self.hair)
        if p.style in ("crop", "quiff", "curls", "highfade"):
            def blend(ratio):
                return sum(round(((p.skin >> i) & 255) * ratio + ((p.hair >> i) & 255) * (1 - ratio)) << i
                           for i in (0, 8, 16))
            stubble = self.color(blend(.25))
            fade = self.color(blend(.13))
            for row, color in enumerate((stubble, fade)):
                for i in range(steps):
                    if abs(sin(tau * (i + .5) / steps)) > .47 or cos(tau * i / steps) < 0:
                        self.indices[first + row * steps + i] = color
        if p.style == "tied":
            self.oval(0, .448 * p.length, -.445, .153, .119, .172, self.hair, 16)
            self.oval(0, .448 * p.length, -.401, .150, .033, .161, self.outline, 16)

    def object(self):
        self.build_face()
        self.haircut()
        return self.bake()

    def bake(self):
        mesh = bpy.data.meshes.new(self.name.title() + " portrait sculpt")
        mesh.from_pydata(self.points, [], self.faces)
        mesh.update()
        model = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(model)
        for rgb in self.colors:
            color = tuple(((rgb >> channel) & 255) / 255 for channel in (16, 8, 0))
            mat = bpy.data.materials.new(f"Enamel {rgb:06X}")
            mat.diffuse_color = (*color, 1)
            mesh.materials.append(mat)
        for face, index in zip(mesh.polygons, self.indices):
            face.use_smooth = True
            face.material_index = index
        if self.pigment:
            layer = mesh.color_attributes.new(name="PortraitPigment", type="BYTE_COLOR", domain="POINT")
            for face, index in zip(mesh.polygons, self.indices):
                rgb = self.colors_rgb(index)
                for vertex in face.vertices:
                    layer.data[vertex].color_srgb = (*[channel / 255 for channel in self.pigment.get(vertex, rgb)], 1)
            material = portrait_shader()
            for slot in range(len(mesh.materials)):
                mesh.materials[slot] = material
        return model


# Fitted jersey with modeled folds. Panel boundaries are part of the mesh,
# so the stripes and collars follow the torso and catch the same light.
KITS = {
    "messi": (0xEDF3EC, 0x83C7E9, 0x1B3044),
    "ronaldo": (0xB92547, 0x243D37, 0xECDCBF),
    "mbappe": (0x444C9D, 0x2D386E, 0xF5D5C3),
    "yamal": (0xDA422F, 0xF8AB46, 0x67293A),
    "haaland": (0xD9DEE0, 0x233B55, 0xBD435A),
    "vinicius": (0xECD44B, 0x3B6A4E, 0xEFE9BB),
}
JERSEY_RINGS = [
    (-.53, .333, .331, -.012), (-.50, .366, .365, -.019), (-.43, .379, .375, -.021),
    (-.33, .383, .368, -.025), (-.23, .379, .397, -.026), (-.10, .411, .438, -.012),
    (.03, .449, .459, 0), (.15, .482, .467, .012), (.27, .504, .442, -.004),
    (.35, .489, .398, -.017), (.42, .427, .347, -.028), (.49, .334, .290, -.041),
    (.533, .218, .219, -.049), (.542, .208, .204, -.049), (.505, .182, .181, -.045),
]


def jersey(name):
    mesh_name = name + "_jersey"
    base, panel, trim = KITS[name]
    sculpt = Sculpt(mesh_name, PLAYERS[name])
    sculpt.colors.clear()
    for rgb in (base, panel, trim):
        sculpt.color(rgb)
    steps = 56
    rows = []
    for y, width, depth, offset in JERSEY_RINGS:
        points = []
        for i in range(steps):
            theta = tau * i / steps
            x, front = sin(theta), cos(theta)
            crease = exp(-((y + .38 - x * .34) / .22) ** 2) * (.013 * sin(10 * x + 28 * y))
            crease += .016 * exp(-((y - .15 + abs(x) * .17) / .42) ** 2) * sin(8 * x + 8 * y)
            yy = y - .062 * max(0, front) ** 4 * max(0, y * 2) ** 4
            points.append((width * x, yy, offset + (depth + crease) * front))
        rows.append(points)
    sculpt.band(rows, 0)
    model = sculpt.bake()
    mesh = model.data
    uvs = mesh.uv_layers.new(name="Portrait")
    # Map height physically so the print keeps its proportions across unequal rings.
    for poly in mesh.polygons:
        us = [((idx % steps) / steps + .25) % 1 for idx in poly.vertices]
        wraps = max(us) - min(us) > .5
        for loop, u in zip(poly.loop_indices, us):
            vertex = mesh.loops[loop].vertex_index
            v = (JERSEY_RINGS[vertex // steps][0] + .53) / 1.072
            uvs.data[loop].uv = (u + (1 if wraps and u < .5 else 0), v)
        poly.material_index = 0
    mesh.materials.clear()
    mat = bpy.data.materials.new(name.title()+" woven match kit")
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .84
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(ROOT / "art/portraits" / (mesh_name + ".png")))
    tex.image.pack()
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    mesh.materials.append(mat)
    return model


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    from painted_heads import head
    models = [head(name, FITS) for name in PLAYERS]
    for i, model in enumerate(models):
        model.location.x = (i - 2.5) * 1.52
    for i, name in enumerate(PLAYERS):
        shirt = jersey(name)
        shirt.location = ((i - 2.5) * 1.52, 0, -1.58)
        models.append(shirt)
    keeper = Sculpt("goalkeeper", GOALKEEPER).object()
    keeper.location = (0, 0, -2.95)
    models.append(keeper)
    from match_boot import match_boot
    boot = match_boot()
    boot.location = (1.5, 0, -2.95)
    models.append(boot)
    from mathutils import Euler
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.shading.color_type = "MATERIAL"
                view = area.spaces.active.region_3d
                view.view_rotation = Euler((pi / 2, 0, .035), "XYZ").to_quaternion()
                view.view_location.z = -1.09
                view.view_distance = 12
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/player-sculpts.blend"), compress=True)
    return models


names = [*PLAYERS, *(name + "_jersey" for name in PLAYERS), "goalkeeper", "match_boot"]
models = [bpy.context.scene.objects[name] for name in names] if "--export" in sys.argv else build()
export_shapes(models, "src/client/PlayerSculptData.luau", include_bounds=True)
