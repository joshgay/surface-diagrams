import math
from dataclasses import replace
from pathlib import Path
import tempfile
import unittest
from xml.etree import ElementTree as ET

from surface_diagrams import (Arc, Loop, Boundary, MarkedPoint, PlanarSurface,
                              Style, RoutingError, render_svg, save_tikz)
from surface_diagrams.curves import HalfEllipse, _rim_parameter, route
from surface_diagrams.layout import layout

NS = '{http://www.w3.org/2000/svg}'


class CircularBoundaryTest(unittest.TestCase):
    def setUp(self):
        self.style = Style(boundary_shape='circle')
        self.row = PlanarSurface.row('BBBBBB',spacing=55,height=210,margin=60)

    def test_simple_defaults_and_point_identity(self):
        self.assertEqual(Style().boundary_radius,4)
        self.assertEqual(self.style.boundary_radius,12)
        d = layout(PlanarSurface.row('BPB'),self.style)
        holes = [s for s in d.ellipses if s.role == 'inner-boundary-circle']
        marks = [s for s in d.ellipses if s.role == 'marked-point']
        self.assertEqual(len(holes),2)
        self.assertEqual(len(marks),1)
        self.assertEqual(marks[0].fill,Style().marked_point_color)
        self.assertTrue(all(s.fill == 'none' and s.rx == 12 for s in holes))
        with self.assertRaises(ValueError):
            Style(boundary_shape='square')

    def test_analytical_endpoint_trim_across_aspects_and_directions(self):
        for aspect in (.1,.7,1.,2.,5.):
            for start,end in ((0,100),(100,0)):
                for up in (True,False,None):
                    piece = HalfEllipse(start,end,up,aspect,0,0,1)
                    for radius in (1,12,49,90):
                        t = _rim_parameter(piece,radius)
                        x,y = piece.point(t)
                        self.assertAlmostEqual(math.hypot(x-start,y),radius,places=8)
                        for j in range(1,20):
                            x,y = piece.point(t*j/20)
                            self.assertLess(math.hypot(x-start,y),radius)

    def test_actual_svg_arc_center_is_preserved_after_trimming(self):
        # Reconstruct the ellipse center from SVG endpoint-form parameters,
        # independently of the router's center or trimming calculation.
        for start,end in ((1,6),(6,1)):
            for direction in ('up','down'):
                s = self.row.with_curves(Arc(start,end,direction=direction))
                path = next(p for p in layout(s,self.style).paths if p.role == 'arc')
                x0,y0 = path.commands[0][1:]
                _,rx,ry,rotation,large,sweep,x1,y1 = path.commands[1]
                xp,yp = (x0-x1)/(2*rx),(y0-y1)/(2*ry)
                factor = math.sqrt(max(0,(1-xp*xp-yp*yp)/(xp*xp+yp*yp)))
                if large == sweep:
                    factor = -factor
                cx = (x0+x1)/2+rx*factor*yp
                cy = (y0+y1)/2-ry*factor*xp
                self.assertAlmostEqual(cx,0,places=8)
                self.assertAlmostEqual(cy,0,places=8)
                self.assertAlmostEqual(math.hypot(x0-s.objects[start-1].x,y0),12)
                self.assertAlmostEqual(math.hypot(x1-s.objects[end-1].x,y1),12)
                a,b = math.atan2((y0-cy)/ry,(x0-cx)/rx),math.atan2((y1-cy)/ry,(x1-cx)/rx)
                if sweep and b < a:
                    b += 2*math.pi
                elif not sweep and b > a:
                    b -= 2*math.pi
                for i in range(101):
                    theta = a+(b-a)*i/100
                    x,y = cx+rx*math.cos(theta),cy+ry*math.sin(theta)
                    for p in s.objects:
                        self.assertGreaterEqual(math.hypot(x-p.x,y),12-1e-8)

    def test_straight_and_mixed_endpoints_and_overrides(self):
        s = PlanarSurface((Boundary(-60,radius=8),MarkedPoint(0),Boundary(60,radius=17)),width=250,height=140)
        for a,b,expected in ((1,2,(-52,0)),(2,3,(0,43)),(3,2,(43,0)),(0,1,(-125,-68))):
            commands = next(p for p in layout(s.with_curves(Arc(a,b)),self.style).paths if p.role == 'arc').commands
            self.assertEqual(commands,(('M',expected[0],0),('L',expected[1],0)))

    def test_curved_rim_sides_and_clearance(self):
        surface = PlanarSurface((Boundary(-50, radius=8), Boundary(50, radius=17)),
                                width=240, height=220)
        for direction in ('up', 'down'):
            for a, b, expected in ((1, 2, (-42, 33)), (2, 1, (33, -42))):
                pieces = route(surface.with_curves(Arc(a, b, direction=direction)), self.style)
                self.assertEqual((pieces[0].start, pieces[-1].end), expected)
            pieces = route(surface.with_curves(Arc(1, 2, direction=direction,
                           start_side='left', end_side='right')), self.style)
            self.assertEqual((pieces[0].start, pieces[-1].end), (-58, 67))
            # Independently check the entire route, including both endpoint holes.
            for i in range(1001):
                x, y = pieces[0].point(i/1000)
                for boundary in surface.objects:
                    self.assertGreaterEqual(math.hypot(x-boundary.x, y), boundary.radius-1e-8)
        with self.assertRaisesRegex(RoutingError, 'endpoint boundary'):
            route(surface.with_curves(Arc(1, 2, direction='up', start_side='left')),
                  replace(self.style, curve_height=.05))
        with self.assertRaisesRegex(RoutingError, 'endpoint boundary'):
            route(surface.with_curves(Arc(1, 2, start_side='left')), self.style)
        for endpoint, shape in ((0, 'circle'), (1, 'dot')):
            with self.assertRaisesRegex(ValueError, 'circular inner boundary'):
                route(surface.with_curves(Arc(endpoint, 2, start_side='left')),
                      replace(self.style, boundary_shape=shape))
        with self.assertRaisesRegex(ValueError, 'circular inner boundary'):
            route(PlanarSurface.row('PP').with_curves(Arc(1, 2, end_side='right')), self.style)
        with self.assertRaisesRegex(ValueError, 'endpoint side'):
            Arc(1, 2, start_side='top')

    def test_cut_crossings_and_loops_retain_their_itineraries(self):
        for curve in (Arc(2,5,(3,),False),Loop((1,4))):
            s = self.row.with_curves(curve)
            pieces = route(s,self.style)
            commands = next(p for p in layout(s,self.style).paths if p.role in ('arc','closed-curve')).commands
            self.assertEqual(sum(c[0]=='A' for c in commands),len(pieces))
            for i,p in enumerate(pieces[:-1]):
                self.assertEqual(commands[i+1][-2:],(p.end,0))
            self.assertEqual(commands[-1][0]=='Z',isinstance(curve,Loop))

    def test_holes_clip_strokes_and_guides_without_painting_over_them(self):
        s = self.row.with_curves(Arc(2,3),Loop((3,6)))
        for bg in (None,'#e9f4fa'):
            style = replace(self.style,show_guides=True,background=bg)
            xml = render_svg(s,style=style)
            root = ET.fromstring(xml)
            clip = root.find('.//'+NS+'clipPath')
            self.assertEqual(clip.attrib['clipPathUnits'],'userSpaceOnUse')
            self.assertEqual(clip[0].attrib['clip-rule'],'evenodd')
            self.assertEqual(clip[0].attrib['d'].count('A '),12)
            for p in root.findall(NS+'path'):
                self.assertEqual(p.attrib['clip-path'],'url(#'+clip.attrib['id']+')')
            holes = [c for c in root.findall(NS+'circle') if c.attrib['class']=='inner-boundary-circle']
            self.assertEqual(len(holes),6)
            self.assertTrue(all(c.attrib['fill']=='none' for c in holes))
            self.assertEqual(len(root.findall(NS+'rect')),int(bg is not None))
            self.assertEqual(xml,render_svg(s,style=style))
            scaled = ET.fromstring(render_svg(s,style=style,scale=3))
            self.assertEqual(scaled.attrib['viewBox'],root.attrib['viewBox'])

    def test_invalid_holes_and_colliding_routes_are_rejected(self):
        for objects in ((Boundary(0,radius=60),),
                        (Boundary(-10),Boundary(10)),
                        (Boundary(0),MarkedPoint(8)),
                        (Boundary(105,radius=15),)):
            with self.subTest(objects=objects),self.assertRaises(ValueError):
                render_svg(PlanarSurface(objects),style=self.style)
        with self.assertRaises(RoutingError):
            render_svg(self.row.with_curves(Arc(0,4)),style=self.style)
        with self.assertRaises(ValueError):
            render_svg(PlanarSurface.row('B'),style=replace(self.style,outline_width=20))
        with self.assertRaises(RoutingError):
            render_svg(self.row.with_curves(Arc(1,6)),style=replace(self.style,curve_height=.05))
        with self.assertRaises(RoutingError):
            render_svg(PlanarSurface((Boundary(0,10),)),style=replace(self.style,show_guides=True))

    def test_guide_labels_clear_unequal_holes(self):
        s = PlanarSurface((Boundary(-30,radius=25),Boundary(30,radius=5)),width=200,height=120)
        d = layout(s,replace(self.style,show_guides=True))
        labels = d.texts
        self.assertEqual(labels[1].x,10)
        self.assertGreater(labels[-2].y,25)

    def test_tikz_hole_clipping_scope_and_transparency(self):
        from surface_diagrams import render_tikz
        s = self.row.with_curves(Arc(1,6,direction='up'))
        for background in (None, '#abc'):
            result = render_tikz(s, style=replace(self.style, background=background, show_guides=True))
            self.assertIn(r'\clip[even odd rule]', result)
            scope = result.index(r'\begin{scope}')
            end = result.index(r'\end{scope}')
            self.assertLess(scope, result.index('% arc'))
            self.assertGreater(end, result.index('% arc'))
            self.assertGreater(result.index('% inner-boundary-circle'), end)
            self.assertEqual(result.count('fill=none'), 7)
            self.assertEqual(result.count(r'\fill['), int(background is not None))
            self.assertNotIn('FFFFFF', result)
        with tempfile.TemporaryDirectory() as tmp:
            path = save_tikz(s, Path(tmp)/'holes.tikz', style=self.style)
            self.assertEqual(path.read_text(), render_tikz(s,style=self.style))


if __name__ == '__main__':
    unittest.main()
