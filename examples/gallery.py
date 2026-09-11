"""A reproducible gallery: edit these constructors to make your own images."""
from dataclasses import replace
from html import escape
from pathlib import Path
from math import ceil
from surface_diagrams import (
    Arc, Loop, Boundary, MarkedPoint, PlanarSurface, Style, GenusSurface,
    TypeIBoundary, BoundaryPair, render_svg, save_svg,
)


def gallery_examples():
    default = Style()
    row = PlanarSurface.row('B P B P P')
    six = PlanarSurface.row('PPPPPP', spacing=55, height=210, margin=60)
    return {
        'planar': [
            ('default', 'Thesis blue and gray', row, default),
            ('large-ellipse', 'More room around the same five objects', replace(row,width=500,height=210), default),
            ('twelve-points', 'Twelve marked points', PlanarSurface.row('P'*12,height=140), default),
            ('twenty-points', 'Twenty points; smaller dots', PlanarSurface.row('P'*20,height=160), Style(marked_point_radius=3)),
            ('mixed-order', 'Six boundaries interspersed with points', PlanarSurface.row('BPPBPPBPPBBB',height=140), default),
            ('no-outline', 'Outer ellipse hidden', row, Style(show_outer_ellipse=False)),
            ('large-boundaries', 'Boundary radius 8; point radius 3', row, Style(boundary_radius=8,marked_point_radius=3)),
            ('large-points', 'Point radius 8; boundary radius 3', row, Style(boundary_radius=3,marked_point_radius=8)),
            ('custom-colors', 'Configurable colors, white background', row, Style(marked_point_color='#bd2535',boundary_color='#167765',background='#ffffff')),
            ('custom-positions', 'Free positions off the axis (no cut curves)', PlanarSurface([Boundary(-70),Boundary(70),MarkedPoint(-25,20),MarkedPoint(-25,-20),MarkedPoint(25,20),MarkedPoint(25,-20)],height=110), default),
            ('per-object-size', 'Individual radii 3, 5, 7, 9', PlanarSurface([MarkedPoint(-60,radius=3),Boundary(-20,radius=5),MarkedPoint(20,radius=7),Boundary(60,radius=9)],height=110), default),
            ('empty', 'An empty, rounder disk', PlanarSurface(width=220,height=180), default),
        ],
        'curves': [
            ('simple-up', 'Arc(1, 6)', six.with_curves(Arc(1,6)), default),
            ('simple-down', 'Arc(1, 6, start_up=False)', six.with_curves(Arc(1,6,start_up=False)), default),
            ('one-cut', 'Arc(2, 5, cuts=(3,), start_up=False)', six.with_curves(Arc(2,5,(3,),False)), Style(show_guides=True)),
            ('repeated-cuts', 'Arc(2, 3, cuts=(4, 2, 4, 2, 4), start_up=False)', six.with_curves(Arc(2,3,(4,2,4,2,4),False)), default),
            ('winding', 'Arc(3, 6, cuts=(4, 0, 4))', six.with_curves(Arc(3,6,(4,0,4))), default),
            ('outer-endpoints', 'Arc(0, 7): endpoints on the outer boundary', six.with_curves(Arc(0,7)), default),
            ('outer-to-point', 'Arc(0, 4, cuts=(2,))', six.with_curves(Arc(0,4,(2,))), default),
            ('consecutive-loop', 'Loop((1, 4)): around objects 2, 3, 4', six.with_curves(Loop((1,4))), default),
            ('nonconsecutive-loop', 'Loop((0, 6, 5, 1)): around the two ends', six.with_curves(Loop((0,6,5,1))), default),
            ('nested', 'Nested loops plus an interior arc', six.with_curves(Loop((0,6)),Loop((1,5)),Arc(3,4)), default),
            ('disjoint', 'Three disjoint arcs', six.with_curves(Arc(1,2),Arc(3,4),Arc(5,6)), default),
            ('mixed-loop', 'Loop around boundaries and marked points', PlanarSurface.row('BPBPBP',spacing=55,height=210,margin=60).with_curves(Loop((1,5))), Style(curve_color='#ed2424',curve_width=2.5)),
        ],
        'directions': [
            ('adjacent-default', 'Arc(3, 4): default is straight', six.with_curves(Arc(3,4)), default),
            ('adjacent-up', 'Arc(3, 4, direction="up")', six.with_curves(Arc(3,4,direction='up')), default),
            ('adjacent-down', 'Arc(3, 4, direction="down")', six.with_curves(Arc(3,4,direction='down')), default),
            ('nonadjacent-default', 'Arc(2, 5): default still goes up', six.with_curves(Arc(2,5)), default),
            ('outer-default', 'Arc(0, 1): straight from outer boundary', six.with_curves(Arc(0,1)), default),
            ('outer-up', 'Arc(0, 1, direction="up")', six.with_curves(Arc(0,1,direction='up')), default),
            ('outer-down', 'Arc(0, 1, direction="down")', six.with_curves(Arc(0,1,direction='down')), default),
            ('right-default', 'Arc(6, 7): straight to outer boundary', six.with_curves(Arc(6,7)), default),
            ('adjacent-with-cuts', 'Arc(2, 3, cuts=(4,)): itinerary preserved', six.with_curves(Arc(2,3,(4,))), default),
            ('shared-endpoints', 'Straight chain with a curved arc over it', six.with_curves(Arc(1,2),Arc(2,3),Arc(1,3)), default),
            ('boundary-dots', 'Consecutive boundary dots also join straight', PlanarSurface.row('BPBBPP',spacing=55,height=210,margin=60).with_curves(Arc(1,2),Arc(3,4)), default),
            ('three-directions', 'Default, up, down on three adjacent pairs', six.with_curves(Arc(1,2),Arc(3,4,direction='up'),Arc(5,6,direction='down')), default),
        ],
        'genus': [
            ('genus-one', 'Genus 1, no boundary components', GenusSurface(1), default),
            ('genus-two', 'Genus 2, no boundary components', GenusSurface(2), default),
            ('genus-three', 'Genus 3, with involution axis', GenusSurface(3,show_axis=True), default),
            ('genus-five', 'Genus 5', GenusSurface(5), default),
            ('balloon', 'Optional second handle arc', GenusSurface(2,handle_style='balloon'), default),
            ('fixed-ends', 'Type I: slots 1 and 6', GenusSurface(type_i=(TypeIBoundary(1),TypeIBoundary(6))), default),
            ('fixed-handle', 'Type I: slots 2 and 3', GenusSurface(type_i=(TypeIBoundary(2),TypeIBoundary(3))), default),
            ('all-fixed', 'All six Type I slots on genus 2', GenusSurface(type_i=tuple(TypeIBoundary(i) for i in range(1,7)),show_axis=True), default),
            ('paired-top-bottom', 'Two Type II pairs: four boundaries', GenusSurface(type_ii=(BoundaryPair('top',.3),BoundaryPair('top',.7))), default),
            ('paired-left-right', 'Left and right Type II pairs', GenusSurface(type_ii=(BoundaryPair('left'),BoundaryPair('right'))), default),
            ('mixed-types', 'One Type I plus two Type II pairs', GenusSurface(type_i=(TypeIBoundary(6),),type_ii=(BoundaryPair('left'),BoundaryPair('top',.65))), default),
            ('many-pairs', 'Six pairs on a wider genus-3 surface', GenusSurface(3,handle_spacing=160,type_ii=tuple(BoundaryPair('top',p,radius=6) for p in (0,.2,.4,.6,.8,1))), default),
            ('d3-default-boundaries', 'D3/D2A: six top-bottom pairs and an end boundary', GenusSurface(3,type_i=(TypeIBoundary(8),),type_ii=(BoundaryPair(),)*6), default),
            ('e2-default-boundaries', 'E2: side pairs and two top-bottom pairs', GenusSurface(3,type_ii=(BoundaryPair('left'),BoundaryPair('right'),BoundaryPair(),BoundaryPair())), default),
            ('automatic-pairs', 'Four pairs: automatic positions and sizes', GenusSurface(2,type_ii=(BoundaryPair(),)*4), default),
            ('custom-proportions', 'Optional wider spacing and taller body', GenusSurface(2,handle_spacing=140,height=120,type_ii=(BoundaryPair(),BoundaryPair())), default),
            ('colored-background', 'Transparent collars on a colored background', GenusSurface(2,type_ii=(BoundaryPair('left'),BoundaryPair('right'),BoundaryPair())), Style(background='#e9f4fa')),
        ],
    }


def make_gallery(destination=None):
    out = Path(destination) if destination else Path(__file__).resolve().parent / 'output'
    out.mkdir(parents=True, exist_ok=True)
    index = ['# Surface diagram examples', '',
             'Run `python examples/make_images.py` to regenerate everything. '
             'The constructors are in [gallery.py](../gallery.py).', '',
             'Blue `#006fff`, gray `#8b8b8b`, and magenta `#ff00d4` are measured '
             'from the thesis planar figures. High-genus examples are new schematics '
             'following the D3/D2A/E2 source SVGs, with boundary rims distinct from handle openings.', '']
    for category, examples in gallery_examples().items():
        height = ceil(len(examples)/2)*230+70
        sheet = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 {height}" width="1000" height="{height}">',
                 '<rect width="100%" height="100%" fill="white"/>',
                 f'<text x="25" y="36" font-family="serif" font-size="24">{category.title()} examples</text>']
        index.extend([f'## {category.title()}', '', f'![{category} examples]({category}-gallery.svg)', ''])
        for i,(name,caption,surface,style) in enumerate(examples):
            filename = f'{category}-{name}.svg'
            save_svg(surface,out/filename,style=style,title=caption,scale=2)
            x,y = (i%2)*500, (i//2)*230+65
            sheet.append(f'<text x="{x+20}" y="{y+15}" font-family="serif" font-size="14">{i+1}. {escape(caption)}</text>')
            svg=render_svg(surface,style=style,title=caption)
            # Nested SVG preserves the diagram's aspect ratio and framing.
            start=svg.index('viewBox="')+9; viewbox=svg[start:svg.index('"',start)]
            body=svg[svg.index('>')+1:svg.rindex('</svg>')]
            sheet.append(f'<svg x="{x+20}" y="{y+27}" width="460" height="177" viewBox="{viewbox}">{body}</svg>')
            index.append(f'- [{caption}]({filename})')
        sheet.append('</svg>')
        (out/f'{category}-gallery.svg').write_text('\n'.join(sheet)+'\n',encoding='utf-8')
        index.append('')
    (out/'GALLERY.md').write_text('\n'.join(index)+'\n',encoding='utf-8')
    return out/'GALLERY.md'


if __name__=='__main__': print(make_gallery())
