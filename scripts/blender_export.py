"""Encode evaluated Blender objects as local Roblox mesh data."""
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def studio(vector):
    return vector.x, vector.z, -vector.y


def blender(xyz):
    x, y, z = xyz
    return Vector((x, -z, y))


def array(name, values):
    rows = (", ".join(str(v) for v in values[i:i + 21]) for i in range(0, len(values), 21))
    return f"\t\t{name} = {{\n" + "".join(f"\t\t\t{row},\n" for row in rows) + "\t\t},\n"


def export_shapes(models, target):
    totals = Counter()
    lines = ["--!strict\n-- Generated from Blender. Edit the source scene and re-export.\nreturn table.freeze({\n"]
    deps = bpy.context.evaluated_depsgraph_get()
    for model in models:
        evaluated = model.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        positions = [studio(v.co) for v in mesh.vertices]
        low = [min(p[i] for p in positions) for i in range(3)]
        high = [max(p[i] for p in positions) for i in range(3)]
        extent = [b - a for a, b in zip(low, high)]
        assert min(extent) > 0, model.name
        points = [round(10000 * ((v[i] - low[i]) / extent[i] - .5)) for v in positions for i in range(3)]
        normals, normal_ids = {}, []
        triangles, face_colors = [], []
        colors = []
        for mat in mesh.materials:
            rgba = [round(255 * channel) for channel in mat.diffuse_color]
            colors.append((rgba[0] << 16) + (rgba[1] << 8) + rgba[2])
        for tri in mesh.loop_triangles:
            triangles.extend(index + 1 for index in tri.vertices)
            for loop in tri.loops:
                normal = studio(mesh.corner_normals[loop].vector)
                normal = tuple(round(v * 10000) for v in normal)
                normal_ids.append(normals.setdefault(normal, len(normals) + 1))
            if colors:
                face_colors.append(tri.material_index + 1)
        count = len(triangles) // 3
        assert 0 < count <= 6000, (model.name, count)
        totals.update(vertices=len(positions), triangles=count)
        lines.append(f'\t["{model.name}"] = {{\n')
        for key, values in (("points", points), ("normals", [v for n in normals for v in n]),
                            ("triangles", triangles), ("normalIndices", normal_ids),
                            ("colors", colors), ("faceColors", face_colors)):
            if values:
                lines.append(array(key, values))
        lines.append("\t},\n")
        print(f"{model.name}: {len(positions)} vertices, {count} triangles")
        evaluated.to_mesh_clear()
    print(f"Total: {totals['vertices']} vertices, {totals['triangles']} triangles")
    lines.append("})\n")
    (ROOT / target).write_text("".join(lines))
