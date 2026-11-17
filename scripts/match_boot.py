"""A studded match boot with an integrated sole plate and crossed laces."""
from math import cos, pi, sin, tau

import bpy
from mathutils import Vector
from blender_export import blender


def match_boot():
    # Longitudinal lasts, from heel to toe: half-width, upper height, lateral camber.
    stations = [
        (-.53,.14,.28,0),(-.50,.23,.43,0),(-.38,.25,.49,0),
        (-.24,.247,.48,0),(-.10,.24,.435,.002),(.04,.25,.358,.004),
        (.19,.277,.278,.012),(.32,.286,.224,.018),(.45,.255,.182,.020),
        (.505,.187,.139,.014),(.535,.045,.093,0),
    ]
    pts, faces, colors = [], [], []
    segments = 32
    def shell(t, w, h, camber, z):
        side = cos(t)
        # Sole is a low flat plate, with a rounded upper swollen over the forefoot.
        rise = sin(t)
        y = (.054 + (h-.054)*rise**.72) if rise > 0 else (.054 + .049*rise)
        return (w*side + camber, y, z)
    for z,w,h,camber in stations:
        for j in range(segments):
            pts.append(blender(shell(tau*j/segments,w,h,camber,z)))
    for i in range(len(stations)-1):
        for j in range(segments):
            a=i*segments+j; b=i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
            # Lateral inlay travels diagonally over the leather sidewall.
            zone = min(j, abs(16-j))
            inlay = i in range(3,8) and j<=16 and .8 <= zone-(i-3)*.65 <= 2.2
            colors.append(1 if j>=16 else 2 if inlay else 0)
    faces.extend((tuple(range(segments)),tuple(range(len(pts)-segments,len(pts)))))
    colors.extend((0,0))
    def top(x,z):
        for a,b in zip(stations,stations[1:]):
            if z <= b[0]:
                t=(z-a[0])/(b[0]-a[0])
                w,h,c=(a[i]+(b[i]-a[i])*t for i in (1,2,3))
                return .054+(h-.054)*max(0,1-((x-c)/w)**2)**.36
        return .1
    for row in range(4):
        for flip in (-1,1):
            start=len(pts)
            for k in range(9):
                t=k/8
                x=(t-.5)*.21
                z=-.17+row*.066+flip*(t-.5)*.047
                y=top(x,z)+.005
                for j in range(6):
                    a=tau*j/6
                    pts.append(blender((x,y+.009*cos(a),z+.010*sin(a))))
            for k in range(8):
                for j in range(6):
                    a=start+k*6+j; b=start+k*6+(j+1)%6
                    faces.append((a,b,b+6,a+6)); colors.append(3)
    # Low conical studs, tucked under both the heel and the ball of the foot.
    for z in (-.36,.19,.36):
        for side in (-1,1):
            start=len(pts)
            for y,r in ((.026,.034),(-.023,.027)):
                for j in range(8):
                    a=tau*j/8
                    pts.append(blender((side*.155+r*cos(a),y,z+.041*sin(a))))
            for j in range(8):
                a=start+j;b=start+(j+1)%8
                faces.append((a,b,b+8,a+8));colors.append(1)
            faces.append(tuple(range(start+8,start+16)));colors.append(1)
    mesh=bpy.data.meshes.new("Football last and sole plate")
    mesh.from_pydata(pts,[],faces)
    mesh.update()
    for rgb in (0x273848,0x141F2A,0x79ABB4,0xD8E9E8):
        mat=bpy.data.materials.new("Boot %06X"%rgb)
        mat.diffuse_color=(*[((rgb>>shift)&255)/255 for shift in (16,8,0)],1)
        mesh.materials.append(mat)
    for poly, color in zip(mesh.polygons,colors):
        poly.material_index=color
        poly.use_smooth=True
    import bmesh
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj=bpy.data.objects.new("match_boot",mesh)
    bpy.context.collection.objects.link(obj)
    return obj
