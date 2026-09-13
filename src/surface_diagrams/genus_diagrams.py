"""Default-genus drawings carrying curves through a checked presentation mesh."""
from dataclasses import dataclass

from .genus_geometry import presentation
from .genus_mesh import genus_binding
from .mesh_atlas import cubic_point, _near, _segment_distance
from .primitives import Drawing, Path, Text, Ellipse
from .visuals import RAINBOW
from .disk_routes import DiskRoute, ItineraryError


@dataclass(frozen=True)
class BorderedReferenceDiagram:
    """Supplied vertical-plane reference arcs for Type I and top/bottom Type II.

    This presentation is independent of the certified closed-surface mesh;
    it is not accepted as a CutSystem or as a DiskRoute chart binding.
    """
    surface: object
    pair_bank: str = "a"

    def drawing(self, style):
        from dataclasses import replace
        surface=self.surface
        last=2*surface.genus+2
        side_pairs=[pair.side for pair in surface.type_ii if pair.side in ('left','right')]
        if len(side_pairs)!=len(set(side_pairs)):
            raise NotImplementedError('one Type II pair per side is currently supported')
        if side_pairs and self.pair_bank!='a':
            raise NotImplementedError('side Type II spokes currently use inner bank a')
        if any(fixed.slot in (1,last) for fixed in surface.type_i) and side_pairs:
            raise NotImplementedError('combined Type I end rims and side Type II spokes need separate binding')
        if self.pair_bank not in ('a','b'):
            raise ValueError("pair_bank must be 'a' or 'b'")
        if surface.marks:
            raise NotImplementedError('bordered marked-point reference arcs are not implemented yet')
        outline=presentation(surface)
        base=outline.drawing(style)
        paths,texts=list(base.paths),[]
        rims={rim.id:rim for rim in outline.rims}
        vy=1 if surface.view_vertical=='above' else -1

        def endpoint(slot, bank):
            if f'fixed-{slot}' in rims:
                return surface.boundary_anchor(f'fixed-{slot}',bank).point
            if slot in (1,last):
                tips=[path[0][1:] for path in outline.contours if abs(path[0][2])<1e-9]
                tips += [command[-2:] for path in outline.contours for command in path[1:]
                         if abs(command[-1])<1e-9]
                return (min(tips) if slot==1 else max(tips))
            hole=(slot-2)//2
            far=outline.handles[2*hole+1]
            return far[0][1:] if slot%2==0 else far[-1][-2:]

        members={}
        for number in range(1,2*surface.genus+2):
            begin=len(paths)
            color=RAINBOW[(number-1)%len(RAINBOW)]
            if number%2:
                # The corridor member joins consecutive vertical-plane slots.
                bordered=any(f'fixed-{slot}' in rims for slot in (number,number+1))
                for sign,bank in ((-vy,'a' if vy>0 else 'b'),(vy,'b' if vy>0 else 'a')):
                    start,end=endpoint(number,bank),endpoint(number+1,bank)
                    width=end[0]-start[0]
                    lift=sign*min(surface.height*.12,abs(width)*.32)
                    commands=(('M',*start),('C',start[0]+width/3,start[1]+lift,
                                end[0]-width/3,end[1]+lift,*end))
                    paths.append(Path(commands,color,style.curve_width,
                                      'boundary-reference-arc' if bordered else 'named-cut',sign==vy))
                texts.append(Text((start[0]+end[0])/2,(start[1]+end[1])/2+4*vy,
                                  str(number),color,10))
            elif any(f'fixed-{slot}' in rims for slot in (number,number+1)):
                # An opened cusp is wider than the old cusp. A small rounded
                # rectangle encloses the actual hole/rim control hulls with a
                # uniform gap, rather than cutting through an opened rim.
                hole=number//2-1
                controls=[tuple(cmd[i:i+2]) for path in outline.handles[2*hole:2*hole+2]
                          for cmd in path for i in range(1,len(cmd),2)]
                xs=[p[0] for p in controls]; ys=[p[1] for p in controls]
                for slot in (number,number+1):
                    rim=rims.get(f'fixed-{slot}')
                    if rim:
                        xs.extend((rim.x-rim.depth,rim.x+rim.depth))
                        ys.extend((-rim.radius,rim.radius))
                gap=surface.handle_spacing*.035
                points=_rounded_enclosure(min(xs),max(xs),min(ys),max(ys),gap)
                def plane_point(slot):
                    rim=rims.get(f'fixed-{slot}')
                    return (rim.x,rim.y) if rim else endpoint(slot,'a')
                pieces=_cusp_visibility((('front',points),),plane_point(number),plane_point(number+1),vy)
                _append_paths(paths,pieces,color,style.curve_width,'named-cut')
                texts.append(Text((min(xs)+max(xs))/2,max(ys)+gap+9,str(number),color,10))
            else:
                center=(number//2-1-(surface.genus-1)/2)*surface.handle_spacing
                radius=surface.handle_spacing*.335
                ry=min(surface.height*.17,surface.handle_spacing*.17)
                points=_ellipse_reference(center,radius,ry)
                far=outline.handles[number-1]
                pieces=_cusp_visibility((('front',points),),far[0][1:],far[-1][-2:],vy)
                _append_paths(paths,pieces,color,style.curve_width,'named-cut')
                texts.append(Text(center,ry+9,str(number),color,10))
            members[number]=tuple(paths[begin:])
        chain=tuple(p for p in paths if p.role in ('named-cut','boundary-reference-arc'))
        for index,rim in enumerate(r for r in outline.rims if r.role=='type-ii-boundary'):
            start=surface.boundary_anchor(rim.id,self.pair_bank).point
            if rim.normal[0]:
                number=1 if rim.x<0 else last-1
                upper=rim.y>0
                def midpoint(path):
                    command=path.commands[1]
                    return cubic_point((path.commands[0][1:],command[1:3],command[3:5],command[-2:]),.5)
                target=(max if upper else min)(members[number],key=lambda path:midpoint(path)[1])
                end=midpoint(target)
                inward=end[0]-start[0]
                commands=(('M',*start),('C',start[0]+.7*inward,start[1],
                            end[0],end[1]+.3*(start[1]-end[1]),*end))
                dashed=target.dashed
            else:
                hits=[]
                for path in chain:
                    for point in _vertical_hits(path.commands,start[0]):
                        if rim.y*(start[1]-point[1])>1e-8:
                            hits.append((abs(start[1]-point[1]),point,path.dashed))
                if not hits:
                    raise ItineraryError('Type II spoke misses the reference chain; change pair placement or bank')
                _,end,dashed=min(hits,key=lambda item:item[0])
                commands=(('M',*start),('L',*end))
            number=last+index
            color=RAINBOW[(number-1)%len(RAINBOW)]
            paths.append(Path(commands,color,style.curve_width,'boundary-reference-spoke',dashed))
            texts.append(Text(start[0]+8,(start[1]+end[1])/2,str(number),color,9))
        return replace(base,paths=tuple(paths),texts=tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


def _ellipse_reference(center,rx,ry):
    """The standard even wrap, sampled from its four cubic quarters."""
    k=.5522847498307936
    quarters=(((rx,0),(rx,k*ry),(k*rx,ry),(0,ry)),
              ((0,ry),(-k*rx,ry),(-rx,k*ry),(-rx,0)),
              ((-rx,0),(-rx,-k*ry),(-k*rx,-ry),(0,-ry)),
              ((0,-ry),(k*rx,-ry),(rx,-k*ry),(rx,0)))
    points=[]
    for quarter in quarters:
        for i in range(25):
            x,y=cubic_point(quarter,i/24)
            points.append((center+x,y))
    return tuple(points)


def _vertical_hits(commands,x):
    """Exact line hits and bisected monotone cubic hits, retaining actual paths."""
    point=None
    for command in commands:
        if command[0]=='M':
            point=command[1:]
            continue
        end=command[-2:]
        if min(point[0],end[0])-1e-9 <= x <= max(point[0],end[0])+1e-9:
            if abs(end[0]-point[0])<1e-10:
                if abs(x-point[0])<1e-9:
                    yield point
                    yield end
            elif command[0]=='L':
                t=(x-point[0])/(end[0]-point[0])
                yield (x,point[1]+t*(end[1]-point[1]))
            elif command[0]=='C':
                curve=(point,command[1:3],command[3:5],end)
                low,high=0.,1.
                increasing=end[0]>point[0]
                for _ in range(48):
                    mid=(low+high)/2
                    if (cubic_point(curve,mid)[0]<x)==increasing: low=mid
                    else: high=mid
                yield cubic_point(curve,(low+high)/2)
            else:
                raise ItineraryError('unsupported reference-spoke target geometry')
        point=end


def _rounded_enclosure(left,right,bottom,top,gap):
    """Polyline of a rounded offset box; the supplied hull stays inside it."""
    from math import cos,sin,pi
    points=[]
    for cx,cy,angle in ((right,top,0),(left,top,90),(left,bottom,180),(right,bottom,270)):
        for i in range(13):
            t=(angle+90*i/12)*pi/180
            points.append((cx+gap*cos(t),cy+gap*sin(t)))
    points.append(points[0])
    return tuple(points)


@dataclass(frozen=True)
class BoundaryGuide:
    """A visual inventory of actual vertical-plane rim attachments."""
    surface: object

    def drawing(self, style):
        from dataclasses import replace
        from .visuals import _shift
        if self.surface.marks:
            raise NotImplementedError('bordered marked-point plane bindings are not implemented yet')
        outline=presentation(self.surface)
        base=outline.drawing(style)
        if not outline.rims:
            return base
        rows=len(outline.rims)
        extra=20*rows+18
        moved=_shift(base,0,extra/2)
        ellipses,texts=list(moved.ellipses),list(moved.texts)
        for i,rim in enumerate(outline.rims,1):
            color=RAINBOW[(i-1)%len(RAINBOW)]
            for bank,point,direction in zip(('a','b'),rim.anchors,(-1,1)):
                x,y=point
                ellipses.append(Ellipse(x,y+extra/2,2,2,color,'none',0,'boundary-anchor'))
                texts.append(Text(x+direction*10*rim.tangent[0]+8*rim.normal[0],
                                  y+extra/2+direction*10*rim.tangent[1]+8*rim.normal[1]-3,
                                  str(i)+bank,color,8))
            y=-base.height/2+extra/2-20*i
            texts.append(Text(0,y,f'{i} = {rim.id}   (a / b)',color,10))
        width=max(base.width,max(len(r.id) for r in outline.rims)*8+120)
        return replace(moved,width=width,height=base.height+extra,
                       ellipses=tuple(ellipses),texts=tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


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
            # Visibility changes on the same cusp plane as the adjacent odd cuts.
            # The projected cusp line can be tilted and need not lie at y=0.
            if number%2 == 0 and parent.kind == 'closed':
                handle = presentation(self.surface).handles[number-1]
                left, right = handle[0][1:], handle[-1][-2:]
                sign=1 if self.surface.view_vertical == 'above' else -1
                pieces=_cusp_visibility(pieces,left,right,sign)
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


def _cusp_visibility(pieces, left, right, sign):
    """Split presentation polylines exactly where they cross the cusp plane."""
    def distance(point):
        x,y=point
        plane_y=left[1]+(right[1]-left[1])*(x-left[0])/(right[0]-left[0])
        return sign*(y-plane_y)
    result=[]
    for _,points in pieces:
        for a,b in zip(points,points[1:]):
            da,db=distance(a),distance(b)
            if da*db < 0:
                t=da/(da-db)
                crossing=(a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1]))
                result.extend((('front' if da>0 else 'back',(a,crossing)),
                               ('front' if db>0 else 'back',(crossing,b))))
            else:
                result.append(('front' if da+db>=0 else 'back',(a,b)))
    return result


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
