"""Executable abstract topology fixtures for P3; no presentation claims."""

from dataclasses import replace
import json

from surface_diagrams.cut_systems import (
    BoundarySide, Cellulation, Face, Mark, SidePair, SurfaceSpec,
    validate_cut_system,
)


def polygon(name, word, genus, boundaries=(), marks=(), cuts=None):
    """Expand the documented signed polygon words into occurrence records."""
    word = tuple(word.split())
    pairs = tuple(SidePair(s, s, '-'+s) for s in word if '-'+s in word)
    paired_sides = {s for p in pairs for s in (p.first, p.second)}
    boundary_sides = tuple(BoundarySide(s, dict(boundaries)[s])
                           for s in word if s not in paired_sides)
    cell = Cellulation((Face(name, word),), pairs, boundary_sides, tuple(marks),
                       tuple(p.id for p in pairs) if cuts is None else tuple(cuts))
    spec = SurfaceSpec(name, genus, tuple(dict.fromkeys(b.boundary for b in boundary_sides)),
                       tuple(m.id for m in marks))
    return cell, spec


def examples():
    cases = {
        'disk': polygon('disk', 'B0a B0b B0c', 0,
                        (('B0a', 'B0'), ('B0b', 'B0'), ('B0c', 'B0'))),
        'annulus': polygon('annulus', 'a B1 -a B0', 0,
                           (('B1', 'B1'), ('B0', 'B0'))),
        'marked-disk': polygon('marked-disk', 'B0 a -a', 0,
                               (('B0', 'B0'),), (Mark('M', corner='-a'),)),
        'torus': polygon('torus', 'a b -a -b', 1),
        'genus-two': polygon('genus-two', 'a b -a -b c d -c -d', 2),
        'pair-of-pants': polygon('pair-of-pants', 'a B1 -a B0a c B2 -c B0b', 0,
                                 (('B1', 'B1'), ('B2', 'B2'), ('B0a', 'B0'), ('B0b', 'B0'))),
    }
    cases['split-disk'] = (
        Cellulation((Face('left', ('a', 'L1', 'L2')), Face('right', ('-a', 'R1', 'R2'))),
                    (SidePair('a', 'a', '-a'),),
                    tuple(BoundarySide(s, 'B0') for s in ('L1', 'L2', 'R1', 'R2')),
                    cuts=('a',)),
        SurfaceSpec('split-disk', 0, ('B0',)),
    )
    return cases


def reports():
    for name, (cell, spec) in examples().items():
        for selected in (True, False):
            candidate = cell if selected else replace(cell, cuts=())
            report = validate_cut_system(candidate, spec)
            yield {
                'example': name,
                'cuts': list(candidate.cuts),
                'scope': report.scope,
                'certified': report.certified,
                'full': [{'genus': c.genus, 'boundaries': len(c.boundary_cycles),
                          'euler': c.euler} for c in report.full],
                'complement': [{'faces': c.faces, 'genus': c.genus,
                                'boundaries': len(c.boundary_cycles),
                                'interior_marks': c.interior_marks} for c in report.complement],
                'diagnostics': [{'code': d.code, 'message': d.message, 'ids': d.ids}
                                for d in report.diagnostics],
            }


if __name__ == '__main__':
    print(json.dumps(list(reports()), indent=2))
