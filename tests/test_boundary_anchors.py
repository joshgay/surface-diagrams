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
                self.assertEqual({p.commands[0][1:] for p in arcs},
                                 {a.point for a in surface.boundary_anchors()})
                outline=presentation(surface)
                self.assertEqual({p.commands[-1][-2:] for p in arcs},
                    {outline.handles[1][0][1:],outline.handles[-1][-1][-2:]})
                self.assertIn('boundary-reference-arc',render_tikz(surface.with_reference_arcs()))
                with self.assertRaises(NotImplementedError): surface.cut_system()
        for surface in (GenusSurface(type_i=(TypeIBoundary(2),)),
                        GenusSurface(type_ii=(BoundaryPair('top'),))):
            with self.assertRaises(NotImplementedError): render_svg(surface.with_reference_arcs())
