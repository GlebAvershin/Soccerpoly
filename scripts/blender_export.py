"""Encode evaluated Blender objects as local Roblox mesh data."""
from collections import Counter
import numpy as np
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


def portrait_shader():
    name = "Painted portrait resin"
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    pigment = nodes.new("ShaderNodeVertexColor")
    pigment.layer_name = "PortraitPigment"
    shader = nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .49
    material.node_tree.links.new(pigment.outputs["Color"], shader.inputs["Base Color"])
    return material


def export_shapes(models, target, include_bounds=False):
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
        uv_ids, uv_corners = {}, []
        painted = mesh.uv_layers.get("Portrait")
        colors, vertex_colors = [], []
        pigment = mesh.color_attributes.get("PortraitPigment")
        if pigment:
            palette = {}
            for sample in pigment.data:
                rgb = [round(255 * channel) for channel in sample.color_srgb[:3]]
                rgb = tuple(min(255, round(channel / 5) * 5) for channel in rgb)
                packed = (rgb[0] << 16) + (rgb[1] << 8) + rgb[2]
                vertex_colors.append(palette.setdefault(packed, len(palette) + 1))
            colors = list(palette)
        if painted:
            # Low-memory clients can keep the sampled paint on the mesh even
            # when Roblox declines an editable texture allocation.
            image = next(node.image for node in mesh.materials[0].node_tree.nodes if node.type == "TEX_IMAGE")
            width, height = image.size
            rgba = np.empty(width * height * 4, dtype=np.float32)
            image.pixels.foreach_get(rgba)
            linear = rgba.reshape(height, width, 4)[:, :, :3]
            rgb = np.where(linear < .0031308, 12.92*linear, 1.055*np.power(linear, 1/2.4)-.055)
            palette = {}
            vertex_colors = [1] * len(positions)
            for loop in mesh.loops:
                u,v = painted.data[loop.index].uv
                sample = np.clip(np.rint(rgb[int((v % 1)*(height-1)), int((u % 1)*(width-1))]*63)*4,0,255)
                r,g,b = map(int,sample)
                vertex_colors[loop.vertex_index] = palette.setdefault((r<<16)+(g<<8)+b,len(palette)+1)
            colors = list(palette)
        for mat in (() if pigment or painted else mesh.materials):
            rgba = [round(255 * channel) for channel in mat.diffuse_color]
            colors.append((rgba[0] << 16) + (rgba[1] << 8) + rgba[2])
        for tri in mesh.loop_triangles:
            triangles.extend(index + 1 for index in tri.vertices)
            for loop in tri.loops:
                if painted:
                    u, v = painted.data[loop].uv
                    key = (round(u * 10000), round((1 - v) * 10000))
                    uv_corners.append(uv_ids.setdefault(key, len(uv_ids)+1))
                normal = studio(mesh.corner_normals[loop].vector)
                normal = tuple(round(v * 10000) for v in normal)
                normal_ids.append(normals.setdefault(normal, len(normals) + 1))
            if colors and not vertex_colors:
                face_colors.append(tri.material_index + 1)
        count = len(triangles) // 3
        assert 0 < count <= 6000, (model.name, count)
        totals.update(vertices=len(positions), triangles=count)
        lines.append(f'\t["{model.name}"] = {{\n')
        if include_bounds:
            lines.append(array("size", [round(v, 5) for v in extent]))
            lines.append(array("center", [round((a + b) / 2, 5) for a, b in zip(low, high)]))
        for key, values in (("points", points), ("normals", [v for n in normals for v in n]),
                            ("triangles", triangles), ("normalIndices", normal_ids),
                            ("uvs", [v for pair in uv_ids for v in pair]), ("uvIndices", uv_corners),
                            ("colors", colors), ("faceColors", face_colors), ("vertexColors", vertex_colors)):
            if values:
                lines.append(array(key, values))
        lines.append("\t},\n")
        print(f"{model.name}: {len(positions)} vertices, {count} triangles")
        evaluated.to_mesh_clear()
    print(f"Total: {totals['vertices']} vertices, {totals['triangles']} triangles")
    lines.append("})\n")
    (ROOT / target).write_text("".join(lines))
