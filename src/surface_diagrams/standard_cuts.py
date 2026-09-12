"""Canonical numbered chain cellulations, with explicit boundary/mark spokes.

The chain ribbon graph is constructed first; its two complementary disks are
recovered and checked against the requested genus. Decorations puncture or mark
those disks and attach explicit spokes. No projection crossing defines topology.
"""

from dataclasses import dataclass, replace

from .cut_systems import (Attachment, BoundarySide, Cellulation, Face, Intersection,
                          Mark, ParentCut, SidePair, SurfaceSpec, validate_cut_system)


@dataclass(frozen=True)
class CutSystem:
    cellulation: Cellulation
    surface: SurfaceSpec

    def validate(self):
        return validate_cut_system(self.cellulation, self.surface)

    @property
    def numbers(self):
        return tuple((p.number, p.id) for p in self.cellulation.parents)


def chain_system(genus, *, boundaries=(), marks=()):
    """Return the 2g+1 chain with one numbered spoke per boundary/mark.

    Boundary and mark IDs have a stable caller-supplied order. This constructs
    abstract topology; a display must separately bind the same cells to charts.
    """
    if type(genus) is not int or not 1 <= genus <= 64:
        raise ValueError('genus must be an integer in 1..64')
    boundaries, marks = tuple(boundaries), tuple(marks)
    if len(boundaries)+len(marks) > 128:
        raise ValueError('at most 128 boundary/mark decorations are supported')
    if any(not isinstance(s, str) or not s for s in boundaries+marks):
        raise ValueError('boundary and mark IDs must be nonempty strings')
    if len(set(boundaries)) != len(boundaries) or len(set(marks)) != len(marks):
        raise ValueError('boundary and mark IDs must be unique within their type')
    count = 2*genus+1
    pairs, parents, ends = [], [], {}
    for number in range(1, count+1):
        vertices = ([1] if number == 1 else [count-1] if number == count
                    else [number-1, number])
        walk = []
        for i, vertex in enumerate(vertices):
            target = vertices[(i+1) % len(vertices)]
            edge = f'c{number}.e{i+1}'
            forward, backward = edge+'+', edge+'-'
            pairs.append(SidePair(edge, forward, backward))
            walk.append(forward)
            ends[number, vertex, 'out'] = forward
            ends[number, target, 'in'] = backward
        parents.append(ParentCut(f'c{number}', number, 'closed', tuple(walk)))
    rotation = {}
    intersections = []
    for vertex in range(1, count):
        order = (ends[vertex, vertex, 'out'], ends[vertex+1, vertex, 'out'],
                 ends[vertex, vertex, 'in'], ends[vertex+1, vertex, 'in'])
        rotation.update(zip(order, order[1:]+order[:1]))
        intersections.append(Intersection(order[0], (f'c{vertex}', f'c{vertex+1}')))
    mate = {s: t for p in pairs for s, t in ((p.first, p.second), (p.second, p.first))}
    unseen, faces = set(mate), []
    while unseen:
        first, word = min(unseen), []
        side = first
        while side in unseen:
            word.append(side)
            unseen.remove(side)
            side = rotation[mate[side]]
        if side != first:
            raise RuntimeError('chain face walk did not close')
        faces.append(Face(f'chain-disk-{len(faces)+1}', tuple(word)))
    cell = Cellulation(tuple(faces), tuple(pairs), cuts=tuple(p.id for p in pairs),
                       parents=tuple(parents), intersections=tuple(intersections))
    spec = SurfaceSpec(f'chain-genus-{genus}', genus)
    report = validate_cut_system(cell, spec)
    if not report.certified or len(report.complement) != 2:
        raise RuntimeError('canonical chain did not reconstruct the requested genus: '+str(report.diagnostics))
    # Alternating disk assignment is topological data. A later presentation
    # binding must preserve it; a screen position cannot silently reassign it.
    for i, (kind, name) in enumerate([('boundary', b) for b in boundaries]+[('mark', m) for m in marks]):
        cell = _decorate(cell, i % 2, kind, name, count+i+1)
    spec = replace(spec, boundaries=boundaries, marks=marks)
    result = CutSystem(cell, spec)
    if not result.validate().certified:
        raise RuntimeError('decorated chain failed certification: '+str(result.validate().diagnostics))
    return result


def _decorate(cell, face_index, kind, name, number):
    face = cell.faces[face_index]
    # Select a chain edge side, never a previous spoke. Subdivision leaves a
    # distinct attachment vertex and preserves every existing crossing vertex.
    by_side = {s: p for p in cell.pairs for s in (p.first, p.second)}
    parent_by_edge = {by_side[s].id: p.id for p in cell.parents for s in p.walk}
    side = next(s for s in face.sides if parent_by_edge.get(by_side[s].id, '').startswith('c')
                )
    pair = by_side[side]
    replacement = {pair.first: (pair.first+'.0', pair.first+'.1'),
                   pair.second: (pair.second+'.1', pair.second+'.0')}
    new_pairs = (SidePair(pair.id+'.0', replacement[pair.first][0], replacement[pair.second][1]),
                 SidePair(pair.id+'.1', replacement[pair.first][1], replacement[pair.second][0]))
    def expand(word):
        return tuple(t for s in word for t in replacement.get(s, (s,)))
    def corner(s):
        return replacement.get(s, (s,))[0]
    faces = [replace(f, sides=expand(f.sides)) for f in cell.faces]
    parents = [replace(p, walk=expand(p.walk), endpoints=tuple(corner(s) for s in p.endpoints))
               for p in cell.parents]
    pairs = tuple(p for p in cell.pairs if p.id != pair.id)+new_pairs
    cuts = tuple(p for p in cell.cuts if p != pair.id)+tuple(p.id for p in new_pairs)
    intersections = tuple(replace(x, corner=corner(x.corner)) for x in cell.intersections)
    attachments = tuple(replace(a, corner=corner(a.corner)) for a in cell.attachments)
    marks = tuple(replace(m, corner=corner(m.corner)) if m.corner is not None else m for m in cell.marks)
    forward, backward = f's{number}+', f's{number}-'
    boundary_side = f'boundary-{number}'
    insertion = (forward, boundary_side, backward) if kind == 'boundary' else (forward, backward)
    sides = list(faces[face_index].sides)
    anchor = replacement[side][1]
    index = sides.index(anchor)
    sides[index:index] = insertion
    faces[face_index] = replace(faces[face_index], sides=tuple(sides))
    pairs += (SidePair(f's{number}', forward, backward),)
    cuts += (f's{number}',)
    boundary = cell.boundaries
    if kind == 'boundary':
        boundary += (BoundarySide(boundary_side, name),)
        endpoint = boundary_side
    else:
        marks += (Mark(name, corner=backward),)
        endpoint = backward
    parent_id = f'{kind}:{name}'
    parents.append(ParentCut(parent_id, number, 'arc', (forward,), (forward, endpoint)))
    attachments += (Attachment(forward, parent_id, parent_by_edge[pair.id]),)
    return Cellulation(tuple(faces), pairs, boundary, marks, cuts, tuple(parents),
                       intersections=intersections, attachments=attachments)
