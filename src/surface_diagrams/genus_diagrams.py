"""Default-genus drawings carrying curves through a checked presentation mesh."""
from dataclasses import dataclass

from .genus_geometry import presentation
from .genus_mesh import genus_binding
from .mesh_atlas import cubic_point, _near, _segment_distance
from .primitives import Drawing, Path, Text, Ellipse
from .visuals import RAINBOW
from .disk_routes import DiskRoute, ItineraryError


@dataclass(frozen=True)
class NamedCut:
    number: int

    def __post_init__(self):
        if type(self.number) is not int or self.number < 1:
            raise ValueError('named cut number must be a positive integer')


@dataclass(frozen=True)
class MarkedArc:
    """A straight visual arc between automatic genus marks in the clear upper band.

    This is a supplied presentation arc, not a cut-disk itinerary. DiskRoute
    remains available when a particular winding/crossing sequence is required.
    """
    start: str
    end: str
    id: str = None

    def __post_init__(self):
        if self.id is None:
            object.__setattr__(self,'id',f'{self.start}-{self.end}')
        if any(not isinstance(s,str) or not s for s in (self.start,self.end,self.id)):
            raise ValueError('mark names and arc ID must be nonempty strings')
        if self.start == self.end:
            raise ValueError('a marked arc needs distinct endpoints')


@dataclass(frozen=True)
class GenusDiagram:
    surface: object
    curves: tuple = ()
    show_cuts: bool = False
    intersections: tuple = ()

    def with_curves(self, *curves, intersections=()):
        return GenusDiagram(self.surface,self.curves+tuple(curves),self.show_cuts,self.intersections+tuple(intersections))

    def drawing(self, style):
        binding=genus_binding(self.surface)
        atlas,_=binding.charts()
        base=presentation(self.surface).drawing(style)
        paths,texts=list(base.paths),list(base.texts)
        ellipses=list(base.ellipses)
        parents={p.number:p for p in binding.system.cellulation.parents}
        numbers=list(parents) if self.show_cuts else []
        for curve in self.curves:
            if isinstance(curve,NamedCut):
                if curve.number not in parents:
                    raise ValueError('named cut number is outside the standard system')
                if curve.number not in numbers:
                    numbers.append(curve.number)
            elif not isinstance(curve,(DiskRoute,MarkedArc)):
                raise TypeError('genus curves must be NamedCut, MarkedArc or DiskRoute objects')
        geometry={t.face:t for t in binding.triangles}
        side_map={s:(geometry[f.id],i) for f in binding.system.cellulation.faces for i,s in enumerate(f.sides)}
        mark_points={}
        for mark in binding.system.cellulation.marks:
            triangle,index=side_map[mark.corner]
            x,y=triangle.points[index]
            mark_points[mark.id]=(x,y)
            ellipses.append(Ellipse(x,y,style.marked_point_radius,style.marked_point_radius,
                                    style.marked_point_color,style.marked_point_color,0,'marked-point'))
            texts.append(Text(x+7,y+2,mark.id,style.marked_point_color,9))
        for number in numbers:
            parent=parents[number]
            color=RAINBOW[(number-1)%len(RAINBOW)] if self.show_cuts else style.curve_color
            pieces=[]
            for side in parent.walk:
                triangle,i=side_map[side]
                pts=(triangle.points[i],triangle.points[(i+1)%3])
                if i==0 and triangle.curved:
                    pts=tuple(cubic_point(triangle.curved,t/12) for t in range(13))
                pieces.append((triangle.sheet,pts))
            # The named handle wrap has its own presentation visibility:
            # above view: solid upper half, dashed lower half. Chart sheet
            # membership is topological data and is not changed by this style.
            if number%2 == 0 and parent.kind == 'closed':
                sign=1 if self.surface.view_vertical == 'above' else -1
                pieces=[('front' if sign*sum(y for x,y in pts)>=0 else 'back',pts)
                        for sheet,pts in pieces]
            _append_paths(paths,pieces,color,style.curve_width,'named-cut')
            if self.show_cuts:
                front=[p for sheet,pts in pieces if sheet=='front' for p in pts]
                if parent.kind == 'arc':
                    x,y=front[len(front)//2]
                    x+=9
                    y-=5
                elif number%2:
                    x,y=front[len(front)//2]
                    y+=9*(1 if self.surface.view_vertical=='above' else -1)
                else:
                    x,y=max(front,key=lambda p:p[1])
                    y+=9
                texts.append(Text(x,y,str(number),color,10))
        marked_arcs=tuple(c for c in self.curves if isinstance(c,MarkedArc))
        routes=tuple(c for c in self.curves if isinstance(c,DiskRoute))
        if marked_arcs and (routes or self.intersections):
            raise ItineraryError('use separate panels for visual MarkedArc and explicit DiskRoute families')
        if len({a.id for a in marked_arcs}) != len(marked_arcs):
            raise ValueError('marked arc IDs must be distinct')
        # Every allowed straight segment lies in this convex rectangle, which
        # is above all hole control hulls and below the flat body's top contour.
        outline=presentation(self.surface)
        hole_top=max(v for c in outline.handles for command in c for v in command[2::2])
        upper=self.surface.height*.44*.99
        drawn_arcs=[]
        for arc in marked_arcs:
            if arc.start not in mark_points or arc.end not in mark_points:
                raise ValueError('unknown marked arc endpoint')
            a,b=mark_points[arc.start],mark_points[arc.end]
            if not all(abs(x)<self.surface.genus*self.surface.handle_spacing/2
                       and hole_top+style.curve_width/2<y<upper-style.curve_width/2 for x,y in (a,b)):
                raise ItineraryError('straight marked arc needs a clear upper corridor; use an explicit DiskRoute')
            for name,point in mark_points.items():
                if name not in (arc.start,arc.end) and _segment_distance(point,a,b)<=style.marked_point_radius+style.curve_width/2:
                    raise ItineraryError('straight marked arc meets another mark; use consecutive marks or an explicit DiskRoute')
            from .disk_routes import _orient
            for c,d in drawn_arcs:
                orientations=(_orient(a,b,c),_orient(a,b,d),_orient(c,d,a),_orient(c,d,b))
                if orientations[0]*orientations[1]<-1e-10 and orientations[2]*orientations[3]<-1e-10:
                    raise ItineraryError('straight marked arcs intersect; use explicit DiskRoutes for declared intersections')
                if max(abs(v) for v in orientations)<1e-8:
                    axis=0 if abs(b[0]-a[0])>=abs(b[1]-a[1]) else 1
                    lo=max(min(a[axis],b[axis]),min(c[axis],d[axis]))
                    hi=min(max(a[axis],b[axis]),max(c[axis],d[axis]))
                    if hi-lo>1e-8:
                        raise ItineraryError('straight marked arcs overlap')
            drawn_arcs.append((a,b))
            paths.append(Path((('M',*a),('L',*b)),style.curve_color,style.curve_width,'surface-route'))
        atlas.family(routes,intersections=self.intersections)
        for route in routes:
            pieces=binding.project(route)
            _append_paths(paths,[(p.sheet,p.points) for p in pieces],style.curve_color,style.curve_width,'surface-route')
        return Drawing(base.width,base.height,tuple(ellipses),tuple(paths),tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


def _append_paths(paths,pieces,color,width,role):
    sheet,commands=None,[]
    previous=None
    for current,points in pieces:
        if previous is not None and not _near(previous,points[0]):
            raise ItineraryError('projected route pieces do not join')
        previous=points[-1]
        if current!=sheet:
            if commands:
                paths.append(Path(tuple(commands),color,width,role,sheet=='back'))
            commands=[('M',*points[0])]
            sheet=current
        commands.extend(('L',*p) for p in points[1:])
    if commands:
        paths.append(Path(tuple(commands),color,width,role,sheet=='back'))
