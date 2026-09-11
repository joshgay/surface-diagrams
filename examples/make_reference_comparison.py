"""Compare finite default surfaces with selected crops of the original SVGs."""
from copy import deepcopy
from html import escape
from pathlib import Path
import re
from xml.etree import ElementTree as ET

from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair, render_svg


def make_reference_comparison(destination=None):
    root = Path(__file__).resolve().parents[1]
    out = Path(destination) if destination else root / "examples" / "output"
    out.mkdir(parents=True, exist_ok=True)
    d3 = GenusSurface(3, type_i=(TypeIBoundary(8),), type_ii=(BoundaryPair(),)*6)
    e2 = GenusSurface(3, type_ii=(BoundaryPair('left'), BoundaryPair('right'),
                                BoundaryPair(), BoundaryPair()))
    examples = [
        ("D3HyperellipticLifted.svg", (0, 0, 205, 65), d3, "Genus 3: six pairs and an end boundary"),
        ("D2AHyperellipticSurfaces.svg", (70, 238, 205, 63), d3, "Same default, no appearance overrides"),
        ("E2MCKHOddGenusLiftedWithBoundaries.svg", (4, 4, 185, 76), e2, "Genus 3: side pairs and two top/bottom pairs"),
    ]
    lines = ['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="940" viewBox="0 0 1100 940">',
             '<rect width="1100" height="940" fill="white"/>',
             '<text x="30" y="34" font-family="serif" font-size="24">Primary references and new defaults</text>',
             '<text x="30" y="59" font-family="serif" font-size="14">Left: original abbreviated reference. Right: finite generated surface; curves arrive in a later stage.</text>']
    for i, (filename, crop, surface, caption) in enumerate(examples):
        y = 95 + i*275
        lines.append(f'<text x="30" y="{y}" font-family="serif" font-size="16">{escape(filename)}</text>')
        lines.append(f'<text x="580" y="{y}" font-family="serif" font-size="16">{escape(caption)}</text>')
        source = ET.parse(root / "Figures" / filename).getroot()
        node = deepcopy(source)
        node.set("x", "25")
        node.set("y", str(y+15))
        node.set("width", "510")
        node.set("height", "215")
        node.set("viewBox", " ".join(map(str, crop)))
        # Keep source IDs and clip references local to each embedded document.
        ids = {e.attrib['id']: f"source{i}-{e.attrib['id']}" for e in node.iter() if 'id' in e.attrib}
        for e in node.iter():
            for key, value in list(e.attrib.items()):
                if key == 'id':
                    e.set(key, ids[value])
                else:
                    value = re.sub(r'url\(#([^)]+)\)', lambda m: 'url(#'+ids.get(m[1], m[1])+')', value)
                    if value.startswith('#') and value[1:] in ids:
                        value = '#'+ids[value[1:]]
                    e.set(key, value)
        lines.append(ET.tostring(node, encoding="unicode"))
        new = ET.fromstring(render_svg(surface))
        new.set("x", "575")
        new.set("y", str(y+15))
        new.set("width", "500")
        new.set("height", "215")
        lines.append(ET.tostring(new, encoding="unicode"))
    lines.append('</svg>')
    target = out / "reference-comparison.svg"
    target.write_text("\n".join(lines)+"\n", encoding="utf-8")
    return target


if __name__ == '__main__':
    print(make_reference_comparison())
