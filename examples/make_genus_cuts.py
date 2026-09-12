"""Regenerate closed-genus numbered chains and checked route examples."""
from pathlib import Path
from surface_diagrams import GenusSurface, save_svg
from surface_diagrams.genus_diagrams import NamedCut
from surface_diagrams.disk_routes import Crossing, DiskRoute, CutAtlas, MarkPoint

OUT = Path(__file__).parent / 'output'
for genus in (1, 2, 3, 5):
    surface = GenusSurface(genus)
    save_svg(surface.with_cut_system(), OUT / f'genus-chain-{genus}.svg')
for number in range(1, 6):
    save_svg(GenusSurface(2).with_curves(NamedCut(number)), OUT / f'genus-two-member-{number}.svg')
surface = GenusSurface(1)
atlas = CutAtlas.build(surface.cut_system())
side = next(s for s in atlas.pairs if atlas.sides[s].id == atlas.sides[atlas.cross(Crossing(s)).side].id)
route = DiskRoute((Crossing(side, .37),), id='torus-loop')
save_svg(surface.with_curves(route), OUT / 'genus-torus-route.svg')
save_svg(surface.cut_system().diagram(route), OUT / 'genus-torus-route-disks.svg')

surface = GenusSurface(2, marks=('P', 'Q'))
route = DiskRoute((), MarkPoint('P'), MarkPoint('Q'), id='PQ')
save_svg(surface.with_cut_system(), OUT / 'genus-marked-cuts.svg')
save_svg(surface.with_curves(route), OUT / 'genus-marked-arc.svg')
save_svg(surface.cut_system().diagram(route), OUT / 'genus-marked-disks.svg')

# Fixed oriented mesh locators: a loop through both handles and a transverse
# loop through the left handle. The intersection is declared, never inferred
# from an overlap of front/back strokes in the SVG.
surface = GenusSurface(2)
long_route = DiskRoute((Crossing('front.3.0.0.s0', .23),
                       Crossing('front.126.2.1.s0', .63)), id='long')
atlas = CutAtlas.build(surface.cut_system())
parent = next(p for p in atlas.system.cellulation.parents if p.number == 2)
side = next(s for s in parent.walk if atlas.sides[s].id == atlas.sides[atlas.cross(Crossing(s)).side].id)
short_route = DiskRoute((Crossing(side, .37),), id='short')
intersections = ((('long', 0), ('short', 0)),)
save_svg(surface.with_curves(long_route), OUT / 'genus-multiple-handles.svg')
save_svg(surface.with_curves(long_route, short_route, intersections=intersections), OUT / 'genus-intersection.svg')
save_svg(surface.cut_system().diagram(long_route, short_route, intersections=intersections), OUT / 'genus-intersection-disks.svg')

separating = DiskRoute((Crossing('front.71.0.0.s0', .23),
                       Crossing('front.76.2.1.s0', .63)), id='separating')
repeated = DiskRoute((Crossing('front.3.0.0.s0', .25),
                     Crossing('front.31.0.0.s0', .25),
                     Crossing('front.31.0.0.s0', .75),
                     Crossing('front.70.2.1.s0', .75)), id='repeat')
save_svg(surface.with_curves(separating), OUT / 'genus-separating.svg')
save_svg(surface.with_curves(repeated), OUT / 'genus-repeated-crossings.svg')
parent = next(p for p in atlas.system.cellulation.parents if p.number == 4)
side = next(s for s in parent.walk if atlas.sides[s].id == atlas.sides[atlas.cross(Crossing(s)).side].id)
right = DiskRoute((Crossing(side, .37),), id='right')
save_svg(surface.with_curves(short_route, right), OUT / 'genus-disjoint.svg')
