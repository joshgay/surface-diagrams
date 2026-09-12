"""Checked triangulated presentation bindings and harmonic cut-disk charts.

Every triangle belongs to an explicit front/back sheet. The cut-disk embedding
uses positive graph weights and fixed convex boundary vertices, then verifies
all triangle orientations. Projection never reconnects an itinerary.
"""

from dataclasses import dataclass
from math import hypot, comb, isfinite
from functools import lru_cache

from .cut_systems import _prepare, _reconstruct
from .disk_routes import CutAtlas, ItineraryError, _orient


def harmonic(vertices, triangles, fixed, initial=None, tolerance=1e-11):
    """Solve the symmetric graph Dirichlet problem with conjugate gradients."""
    neighbours = {v: set() for v in vertices}
    for triangle in triangles:
        for i, a in enumerate(triangle):
            b = triangle[(i+1)%3]
            neighbours[a].add(b)
            neighbours[b].add(a)
    unknown = [v for v in vertices if v not in fixed]
    index = {v: i for i,v in enumerate(unknown)}
    degree = [len(neighbours[v]) for v in unknown]
    if any(d == 0 for d in degree):
        raise ItineraryError('mesh contains an isolated vertex')
    adjacent = [[index[n] for n in sorted(neighbours[v]) if n in index] for v in unknown]
    def multiply(x):
        return [degree[i]*x[i]-sum(x[j] for j in adjacent[i]) for i in range(len(x))]
    result = dict(fixed)
    if not unknown:
        return result
    axes = []
    for axis in range(2):
        rhs = [sum(fixed[n][axis] for n in sorted(neighbours[v]) if n in fixed) for v in unknown]
        x = [initial[v][axis] if initial else 0. for v in unknown]
        ax = multiply(x)
        residual = [b-a for b,a in zip(rhs,ax)]
        direction = residual[:]
        norm = sum(r*r for r in residual)
        threshold = tolerance*tolerance*max(1.,sum(b*b for b in rhs))
        for _ in range(max(100,4*len(x))):
            if norm <= threshold:
                break
            ad = multiply(direction)
            denominator = sum(p*q for p,q in zip(direction,ad))
            if denominator <= 0:
                raise ItineraryError('mesh Dirichlet system is singular')
            alpha = norm/denominator
            x = [v+alpha*p for v,p in zip(x,direction)]
            residual = [r-alpha*a for r,a in zip(residual,ad)]
            new_norm = sum(r*r for r in residual)
            beta = new_norm/norm
            direction = [r+beta*p for r,p in zip(residual,direction)]
            norm = new_norm
        else:
            raise ItineraryError('mesh harmonic solve did not converge')
        axes.append(x)
    result.update((v,(axes[0][i],axes[1][i])) for i,v in enumerate(unknown))
    return result


def cubic_point(c, t):
    u=1-t
    return tuple(u**3*c[0][i]+3*u*u*t*c[1][i]+3*u*t*t*c[2][i]+t**3*c[3][i] for i in range(2))


def cubic_slice(c, low, high):
    from .genus_geometry import _split
    if high < 1:
        c=_split(c,high)[0]
    if low:
        c=_split(c,low/high)[1]
    return c


@dataclass(frozen=True)
class MeshTriangle:
    face: str
    sheet: str
    points: tuple
    # If present, a cubic along the triangle's first oriented edge.
    curved: tuple = ()

    def project(self, barycentric):
        point = tuple(sum(w*p[i] for w,p in zip(barycentric,self.points)) for i in range(2))
        if self.curved:
            rho=barycentric[0]+barycentric[1]
            if rho>1e-14:
                t=barycentric[1]/rho
                curve=cubic_point(self.curved,t)
                linear=tuple((1-t)*self.points[0][i]+t*self.points[1][i] for i in range(2))
                point=tuple(point[i]+rho*(curve[i]-linear[i]) for i in range(2))
        return point


@dataclass(frozen=True)
class ProjectedPiece:
    points: tuple
    sheet: str
    route: str
    index: int


@dataclass(frozen=True)
class MeshBinding:
    system: object
    triangles: tuple

    def __post_init__(self):
        cell=self.system.cellulation
        face_map={f.id:f for f in cell.faces}
        geometry={t.face:t for t in self.triangles}
        if set(geometry)!=set(face_map) or len(geometry)!=len(self.triangles):
            raise ItineraryError('every cell face needs exactly one projection triangle')
        points={}
        curves={}
        for triangle in self.triangles:
            if triangle.sheet not in ('front','back') or len(triangle.points)!=3:
                raise ItineraryError('projection triangles need three points and a front/back sheet')
            if any(len(p)!=2 or any(not isfinite(v) for v in p) for p in triangle.points):
                raise ItineraryError('projection coordinates must be finite 2D points')
            sign=1 if triangle.sheet=='front' else -1
            if sign*_orient(*triangle.points)<=1e-10:
                raise ItineraryError('projection contains a flipped or degenerate triangle: '+triangle.face)
            face=face_map[triangle.face]
            if len(face.sides)!=3:
                raise ItineraryError('projection binding requires triangular cells')
            for i,side in enumerate(face.sides):
                points[side]=(triangle.points[i],triangle.points[(i+1)%3])
            if triangle.curved:
                if len(triangle.curved)!=4 or any(len(p)!=2 or any(not isfinite(v) for v in p) for p in triangle.curved):
                    raise ItineraryError('curved edges need four finite cubic control points')
                if not (_near(triangle.curved[0],triangle.points[0]) and _near(triangle.curved[-1],triangle.points[1])):
                    raise ItineraryError('curved edge endpoints do not match their triangle')
                if not _star_positive(triangle.curved,triangle.points[2],sign):
                    raise ItineraryError('curved projection triangle cannot be certified without a fold: '+repr(triangle))
                curves[face.sides[0]]=triangle.curved
        for pair in cell.pairs:
            a,b=points[pair.first],points[pair.second]
            if not (_near(a[0],b[1]) and _near(a[1],b[0])):
                raise ItineraryError('paired projection edge endpoints do not match: '+pair.id)
            if (pair.first in curves)!=(pair.second in curves):
                raise ItineraryError('paired edges disagree about curved geometry')
            if pair.first in curves and any(not _near(p,q) for p,q in zip(curves[pair.first],reversed(curves[pair.second]))):
                raise ItineraryError('paired curved seams do not match')

    @lru_cache(maxsize=16)
    def charts(self):
        atlas=CutAtlas.build(self.system)
        cell=self.system.cellulation
        data=_prepare(cell,self.system.surface)
        components, vertices, vertex_of=_reconstruct(cell,data,cell.cuts)
        face_map={f.id:f for f in cell.faces}
        geometry={t.face:t for t in self.triangles}
        if set(geometry)!=set(face_map) or len(geometry)!=len(self.triangles):
            raise ItineraryError('every cell face needs exactly one projection triangle')
        chart_data=[]
        for component, chart in zip(components,atlas.charts):
            faces=[face_map[f] for f in component.faces]
            if any(len(f.sides)!=3 for f in faces):
                raise ItineraryError('projection binding requires triangular cells')
            triangles=[tuple(vertex_of[s] for s in f.sides) for f in faces]
            fixed={vertex_of[s]:p for s,p in zip(chart.sides,chart.vertices)}
            nodes=sorted({v for t in triangles for v in t})
            uv=harmonic(nodes,triangles,fixed)
            for face,nodes in zip(faces,triangles):
                points=tuple(uv[v] for v in nodes)
                if _orient(*points)<=1e-14:
                    raise ItineraryError('cut-disk chart contains a folded or degenerate triangle')
                chart_data.append((chart.id,points,geometry[face.id]))
        return atlas,tuple(chart_data)

    def project(self, route, *, error=.015):
        if not isfinite(error) or error <= 0:
            raise ValueError('projection error must be finite and positive')
        atlas,charts=self.charts()
        routed=atlas.route(route)
        result=[]
        for piece in routed.pieces:
            fragments=[]
            for chart,uv,triangle in charts:
                if chart!=piece.chart:
                    continue
                start=_barycentric(uv,piece.start)
                end=_barycentric(uv,piece.end)
                lo,hi=0.,1.
                for a,b in zip(start,end):
                    difference=b-a
                    if abs(difference)<1e-14:
                        if a < -1e-10:
                            hi=-1
                    elif difference>0:
                        lo=max(lo,-a/difference)
                    else:
                        hi=min(hi,-a/difference)
                if hi-lo <= 1e-10:
                    continue
                low_weights=tuple(a+lo*(b-a) for a,b in zip(start,end))
                high_weights=tuple(a+hi*(b-a) for a,b in zip(start,end))
                points=flatten_segment(triangle,low_weights,high_weights,error)
                fragments.append((lo,hi,ProjectedPiece(tuple(points),triangle.sheet,route.id,piece.index)))
            fragments.sort(key=lambda x:(x[0],x[1]))
            covered=0.
            for lo,hi,fragment in fragments:
                if lo>covered+1e-7:
                    raise ItineraryError('route leaves its checked disk chart')
                if hi<=covered+1e-8:
                    continue  # A route lying on a mesh diagonal has two carriers.
                if lo<covered-1e-7:
                    raise ItineraryError('projection chart triangles overlap along the route')
                result.append(fragment)
                covered=hi
            if covered<1-1e-7:
                raise ItineraryError('route projection did not reach its endpoint')
        return tuple(result)


def _barycentric(triangle,point):
    a,b,c=triangle
    denominator=_orient(a,b,c)
    return (_orient(point,b,c)/denominator,_orient(a,point,c)/denominator,
            _orient(a,b,point)/denominator)


def _near(a,b):
    return hypot(a[0]-b[0],a[1]-b[1])<=1e-7


def _star_positive(curve,apex,sign,depth=0):
    # Bernstein coefficients of cross(B(t)-apex, B'(t)), degree five.
    # Strict positivity certifies the entire radial curved triangle, not samples.
    offsets=[(p[0]-apex[0],p[1]-apex[1]) for p in curve]
    derivative=[(3*(b[0]-a[0]),3*(b[1]-a[1])) for a,b in zip(curve,curve[1:])]
    coefficients=[]
    for k in range(6):
        total=0.
        for i in range(4):
            j=k-i
            if 0<=j<3:
                a,b=offsets[i],derivative[j]
                total+=comb(3,i)*comb(2,j)/comb(5,k)*(a[0]*b[1]-a[1]*b[0])*sign
        coefficients.append(total)
    if min(coefficients)>1e-12:
        return True
    if max(coefficients)<=1e-12 or depth>=10:
        return False
    return (_star_positive(cubic_slice(curve,0,.5),apex,sign,depth+1)
            and _star_positive(cubic_slice(curve,.5,1),apex,sign,depth+1))


def _bernstein_product(a, b):
    m,n=len(a)-1,len(b)-1
    return tuple(sum(comb(m,i)*comb(n,k-i)*a[i]*b[k-i]
                     for i in range(max(0,k-n),min(m,k)+1))/comb(m+n,k)
                 for k in range(m+n+1))


def _segment_distance(point, a, b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    length=dx*dx+dy*dy
    t=0. if not length else max(0.,min(1.,((point[0]-a[0])*dx+(point[1]-a[1])*dy)/length))
    return hypot(point[0]-a[0]-t*dx,point[1]-a[1]-t*dy)


def flatten_segment(triangle, start, end, error):
    """Flatten a radial cubic carrier using positive rational Bezier bounds.

    Multiplication by rho squared makes the projected line a homogeneous
    cubic. Positive weights put the whole curve in its control-point convex
    hull, providing a segment-wide bound instead of midpoint sampling.
    """
    if not isfinite(error) or error <= 0:
        raise ValueError('projection error must be finite and positive')
    def clean(weights):
        if min(weights)<-1e-7:
            raise ItineraryError('projected segment lies outside its triangle')
        values=tuple(max(0.,x) for x in weights)
        total=sum(values)
        return tuple(x/total for x in values)
    start,end=clean(start),clean(end)
    points=[triangle.project(start)]
    def flatten(a,b,depth=0):
        pa,pb=triangle.project(a),triangle.project(b)
        if not triangle.curved:
            points.append(pb)
            return
        u,v=(a[0],b[0]),(a[1],b[1])
        rho=(u[0]+v[0],u[1]+v[1])
        # A line reaching the apex is radial, hence projects to a straight line.
        if min(rho)==0:
            points.append(pb)
            return
        rho2=_bernstein_product(rho,rho)
        weights=_bernstein_product(rho2,(1.,1.))
        apex_term=_bernstein_product(rho2,(a[2],b[2]))
        u2,v2=_bernstein_product(u,u),_bernstein_product(v,v)
        coefficients=(_bernstein_product(u2,u),_bernstein_product(u2,v),
                      _bernstein_product(u,v2),_bernstein_product(v2,v))
        controls=tuple(tuple((apex_term[k]*triangle.points[2][axis]+
                              sum(factor*coefficient[k]*control[axis]
                                  for factor,coefficient,control in zip((1,3,3,1),coefficients,triangle.curved)))/weights[k]
                             for axis in (0,1)) for k in range(4))
        if max(_segment_distance(p,pa,pb) for p in controls)<=error:
            points.append(pb)
            return
        if depth>=24:
            raise ItineraryError('curved projection failed the rendering tolerance')
        middle=tuple((x+y)/2 for x,y in zip(a,b))
        flatten(a,middle,depth+1)
        flatten(middle,b,depth+1)
    flatten(start,end)
    return tuple(points)
