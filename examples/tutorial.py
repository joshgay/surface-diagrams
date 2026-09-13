"""Generate the tutorial's actual diagrams: python examples/tutorial.py."""
from pathlib import Path
from surface_diagrams import (
    Arc, Loop, PlanarSurface, Style, GenusSurface, TypeIBoundary, BoundaryPair,
    ColoredCurve, PlanarDiagram, BraidDiagram, Panel, Figure, RAINBOW, save_svg, save_tikz,
    FactorPanel, FactorizationDiagram,
)
from surface_diagrams.genus_diagrams import NamedCut, MarkedArc
from surface_diagrams.disk_routes import DiskRoute, Crossing, CutAtlas


def examples():
    row = PlanarSurface.row('PPPPPP', spacing=55, height=210, margin=60)
    guides = Style(show_guides=True)
    yield '01-input-map', row, guides
    yield '02-arcs-and-loops', Figure((
        (Panel(row.with_curves(Arc(2,5,cuts=(3,),direction='down')), 'Arc(2, 5, cuts=(3,), direction="down")', guides),),
        (Panel(row.with_curves(Loop((1,4))), 'Loop((1, 4)): surrounds objects 2, 3, 4', guides),),
        (Panel(row.with_curves(Loop((0,6,5,1))), 'Loop((0, 6, 5, 1)): a nonconsecutive enclosure', guides),),
    )), Style()
    holes = PlanarSurface.row('BPPB', spacing=65, height=180, margin=65)
    yield '03-boundary-endpoints', Figure((
        (Panel(holes.with_curves(Arc(0,1), Arc(1,2), Arc(3,4), Arc(4,5)),
               'Left/right rim endpoints: outer-to-hole and hole-to-point', Style(boundary_shape='circle', show_guides=True)),),
        (Panel(PlanarSurface.row('BB', spacing=100, height=140, margin=65).with_curves(Arc(1,2)),
               'Boundary-to-boundary: a straight arc joins facing rims', Style(boundary_shape='circle')),),
        (Panel(PlanarSurface.row('BB', spacing=100, height=220, margin=70).with_curves(
                   Arc(1,2,direction='up',start_side='left',end_side='right')),
               'Curved arc: explicit left start rim and right end rim', Style(boundary_shape='circle')),),
    )), Style()
    points = PlanarSurface.row('PPP', spacing=65, height=210, margin=65)
    cuts = tuple(ColoredCurve(f'c{i}', Arc(i-1,i), RAINBOW[i-1]) for i in range(1,5))
    yield '04-rainbow-planar-cuts', PlanarDiagram(points, cuts, show_legend=True), guides
    family = (ColoredCurve('a', Arc(1,4), RAINBOW[0]),
              ColoredCurve('b', Arc(3,6), RAINBOW[4]))
    individual = Figure(tuple((Panel(PlanarDiagram(row, (curve,)),
                                    f'Curve {curve.id}: same route and color'),) for curve in family))
    yield '05-intersecting-families', Figure((
        (Panel(PlanarDiagram(row, family, True, show_legend=True), 'Intersecting family'),
         Panel(individual, 'Inspect each component')),
        (Panel(PlanarDiagram(points, cuts+(ColoredCurve('twist-support',Loop((1,3)), '#222222'),),
                             True, show_legend=True),
               'Reference cuts and twist support (no action computed)'),),
    )), Style()
    yield '06-factorization-and-braids', Figure((
        (Panel(points.with_curves(Arc(1,2)), 'Factor 1: half twist supported on arc (1,2)'),
         Panel(BraidDiagram(3,(1,),spacing=45,step=96), 'Corresponding crossing: +1')),
        (Panel(points.with_curves(Arc(2,3)), 'Factor 2: half twist supported on arc (2,3)'),
         Panel(BraidDiagram(3,(2,),spacing=45,step=96), 'Corresponding crossing: +2')),
        (Panel(PlanarDiagram(points,cuts), 'Reference cuts C; image of product still to supply'),
         Panel(BraidDiagram(3,(1,2),spacing=45,step=48), 'Stacked crossings, read top to bottom')),
    )), Style()
    yield '07-standard-genus-cuts', Figure(tuple(
        (Panel(GenusSurface(g).with_cut_system(), f'Genus {g}: numbered standard filling chain'),)
        for g in (1,2,3)
    )), Style()
    surface = GenusSurface(2, marks=('P','Q'))
    arc = MarkedArc('P','Q',id='PQ')
    yield '08-genus-arc-and-chart', Figure((
        (Panel(surface.with_curves(arc), 'Straight visual arc from marked P to Q'),),
        (Panel(surface.with_cut_system(), 'Reference chain and mark attachments'),),
    )), Style()
    torus = GenusSurface(1)
    atlas = CutAtlas.build(torus.cut_system())
    crossing = atlas.crossing_on_cut(2, segment=1, bank='+', position=.37)
    loop = DiskRoute((crossing,),id='torus-loop')
    yield '09-genus-closed-curves', Figure((
        (Panel(GenusSurface(2).with_curves(NamedCut(2)), 'A known closed curve: NamedCut(2)'),),
        (Panel(torus.with_curves(loop), 'Explicit one-crossing torus route'),),
    )), Style()
    yield '10-boundary-surface-templates', Figure((
        (Panel(GenusSurface(2,type_i=(TypeIBoundary(6),)).boundary_guide(), 'Type I: vertical-plane rim attachments'),),
        (Panel(GenusSurface(2,type_ii=(BoundaryPair('left'),BoundaryPair('top'))).boundary_guide(), 'Type II: vertical-plane rim attachments'),),
    )), Style()
    yield '11-hurwitz-and-substitution', Figure((
        (Panel(BraidDiagram(3,(1,2)), '(a,b), a = +1 and b = +2'),
         Panel(BraidDiagram(3,(2,-2,1,2)), '(b, b^-1 a b): the first two crossings cancel')),
        (Panel(BraidDiagram(3,(1,2,1)), 'Substitution: braid relation, left word'),
         Panel(BraidDiagram(3,(2,1,2)), 'Braid relation, right word')),
    )), Style()

    yield '12-bordered-reference-families', Figure((
        (Panel(GenusSurface(2,type_i=(TypeIBoundary(1),TypeIBoundary(6))).with_reference_arcs(),
               'Type I end boundaries: vertical-plane reference arcs'),),
        (Panel(GenusSurface(2,type_i=(TypeIBoundary(2),TypeIBoundary(3),TypeIBoundary(4))).with_reference_arcs(),
               'Type I cusp boundaries: attached arcs and close rim enclosures'),),
        (Panel(GenusSurface(2,type_ii=(BoundaryPair('top'),)).with_reference_arcs(),
               'Type II top/bottom boundaries: vertical-plane spokes'),),
        (Panel(GenusSurface(2,type_ii=(BoundaryPair('left'),BoundaryPair('top'))).with_reference_arcs(),
               'Type II side and top/bottom pairs: inner-bank spokes'),),
    )), Style()
    marked = GenusSurface(2,type_i=(TypeIBoundary(6),),marks=('P','Q'))
    yield '13-bordered-marked-reference', marked.with_reference_arcs(
        mark_positions={'P':(-35,30),'Q':(35,-30)}), Style()
    family = GenusSurface(2,type_i=(TypeIBoundary(6),)).with_reference_arcs()
    yield '14-bordered-factor-panels', Figure((
        (Panel(family.select(2), 'Factor 1: positive twist supported on member 2'),),
        (Panel(family.select(4), 'Factor 2: positive twist supported on member 4'),),
        (Panel(family, 'Reference family; action images are not computed'),),
    )), Style()
    yield '15-mixed-boundary-views', Figure(tuple(
        tuple(Panel(GenusSurface(3,type_i=(TypeIBoundary(8),),
                    type_ii=(BoundaryPair('left'),BoundaryPair('top'),BoundaryPair('top')),
                    marks=('M',),view_vertical=vertical,view_horizontal=horizontal).with_reference_arcs(
                        mark_positions={'M':(0,45)}), f'{vertical} / {horizontal}')
              for horizontal in ('left','right'))
        for vertical in ('above','below')
    )), Style()

    # Application order is explicit; the continuous braid transports strand
    # colors across blocks, including the row containing an inverse factor.
    small = PlanarSurface.row('PPP', spacing=45, height=100, margin=40)
    a = PlanarDiagram(small, (ColoredCurve('c1', Arc(1,2), RAINBOW[0]),))
    b = PlanarDiagram(small, (ColoredCurve('c2', Arc(2,3), RAINBOW[4]),))
    yield '16-ordered-factorization', FactorizationDiagram((
        FactorPanel('a', Panel(a, 'Half twist on c1'), braid_word=(1,), group='block A'),
        FactorPanel('b', Panel(b, 'Inverse half twist on c2'), exponent=-1, braid_word=(-2,), group='block A'),
        FactorPanel('a-again', Panel(a, 'Same support c1; distinct factor ID'), braid_word=(1,), group='block B'),
    ), strands=3, braid_spacing=36), Style()

    # These two disjoint members are unchanged by twists supported on either
    # member. They are ONLY a subset, not a filling reference system or an
    # equality certificate for the product.
    subset = family.select(2,4)
    yield '17-supplied-action-states', FactorizationDiagram((
        FactorPanel('t2', Panel(family.select(2), 'Twist supported on member 2'),
                    state=Panel(subset, 'Selected members 2 and 4')),
        FactorPanel('t4', Panel(family.select(4), 'Inverse twist on member 4'), exponent=-1,
                    state=Panel(subset, 'Selected members 2 and 4')),
    ), initial_state=Panel(subset, 'Two disjoint members, not the full cut system')), Style()


def main(out=None):
    out = Path(out) if out else Path(__file__).parent/'output'/'tutorial'
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    tex = [r"\documentclass{article}", r"\usepackage{tikz,graphicx}",
           r"\usepackage[margin=15mm]{geometry}",
           # Fit both dimensions: tall factor/action stacks must not run off
           # the page when the gallery scales them to the full text width.
           r"\newsavebox{\diagram}",
           r"\newcommand{\tutorialfigure}[1]{%",
           r"  \sbox{\diagram}{\input{#1}}%",
           r"  \ifdim\wd\diagram>0.9\linewidth",
           r"    \sbox{\diagram}{\resizebox{0.9\linewidth}{!}{\usebox{\diagram}}}%",
           r"  \fi",
           r"  \ifdim\dimexpr\ht\diagram+\dp\diagram\relax>0.9\textheight",
           r"    \resizebox*{!}{0.9\textheight}{\usebox{\diagram}}%",
           r"  \else\usebox{\diagram}\fi}", r"\begin{document}"]
    for name, diagram, style in examples():
        save_svg(diagram, out/(name+'.svg'), style=style, title=name)
        save_tikz(diagram, out/(name+'.tikz'), style=style, title=name)
        tex.extend([r"\begin{center}", r"\tutorialfigure{"+name+r".tikz}",
                    r"\end{center}", r"\clearpage"])
        count += 1
    tex.append(r"\end{document}")
    (out/"tutorial-gallery.tex").write_text("\n".join(tex)+"\n", encoding="utf-8")
    torus = GenusSurface(1)
    atlas = CutAtlas.build(torus.cut_system())
    crossing = atlas.crossing_on_cut(2, segment=1, bank='+', position=.37)
    loop = DiskRoute((crossing,), id='torus-loop')
    save_svg(torus.cut_system().diagram(loop, show_segments=True), out/'09-torus-cut-disk-detail.svg',
             title='Full-resolution torus cut-disk diagnostic; zoom to read side labels')
    print(f'Generated {count} SVG tutorial figures plus a detailed cut-disk SVG and {count} TikZ counterparts in {out.resolve()}')


if __name__ == '__main__':
    main()
