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
