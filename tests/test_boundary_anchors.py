import unittest
from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair, Style, render_svg, render_tikz
from surface_diagrams.genus_geometry import presentation
from surface_diagrams.layout import layout


class BoundaryAnchorTests(unittest.TestCase):
    def test_actual_rim_endpoints_and_identity_in_all_views(self):
        expected=None
        for vertical in ('above','below'):
            for horizontal in ('left','right'):
                surface=GenusSurface(2,type_i=(TypeIBoundary(2),TypeIBoundary(6)),
                    type_ii=(BoundaryPair('top'),),view_vertical=vertical,view_horizontal=horizontal)
                anchors=surface.boundary_anchors()
                self.assertEqual(len(anchors),8)
                ids=tuple(a.id for a in anchors)
                if expected is None: expected=ids
                self.assertEqual(ids,expected)
                for rim in presentation(surface).rims:
                    for bank,point in zip(('a','b'),rim.anchors):
                        anchor=surface.boundary_anchor(rim.id,bank)
                        self.assertEqual(anchor.point,point)
                        self.assertEqual(anchor.id,rim.id+':'+bank)
                        # Both drawn half-rims end at precisely these attachments.
                        for sign in (-1,1):
                            self.assertIn(point,(rim.half(sign)[0][1:],rim.half(sign)[-1][-2:]))
                d=layout(surface.boundary_guide(),Style())
                self.assertEqual(sum(e.role=='boundary-anchor' for e in d.ellipses),8)
                self.assertIn('boundary-anchor',render_svg(surface.boundary_guide()))
                self.assertIn('boundary-anchor',render_tikz(surface.boundary_guide()))
                with self.assertRaises(ValueError): surface.boundary_anchor('missing','a')
                with self.assertRaises(ValueError): surface.boundary_anchor('fixed-2','front')

    def test_no_false_mark_or_cut_binding(self):
        self.assertEqual(GenusSurface().boundary_anchors(),())
        surface=GenusSurface(2,type_ii=(BoundaryPair('left'),),marks=('P',))
        with self.assertRaises(NotImplementedError): render_svg(surface.boundary_guide())
        with self.assertRaises(NotImplementedError): surface.cut_system()

    def test_end_reference_arcs_meet_rims_and_cusps_in_all_views(self):
        for vertical in ('above','below'):
            for horizontal in ('left','right'):
                surface=GenusSurface(2,type_i=(TypeIBoundary(1),TypeIBoundary(6)),
                                    view_vertical=vertical,view_horizontal=horizontal)
                d=layout(surface.with_reference_arcs(),Style())
                arcs=[p for p in d.paths if p.role=='boundary-reference-arc']
                self.assertEqual(len(arcs),4)
                self.assertEqual(sum(p.dashed for p in arcs),2)
                endpoints={p.commands[0][1:] for p in arcs}|{p.commands[-1][-2:] for p in arcs}
                self.assertTrue({a.point for a in surface.boundary_anchors()} <= endpoints)
                outline=presentation(surface)
                self.assertEqual(endpoints - {a.point for a in surface.boundary_anchors()},
                    {outline.handles[1][0][1:],outline.handles[-1][-1][-2:]})
                self.assertIn('boundary-reference-arc',render_tikz(surface.with_reference_arcs()))
                with self.assertRaises(NotImplementedError): surface.cut_system()
        for surface in (GenusSurface(type_ii=(BoundaryPair('left'),BoundaryPair('left'))),):
            with self.assertRaises(NotImplementedError): render_svg(surface.with_reference_arcs())

    def test_all_type_i_slots_attach_and_opened_rims_stay_inside_wrap(self):
        from surface_diagrams.mesh_atlas import cubic_point
        from surface_diagrams.visuals import RAINBOW
        for view in ('above','below'):
            surface=GenusSurface(2,type_i=tuple(TypeIBoundary(i) for i in range(1,7)),view_vertical=view)
            drawing=layout(surface.with_reference_arcs(),Style())
            arcs=[p for p in drawing.paths if p.role=='boundary-reference-arc']
            self.assertEqual(len(arcs),6)
            ends={p.commands[0][1:] for p in arcs}|{p.commands[-1][-2:] for p in arcs}
            self.assertEqual(ends,{a.point for a in surface.boundary_anchors()})
            for number in (2,4):
                wrap=[p for p in drawing.paths if p.role=='named-cut' and p.stroke==RAINBOW[number-1]]
                points=[cmd[-2:] for p in wrap for cmd in p.commands]
                for rim in presentation(surface).rims:
                    if rim.id not in (f'fixed-{number}',f'fixed-{number+1}'): continue
                    for sign in (-1,1):
                        commands=rim.half(sign)
                        start=commands[0][1:]
                        for command in commands[1:]:
                            curve=(start,command[1:3],command[3:5],command[5:7])
                            for i in range(31):
                                x,y=cubic_point(curve,i/30)
                                # Ray casting against the actual rounded wrap,
                                # not merely its bounding rectangle.
                                crossings=0
                                for a,b in zip(points,points[1:]+points[:1]):
                                    if (a[1]>y)!=(b[1]>y):
                                        hit=a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1])
                                        crossings += hit>x
                                self.assertEqual(crossings%2,1)
                                self.assertLess(min(p[0] for p in points),x)
                                self.assertGreater(max(p[0] for p in points),x)
                                self.assertLess(min(p[1] for p in points),y)
                                self.assertGreater(max(p[1] for p in points),y)
                            start=command[-2:]

    def test_top_bottom_pair_spokes_hit_the_actual_chain(self):
        from surface_diagrams.genus_diagrams import _vertical_hits
        for view in ('above','below'):
            for bank in ('a','b'):
                surface=GenusSurface(2,type_i=(TypeIBoundary(2),),
                    type_ii=(BoundaryPair('top'),),view_vertical=view)
                d=layout(surface.with_reference_arcs(pair_bank=bank),Style())
                spokes=[p for p in d.paths if p.role=='boundary-reference-spoke']
                self.assertEqual(len(spokes),2)
                anchors={surface.boundary_anchor(f'pair-1-{side}',bank).point for side in ('upper','lower')}
                self.assertEqual({p.commands[0][1:] for p in spokes},anchors)
                chain=[p for p in d.paths if p.role in ('named-cut','boundary-reference-arc')]
                for spoke in spokes:
                    a,b=spoke.commands[0][1:],spoke.commands[-1][1:]
                    self.assertAlmostEqual(a[0],b[0])
                    self.assertGreater(abs(a[1]),abs(b[1]))
                    self.assertTrue(any(abs(b[0]-hit[0])+abs(b[1]-hit[1])<1e-7
                                        for p in chain for hit in _vertical_hits(p.commands,a[0])))
                self.assertIn('boundary-reference-spoke',render_tikz(surface.with_reference_arcs(pair_bank=bank)))
        with self.assertRaises(ValueError):
            render_svg(GenusSurface(type_ii=(BoundaryPair('top'),)).with_reference_arcs(pair_bank='front'))

    def test_vertical_cubic_hit_is_not_a_sampled_approximation(self):
        from surface_diagrams.genus_diagrams import _vertical_hits
        commands=(('M',0.,0.),('C',1.,1.,2.,1.,3.,0.))
        hit,=tuple(_vertical_hits(commands,1.5))
        self.assertAlmostEqual(hit[0],1.5,places=12)
        self.assertAlmostEqual(hit[1],.75,places=12)

    def test_side_pair_spokes_use_inner_rim_banks_and_actual_midpoints(self):
        from surface_diagrams.mesh_atlas import cubic_point
        for side in ('left','right'):
            for view in ('above','below'):
                surface=GenusSurface(2,type_ii=(BoundaryPair(side),),view_vertical=view)
                d=layout(surface.with_reference_arcs(),Style())
                spokes=[p for p in d.paths if p.role=='boundary-reference-spoke']
                self.assertEqual(len(spokes),2)
                expected={surface.boundary_anchor(f'pair-1-{sign}','a').point for sign in ('upper','lower')}
                self.assertEqual({p.commands[0][1:] for p in spokes},expected)
                mids=[]
                for path in d.paths:
                    if path.role=='named-cut' and len(path.commands)==2 and path.commands[1][0]=='C':
                        cmd=path.commands[1]
                        mids.append(cubic_point((path.commands[0][1:],cmd[1:3],cmd[3:5],cmd[-2:]),.5))
                for spoke in spokes:
                    self.assertIn(spoke.commands[-1][-2:],mids)
                    self.assertEqual(spoke.commands[1][0],'C')
                self.assertIn('boundary-reference-spoke',render_svg(surface.with_reference_arcs()))
        with self.assertRaises(NotImplementedError):
            render_svg(GenusSurface(type_ii=(BoundaryPair('left'),)).with_reference_arcs(pair_bank='b'))

    def test_reference_presentation_does_not_require_closed_mesh(self):
        from unittest.mock import patch
        surface=GenusSurface(2,type_ii=(BoundaryPair('left'),))
        with patch('surface_diagrams.genus_diagrams.genus_binding',side_effect=AssertionError('mesh requested')):
            self.assertIn('boundary-reference-spoke',render_svg(surface.with_reference_arcs()))
