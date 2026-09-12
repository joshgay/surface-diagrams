import unittest
from surface_diagrams import GenusSurface, BoundaryPair
from surface_diagrams.genus_geometry import presentation
from surface_diagrams.genus_outer_mesh import PairedOuterChart
from surface_diagrams.mesh_atlas import _near


class OuterChartTests(unittest.TestCase):
    def test_refined_edges_have_matching_seams_and_named_rim_halves(self):
        for genus,count in ((1,1),(2,1),(3,2),(5,3)):
            for vertical in ('above','below'):
                for horizontal in ('left','right'):
                    with self.subTest(genus=genus,count=count,vertical=vertical,horizontal=horizontal):
                        surface=GenusSurface(genus,type_ii=(BoundaryPair(),)*count,
                                             view_vertical=vertical,view_horizontal=horizontal)
                        drawing=presentation(surface)
                        chart=PairedOuterChart(surface,drawing)
                        rx,hy=surface.width/2,surface.height/2
                        xs,ys=chart.refine((-rx,0.,rx),(-hy,0.,hy))
                        edges=[((a,y),(b,y)) for y in (-hy,hy) for a,b in zip(xs,xs[1:])]
                        edges += [((x,a),(x,b)) for x in (-rx,rx) for a,b in zip(ys,ys[1:])]
                        boundaries=set()
                        for a,b in edges:
                            front,name=chart.edge(a,b,'front')
                            back,other=chart.edge(a,b,'back')
                            self.assertEqual(name,other)
                            if name:
                                boundaries.add(name)
                            else:
                                self.assertTrue(all(_near(p,q) for p,q in zip(front,back)))
                            reverse,_=chart.edge(b,a,'front')
                            self.assertTrue(all(_near(p,q) for p,q in zip(front,reversed(reverse))))
                        self.assertEqual(boundaries,{r.id for r in drawing.rims})

    def test_public_boundary_binding_stays_explicitly_unsupported(self):
        with self.assertRaises(NotImplementedError):
            GenusSurface(2,type_ii=(BoundaryPair(),)).cut_system()
