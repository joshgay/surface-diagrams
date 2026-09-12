"""Closed-genus charts built as a doubled, holed planar mesh.

The chain graph and its projection share one triangulated cellulation. Boundary
and mark decorations require separate checked chart extensions.
"""
from collections import defaultdict
from functools import lru_cache
from math import hypot, ceil

from .cut_systems import Cellulation, Face, Intersection, ParentCut, SidePair, SurfaceSpec
from .standard_cuts import CutSystem
from .genus_geometry import presentation
from .mesh_atlas import MeshBinding, MeshTriangle, cubic_slice, harmonic, _star_positive
from .disk_routes import ItineraryError, _orient


@lru_cache(maxsize=16)
def genus_binding(surface):
    if surface.type_i or surface.type_ii:
        raise NotImplementedError('boundary chart binding is not implemented yet')
    if surface.genus > 7:
        raise ValueError('the current presentation mesh supports genus 1..7')
    drawing = presentation(surface)
    spacing = surface.handle_spacing
    rx, hy = surface.width/2, surface.height/2
    hr, hh = spacing*.30, min(hy*.22, spacing*.13)
    ring_height = (hh+hy)/2
    centers = [(i-(surface.genus-1)/2)*spacing for i in range(surface.genus)]
    xs = sorted({-rx, rx, *[x+d for x in centers for d in (-hr-spacing*.10, -hr, -hr*.5, 0., hr*.5, hr, hr+spacing*.10)]})
    refined_xs = [xs[0]]
    for a,b in zip(xs,xs[1:]):
        count=max(1,ceil((b-a)/(spacing*.10)))
        refined_xs.extend(a+(b-a)*i/count for i in range(1,count+1))
    xs=refined_xs
    ys = (-hy, -ring_height, -hh, 0., hh, ring_height, hy)
    coordinates = {(i,j):(x,y) for i,x in enumerate(xs) for j,y in enumerate(ys)}
    triangles, quadrilaterals = [], []
    for i in range(len(xs)-1):
        for j in range(len(ys)-1):
            x, y = (xs[i]+xs[i+1])/2, (ys[j]+ys[j+1])/2
            if any(abs(x-c)<hr and abs(y)<hh for c in centers):
                continue
            a,b,c,d = (i,j),(i+1,j),(i+1,j+1),(i,j+1)
            triangles.extend(((a,b,c),(a,c,d)))
            quadrilaterals.append((a,b,c,d))
    nodes = sorted({v for t in triangles for v in t})
    edge_faces = defaultdict(list)
    for t in triangles:
        for i,a in enumerate(t):
            b = t[(i+1)%3]
            edge_faces[tuple(sorted((a,b)))].append((a,b))
    boundary_edges = {e for e,fs in edge_faces.items() if len(fs)==1}
    def commands_cubic(commands):
        return (tuple(commands[0][1:]), tuple(commands[1][1:3]),
                tuple(commands[1][3:5]), tuple(commands[1][5:7]))
    outer = [commands_cubic(c) for c in drawing.contours]
    hole_curves = []
    vx = 1 if surface.view_horizontal=='right' else -1
    vy = 1 if surface.view_vertical=='above' else -1
    for i in range(surface.genus):
        near = commands_cubic(drawing.handles[2*i])
        far = commands_cubic(drawing.handles[2*i+1])
        near = cubic_slice(near,.085+.02*vx,.915+.02*vx)
        hole_curves.append((near,far) if vy>0 else (far,near))

    def curve(a,b):
        x,y = coordinates[a]; u,v = coordinates[b]
        if x==u and abs(x)==rx:
            left, upper = x<0, (y+v)>=0
            base = outer[(0 if left else 4)+(0 if upper else 1)]
            t0,t1 = abs(y)/hy,abs(v)/hy
        elif y==v and abs(y)==hy:
            base = outer[2 if y>0 else 3]
            def top_parameter(value):
                inner=(surface.genus-1)*spacing/2
                target=value if abs(value)<=inner else (1 if value>=0 else -1)*(inner+(abs(value)-inner)*(surface.genus*spacing/2-inner)/(rx-inner))
                from .mesh_atlas import cubic_point
                low,high=0.,1.
                for _ in range(48):
                    middle=(low+high)/2
                    if cubic_point(base,middle)[0]<target:
                        low=middle
                    else:
                        high=middle
                return (low+high)/2
            t0,t1 = top_parameter(x),top_parameter(u)
        else:
            i = next(i for i,c in enumerate(centers) if
                     c-hr-1e-8<=x<=c+hr+1e-8 and c-hr-1e-8<=u<=c+hr+1e-8)
            c = centers[i]
            base = hole_curves[i][0 if (y+v)>=0 else 1]
            def parameter(x,y):
                y = abs(y)
                if abs(x-(c-hr))<1e-8:
                    return y/(2*hh+2*hr)
                if abs(x-(c+hr))<1e-8:
                    return (2*hh+2*hr-y)/(2*hh+2*hr)
                return (hh+x-(c-hr))/(2*hh+2*hr)
            t0,t1 = parameter(x,y),parameter(u,v)
        return cubic_slice(base,t0,t1) if t0<t1 else tuple(reversed(cubic_slice(base,t1,t0)))
    fixed, boundary_curves = {}, {}
    for a,b in boundary_edges:
        c = curve(a,b)
        boundary_curves[a,b], boundary_curves[b,a] = c, tuple(reversed(c))
        for vertex,point in ((a,c[0]),(b,c[-1])):
            if vertex in fixed and hypot(point[0]-fixed[vertex][0],point[1]-fixed[vertex][1])>1e-7:
                raise ItineraryError('presentation boundary curves do not join consistently')
            fixed[vertex] = point
    from .genus_chain_geometry import smooth_chain_constraints
    chain_fixed,chain_curves=smooth_chain_constraints(surface,coordinates,triangles,fixed,centers,hr,hh,ring_height)
    projected={}
    all_curves={}
    for sheet in ('front','back'):
        constraints=dict(fixed)
        constraints.update(chain_fixed[sheet])
        positions=harmonic(nodes,triangles,constraints,coordinates)
        if not all(_orient(*(positions[v] for v in t))>1e-9 for t in triangles):
            raise ItineraryError('smooth chain constraints fold the presentation mesh: '+repr((sheet,[(tuple(coordinates[v] for v in t),tuple(positions[v] for v in t)) for t in triangles if _orient(*(positions[v] for v in t))<=1e-9][:2])))
        projected[sheet]=positions
        all_curves[sheet]=dict(boundary_curves)
        all_curves[sheet].update(chain_curves[sheet])
    faces, geometry, side_nodes = [], [], {}
    directed, mesh_edges = {}, defaultdict(list)
    midpoint_ids = {edge: ('mid', *edge) for edge in edge_faces}
    for sheet in ('front','back'):
        sheet_curves=all_curves[sheet]
        for index,t in enumerate(quadrilaterals):
            t = t if sheet=='front' else (t[0],t[3],t[2],t[1])
            center = ('center',index)
            polygon_points = tuple(projected[sheet][v] for v in t)
            sign = 1 if sheet=='front' else -1
            def valid_center(point):
                for j,a in enumerate(t):
                    b=t[(j+1)%4]
                    controls=sheet_curves.get((a,b))
                    if controls:
                        if not _star_positive(controls,point,sign):
                            return False
                    elif sign*_orient(projected[sheet][a],projected[sheet][b],point)<=1e-9:
                        return False
                return True
            center_point = tuple(sum(p[axis] for p in polygon_points)/4 for axis in (0,1))
            if not valid_center(center_point):
                # Intersect tangent half-planes to locate the curved cell's
                # visibility kernel; the exact Bernstein check below certifies
                # the candidate over each entire cubic, not just sample points.
                extent = surface.width + surface.height
                kernel = [(-extent,-extent),(extent,-extent),(extent,extent),(-extent,extent)]
                for j,a in enumerate(t):
                    b=t[(j+1)%4]
                    controls=sheet_curves.get((a,b))
                    tangents=[]
                    if controls:
                        from .mesh_atlas import cubic_point
                        for k in range(65):
                            u=k/64
                            point=cubic_point(controls,u)
                            tangent=tuple(3*((1-u)**2*(controls[1][axis]-controls[0][axis])+2*u*(1-u)*(controls[2][axis]-controls[1][axis])+u*u*(controls[3][axis]-controls[2][axis])) for axis in (0,1))
                            tangents.append((point,tangent))
                    else:
                        point=projected[sheet][a]
                        tangents.append((point,tuple(projected[sheet][b][axis]-point[axis] for axis in (0,1))))
                    for origin,direction in tangents:
                        def distance(p):
                            return sign*(direction[0]*(p[1]-origin[1])-direction[1]*(p[0]-origin[0]))-1e-8
                        clipped=[]
                        for p,q in zip(kernel,kernel[1:]+kernel[:1]):
                            dp,dq=distance(p),distance(q)
                            if dp>=0:
                                clipped.append(p)
                            if (dp>=0)!=(dq>=0):
                                ratio=dp/(dp-dq)
                                clipped.append(tuple(p[axis]+ratio*(q[axis]-p[axis]) for axis in (0,1)))
                        kernel=clipped
                if not kernel:
                    raise ItineraryError('curved mesh cell has no interior kernel: '+str((sheet,index)))
                center_point=tuple(sum(p[axis] for p in kernel)/len(kernel) for axis in (0,1))
                if not valid_center(center_point):
                    raise ItineraryError('curved mesh cell kernel could not be certified: '+str((sheet,index)))
            for j,a in enumerate(t):
                b = t[(j+1)%4]
                edge = tuple(sorted((a,b)))
                midpoint = midpoint_ids[edge]
                curve_controls = sheet_curves.get((a,b), ())
                if curve_controls:
                    from .mesh_atlas import cubic_point
                    mid_point = cubic_point(curve_controls,.5)
                else:
                    mid_point = tuple((projected[sheet][a][axis]+projected[sheet][b][axis])/2 for axis in (0,1))
                for half,(u,v,pu,pv) in enumerate(((a,midpoint,projected[sheet][a],mid_point),
                                                  (midpoint,b,mid_point,projected[sheet][b]))):
                    vs = (u,v,center)
                    face = f'{sheet}.{index}.{j}.{half}'
                    sides = tuple(face+'.s'+str(k) for k in range(3))
                    faces.append(Face(face,sides))
                    curved = cubic_slice(curve_controls,half*.5,(half+1)*.5) if curve_controls else ()
                    geometry.append(MeshTriangle(face,sheet,(pu,pv,center_point),curved))
                    for k,side in enumerate(sides):
                        start,end = vs[k],vs[(k+1)%3]
                        side_nodes[side] = (sheet,start,end)
                        directed[sheet,start,end] = side
                        key = (('seam',frozenset((start,end))) if k==0 and edge in boundary_edges
                               else (sheet,frozenset((start,end))))
                        mesh_edges[key].append(side)
    pairs, edge_id = [], {}
    for i,sides in enumerate(mesh_edges.values()):
        if len(sides)!=2:
            raise ItineraryError('presentation mesh has an unmatched seam')
        pair = SidePair(f'mesh-e{i}',*sides)
        pairs.append(pair)
        edge_id.update((s,pair.id) for s in sides)
    def gridpath(points,sheet):
        return tuple(side for a,b in zip(points,points[1:])
                     for side in (directed[sheet,a,midpoint_ids[tuple(sorted((a,b)))]],
                                  directed[sheet,midpoint_ids[tuple(sorted((a,b)))],b]))
    parents, crossings = [], []
    row = ys.index(0.)
    for i in range(surface.genus+1):
        left = -rx if i==0 else centers[i-1]+hr
        right = rx if i==surface.genus else centers[i]-hr
        points = [(j,row) for j,x in enumerate(xs) if left<=x<=right]
        walk = gridpath(points,'front')+gridpath(list(reversed(points)),'back')
        parents.append(ParentCut(f'c{2*i+1}',2*i+1,'closed',walk))
    for i,c in enumerate(centers):
        li,ri = xs.index(c-hr-spacing*.10),xs.index(c+hr+spacing*.10)
        bottom,top = ys.index(-ring_height),ys.index(ring_height)
        path = ([(j,bottom) for j in range(li,ri+1)]+
                [(ri,j) for j in range(bottom+1,top+1)]+
                [(j,top) for j in range(ri-1,li-1,-1)]+
                [(li,j) for j in range(top-1,bottom-1,-1)])
        parents.append(ParentCut(f'c{2*i+2}',2*i+2,'closed',gridpath(path,'front')))
        for vertex,other in (((li,row),2*i+1),((ri,row),2*i+3)):
            corner = next(s for s,(sheet,start,end) in side_nodes.items() if sheet=='front' and start==vertex)
            crossings.append(Intersection(corner,(f'c{other}',f'c{2*i+2}')))
    parents.sort(key=lambda p:p.number)
    cuts = tuple(edge_id[s] for p in parents for s in p.walk)
    cell = Cellulation(tuple(faces),tuple(pairs),cuts=cuts,parents=tuple(parents),intersections=tuple(crossings))
    system = CutSystem(cell,SurfaceSpec(f'default-genus-{surface.genus}',surface.genus))
    report = system.validate()
    if not report.certified or len(report.complement)!=2:
        raise ItineraryError('genus presentation chain failed certification: '+str(report.diagnostics))
    return MeshBinding(system,tuple(geometry))
