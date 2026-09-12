"""Default-genus drawings carrying curves through a checked presentation mesh."""
from dataclasses import dataclass

from .genus_geometry import presentation
from .genus_mesh import genus_binding
from .mesh_atlas import cubic_point, _near
from .primitives import Drawing, Path, Text
from .disk_routes import DiskRoute, ItineraryError


@dataclass(frozen=True)
class NamedCut:
    number: int

    def __post_init__(self):
        if type(self.number) is not int or self.number < 1:
            raise ValueError('named cut number must be a positive integer')


@dataclass(frozen=True)
class GenusDiagram:
    surface: object
    curves: tuple = ()
    show_cuts: bool = False
    intersections: tuple = ()

    def with_curves(self, *curves):
        return GenusDiagram(self.surface,self.curves+tuple(curves),self.show_cuts,self.intersections)

    def drawing(self, style):
        binding=genus_binding(self.surface)
        atlas,_=binding.charts()
        base=presentation(self.surface).drawing(style)
        paths,texts=list(base.paths),list(base.texts)
        parents={p.number:p for p in binding.system.cellulation.parents}
        numbers=list(parents) if self.show_cuts else []
        for curve in self.curves:
            if isinstance(curve,NamedCut):
                if curve.number not in parents:
                    raise ValueError('named cut number is outside the standard system')
                if curve.number not in numbers:
                    numbers.append(curve.number)
            elif not isinstance(curve,DiskRoute):
                raise TypeError('genus curves must be NamedCut or DiskRoute objects')
        geometry={t.face:t for t in binding.triangles}
        side_map={s:(geometry[f.id],i) for f in binding.system.cellulation.faces for i,s in enumerate(f.sides)}
        for number in numbers:
            parent=parents[number]
            pieces=[]
            for side in parent.walk:
                triangle,i=side_map[side]
                pts=(triangle.points[i],triangle.points[(i+1)%3])
                if i==0 and triangle.curved:
                    pts=tuple(cubic_point(triangle.curved,t/12) for t in range(13))
                pieces.append((triangle.sheet,pts))
            _append_paths(paths,pieces,style.curve_color,style.curve_width,'named-cut')
            if self.show_cuts:
                front=[p for sheet,pts in pieces if sheet=='front' for p in pts]
                if number%2:
                    x,y=front[len(front)//2]
                    y+=9*(1 if self.surface.view_vertical=='above' else -1)
                else:
                    x,y=max(front,key=lambda p:p[1])
                    y+=9
                texts.append(Text(x,y,str(number),style.curve_color,10))
        routes=tuple(c for c in self.curves if isinstance(c,DiskRoute))
        atlas.family(routes,intersections=self.intersections)
        for route in routes:
            pieces=binding.project(route)
            _append_paths(paths,[(p.sheet,p.points) for p in pieces],style.curve_color,style.curve_width,'surface-route')
        return Drawing(base.width,base.height,base.ellipses,tuple(paths),tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


def _append_paths(paths,pieces,color,width,role):
    sheet,commands=None,[]
    for current,points in pieces:
        if current!=sheet:
            if commands:
                paths.append(Path(tuple(commands),color,width,role,sheet=='back'))
            commands=[('M',*points[0])]
            sheet=current
        elif commands and not _near(tuple(commands[-1][-2:]),points[0]):
            raise ItineraryError('projected route pieces do not join')
        commands.extend(('L',*p) for p in points[1:])
    if commands:
        paths.append(Path(tuple(commands),color,width,role,sheet=='back'))
