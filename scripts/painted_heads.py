"""Build the player's painted head as a closed, UV-mapped Blender mesh."""
import json
from math import cos, sin, pi, tau
import bpy
import bmesh
from mathutils import Vector
from blender_export import ROOT, blender

DIR = ROOT / "art/portraits"
STUDIES = json.loads((DIR / "landmarks.json").read_text())
EYES = ([33,246,161,160,159,158,157,173,133,155,154,153,145,144,163,7],
        [263,249,390,373,374,380,381,382,362,398,384,385,386,387,388,466])


def head(name, topology):
    ref = STUDIES[name]
    pts = ref["points"]
    origin = (pts[234][0] + pts[454][0]) / 2
    scale = 1.19 / (pts[152][1] - pts[10][1])
    chin = pts[152][1]
    temple = (pts[234][2] + pts[454][2]) / 2
    def point(u, v, depth):
        return blender(((u-origin)*scale, (chin-v)*scale-.64, depth))
    coords = [point(u,v,(temple-z)*scale*.88-.05) for u,v,z in pts[:468]]
    uv = [(u*.5, 1-v) for u,v,_ in pts[:468]]
    faces = list(map(tuple,topology["faces"]))
    def vertex(co, tex):
        coords.append(co)
        uv.append(tex)
        return len(uv)-1
    # Close the orbital openings with convex corneas, registered to the iris paint.
    for ring, iris in zip(EYES, (468,473)):
        faces = [face for face in faces if not set(face).issubset(ring)]
        u,v,_ = pts[iris]
        tip = vertex(point(u,v, -sum(coords[k].y for k in ring)/len(ring)+.012), (u*.5,1-v))
        faces.extend((a,b,tip) for a,b in zip(ring, ring[1:]+ring[:1]))
    top = [78,191,80,81,82,13,312,311,310,415,308]
    low = [78,95,88,178,87,14,317,402,318,324,308]
    lips = set(top + low)
    faces = [face for face in faces if not set(face).issubset(lips)]
    for a,b,c,d in zip(top, top[1:], low[1:],low):
        faces.append(tuple(dict.fromkeys((a,b,c,d))))

    rim = topology["oval"]
    def join(old,new):
        faces.extend((old[k-1],old[k],new[k],new[k-1]) for k in range(len(new)))
    # Carry the forehead into the quiff and temples. The front silhouette is
    # measured from each study independently, including asymmetric hair parts.
    for r in range(1,9):
        t = r/8
        new = []
        for k, i in enumerate(topology["oval"]):
            u,v,_ = pts[i]
            ex,ey = ref["outline"][k]
            sx = u+(ex-u)*sin(t*pi/2)
            sy = v+(ey-v)*sin(t*pi/2)
            front = -coords[i].y
            # Jaw wraps towards the neck. Crown lifts before turning back.
            end = -.08 - .03*max(0, (.45-v)*2)
            dep = front + (end-front)*(1-cos(t*pi/2))
            lift = max(0, (.41-v)*3.1)*sin(t*pi)
            if name in ("yamal","vinicius"):
                dep += lift*(.023*sin(k*2.3+r*.81)+.018*cos(k*1.21-r))
                sy -= lift*.008*cos(k*1.75+r*.68)
            elif name in ("messi","ronaldo"):
                dep += lift*(.018*sin(13*sx+5*t)+.012*cos(49*sx+5*t))
            new.append(vertex(point(sx,sy,dep),(sx*.5,1-sy)))
        join(rim,new)
        rim=new
    # Occipital vault flattens towards the nape and rounds over the crown.
    for r in range(1,13):
        t=r*pi/26
        new=[]
        for k, index in enumerate(topology["oval"]):
            u,v=ref["outline"][k]
            sx=origin+(u-origin)*cos(t)
            sy=.45+(v-.45)*cos(t)
            dep=-.08-.66*sin(t) + .12*max(0,v-.57)*sin(2*t)
            if name in ("yamal","vinicius"):
                dep += (.017*sin(k*3.1+r)+.012*cos(k-r*.7))*max(0,(.45-sy)*2)*sin(2*t)
            new.append(vertex(point(sx,sy,dep),(.5+.5*sx,1-sy)))
        join(rim,new)
        rim=new
    pole=vertex(point(origin,.45,-.744),(.5+.5*origin,.55))
    faces.extend((rim[k-1],rim[k],pole) for k in range(len(rim)))

    if name == "haaland":
        # Tied-back hair gathers into a knot at the occiput, visible from the board camera.
        previous = []
        for j in range(13):
            lat = -.499*pi + .998*pi*j/12
            ring = []
            for k in range(32):
                ang = tau*k/32
                flute = 1 + .048*sin(7*ang+lat*3)
                x = .185*cos(lat)*cos(ang)*flute
                z = -.666+.205*cos(lat)*sin(ang)*flute
                y = .196+.165*sin(lat)
                ring.append(vertex(blender((x,y,z)),(.72+.07*cos(ang)*cos(lat), .89+.055*sin(lat))))
            if previous: join(previous,ring)
            previous=ring
    # Sculpt each pinna around the temple, with an inset concha and raised helix.
    for side, index in ((-1,234),(1,454)):
        u,v,_=pts[index]
        ecx=u+side*.033
        ecy=v+.035
        rings=[]
        for radius, dep in ((.04,.038),(.44,.045),(.72,.095),(.92,.085),(1,.022),(.77,-.078),(.05,-.092)):
            row=[]
            for k in range(24):
                a=k*tau/24
                x=ecx+side*radius*(.040*cos(a)+.014*sin(a))
                y=ecy+.109*radius*sin(a)
                row.append(vertex(point(x,y,dep-.08),(x*.5,1-y)))
            if rings: join(rings[-1],row)
            rings.append(row)
        faces.extend([tuple(rings[0]),tuple(rings[-1])])

    mesh=bpy.data.meshes.new(name.title()+" facial planes")
    mesh.from_pydata(coords,[],faces)
    mesh.update()
    tex=mesh.uv_layers.new(name="Portrait")
    for poly in mesh.polygons:
        poly.use_smooth=True
        for loop in poly.loop_indices:
            vi=mesh.loops[loop].vertex_index
            tex.data[loop].uv=uv[vi]
        # Switch panels at the temple, keeping a hard UV seam out of the face.
        if any(uv[k][0] >= .5 for k in poly.vertices):
            for loop in poly.loop_indices:
                a,b=tex.data[loop].uv
                if a < .5: tex.data[loop].uv=(a+.5,b)
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    img=bpy.data.images.load(str(DIR/(name+".png")))
    img.pack()
    mat=bpy.data.materials.new(name.title()+" painted albedo")
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value=.70
    bsdf.inputs["Specular IOR Level"].default_value=.19
    paint=mat.node_tree.nodes.new("ShaderNodeTexImage")
    paint.image=img
    mat.node_tree.links.new(paint.outputs["Color"],bsdf.inputs["Base Color"])
    mesh.materials.append(mat)
    model=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(model)
    return model
