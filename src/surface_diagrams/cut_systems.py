"""Internal P3 polygon-cellulation certificates; independent of drawing geometry.

Corners are named by their outgoing side occurrence. Pairings reverse polygon
boundary directions. Unselected pairs remain glued when computing complements.
This module certifies explicitly supplied abstract cellulations, never SVGs.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class SurfaceSpec:
    id: str
    genus: int
    boundaries: tuple = ()
    marks: tuple = ()


@dataclass(frozen=True)
class Face:
    id: str
    sides: tuple


@dataclass(frozen=True)
class SidePair:
    id: str
    first: str
    second: str
    reversed: bool = True


@dataclass(frozen=True)
class BoundarySide:
    side: str
    boundary: str


@dataclass(frozen=True)
class Mark:
    id: str
    corner: Optional[str] = None
    face: Optional[str] = None


@dataclass(frozen=True)
class ParentCut:
    id: str
    number: int
    kind: str
    # Each side occurrence traverses its paired edge in that side's direction.
    walk: tuple
    endpoints: tuple = ()


@dataclass(frozen=True)
class VertexIncidence:
    corner: str
    # Edge-end labels are (pair ID, 'start'/'end'), relative to pair.first.
    # Boundary ends use their unpaired side occurrence as the ID.
    ends: tuple
    # Optional expected corner equivalence class; assertions never glue vertices.
    corners: tuple = ()


@dataclass(frozen=True)
class Intersection:
    corner: str
    parents: tuple
    kind: str = 'genuine'


@dataclass(frozen=True)
class Attachment:
    """A supplementary cut ending at an interior point of another cut."""
    corner: str
    ending: str
    through: str


@dataclass(frozen=True)
class Cellulation:
    faces: tuple
    pairs: tuple = ()
    boundaries: tuple = ()
    marks: tuple = ()
    cuts: tuple = ()
    parents: tuple = ()
    incidences: tuple = ()
    intersections: tuple = ()
    attachments: tuple = ()


@dataclass(frozen=True)
class Diagnostic:
    code: str
    message: str
    ids: tuple = ()


@dataclass(frozen=True)
class Vertex:
    id: str
    corners: tuple
    boundary: bool
    ends: tuple


@dataclass(frozen=True)
class Component:
    faces: tuple
    vertices: int
    edges: int
    euler: int
    genus: int
    boundary_cycles: tuple
    interior_marks: tuple = ()
    boundary_marks: tuple = ()


@dataclass(frozen=True)
class CutReport:
    full: tuple = ()
    complement: tuple = ()
    diagnostics: tuple = ()
    scope: str = 'abstract_cellulation'
    vertices: tuple = ()

    @property
    def certified(self):
        return bool(self.full) and bool(self.complement) and not self.diagnostics


class _Invalid(Exception):
    def __init__(self, code, message, *ids):
        self.diagnostic = Diagnostic(code, message, tuple(ids))


def _fail(code, message, *ids):
    raise _Invalid(code, message, *ids)


def _id(value):
    if not isinstance(value, str) or not value:
        _fail('invalid_id', 'IDs must be nonempty strings')
    return value


def _unique(values, name):
    values = tuple(values)
    for value in values:
        _id(value)
    if len(values) != len(set(values)):
        _fail('duplicate_id', 'Duplicate ' + name)
    return values


class _Union:
    def __init__(self, items):
        self.parent = {item: item for item in items}

    def find(self, item):
        root = item
        while root != self.parent[root]:
            root = self.parent[root]
        while item != root:
            parent = self.parent[item]
            self.parent[item] = root
            item = parent
        return root

    def join(self, a, b):
        self.parent[self.find(a)] = self.find(b)


def _prepare(cell, spec):
    _id(spec.id)
    if type(spec.genus) is not int or spec.genus < 0:
        _fail('invalid_genus', 'Expected genus must be a nonnegative integer')
    if any(len(items) > 16384 for items in (spec.boundaries, spec.marks, cell.pairs,
           cell.boundaries, cell.marks, cell.cuts, cell.parents, cell.incidences, cell.intersections, cell.attachments)):
        _fail('input_limit', 'At most 16384 records per collection are supported')
    if sum(len(p.walk) for p in cell.parents) > 16384:
        _fail('input_limit', 'At most 16384 parent edge visits are supported')
    if sum(len(v.ends)+len(v.corners) for v in cell.incidences) > 65536:
        _fail('input_limit', 'At most 65536 incidence entries are supported')
    _unique(spec.boundaries, 'boundary IDs')
    _unique(spec.marks, 'mark IDs')
    if not cell.faces or len(cell.faces) > 8192:
        _fail('input_limit', 'Supply 1..8192 faces')
    if sum(len(f.sides) for f in cell.faces) > 32768:
        _fail('input_limit', 'At most 32768 side occurrences are supported')
    _unique((f.id for f in cell.faces), 'face IDs')
    sides = _unique((s for f in cell.faces for s in f.sides), 'side occurrences')
    nxt, prev, face_of = {}, {}, {}
    for face in cell.faces:
        if len(face.sides) < 3:
            _fail('invalid_face', 'A polygon needs at least three sides', face.id)
        for i, side in enumerate(face.sides):
            nxt[side] = face.sides[(i+1) % len(face.sides)]
            prev[side] = face.sides[i-1]
            face_of[side] = face.id
    pair_ids = _unique((p.id for p in cell.pairs), 'pair IDs')
    paired, mate = {}, {}
    for pair in cell.pairs:
        if pair.reversed is not True:
            _fail('orientation', 'Side gluing must reverse boundary direction', pair.id)
        for side, other in ((pair.first, pair.second), (pair.second, pair.first)):
            _id(side)
            if side not in face_of:
                _fail('unknown_side', 'Pair refers to an unknown side', pair.id, side)
            if side in paired:
                _fail('duplicate_pairing', 'A side cannot have multiple partners or pair with itself', side)
            paired[side], mate[side] = pair, other
    boundary = {}
    for item in cell.boundaries:
        _id(item.boundary)
        _id(item.side)
        if item.side not in face_of:
            _fail('unknown_side', 'Boundary refers to an unknown side', item.side)
        if item.side in paired or item.side in boundary:
            _fail('duplicate_boundary', 'Side has more than one gluing/boundary declaration', item.side)
        if item.side in pair_ids:
            _fail('ambiguous_edge_id', 'Unpaired side ID must differ from pair IDs', item.side)
        boundary[item.side] = item.boundary
    missing = set(sides) - set(paired) - set(boundary)
    if missing:
        _fail('unclassified_side', 'Every side needs a pair or genuine boundary', *sorted(missing))
    _unique(cell.cuts, 'selected cut edges')
    if set(cell.cuts) - set(pair_ids):
        _fail('unknown_cut', 'Selected cuts must be pair IDs', *sorted(set(cell.cuts)-set(pair_ids)))
    _unique((m.id for m in cell.marks), 'mark IDs')
    if set(spec.marks) != {m.id for m in cell.marks}:
        _fail('mark_inventory', 'Surface mark IDs do not match the cellulation')
    for mark in cell.marks:
        if (mark.corner is None) == (mark.face is None):
            _fail('mark_locator', 'A mark needs exactly one corner or face locator', mark.id)
        if mark.corner is not None:
            _id(mark.corner)
        if mark.face is not None:
            _id(mark.face)
        if mark.corner is not None and mark.corner not in face_of:
            _fail('mark_locator', 'Unknown marked corner', mark.id, mark.corner)
        if mark.face is not None and mark.face not in {f.id for f in cell.faces}:
            _fail('mark_locator', 'Unknown marked face', mark.id, mark.face)
    return sides, nxt, prev, face_of, paired, mate, boundary


def _reconstruct(cell, data, removed=(), mark_corners=None):
    sides, nxt, prev, face_of, paired, mate, boundary = data
    removed = set(removed)
    active = {s: mate[s] for s in paired if paired[s].id not in removed}
    vertices, faces = _Union(sides), _Union(f.id for f in cell.faces)
    successor, predecessor = {}, {}
    for s, t in active.items():
        vertices.join(s, nxt[t])
        faces.join(face_of[s], face_of[t])
        successor[s] = nxt[t]
        predecessor[nxt[t]] = s
    groups = {}
    for corner in sides:
        groups.setdefault(vertices.find(corner), []).append(corner)
    records, vertex_of = {}, {}

    def edge_end(side, start=True):
        if side in active:
            pair = paired[side]
            return (pair.id, 'start' if (side == pair.first) == start else 'end')
        return (side, 'start' if start else 'end')

    for corners in groups.values():
        starts = [c for c in corners if c not in predecessor]
        ends = [c for c in corners if c not in successor]
        is_boundary = bool(starts or ends)
        if is_boundary and (len(starts) != 1 or len(ends) != 1):
            _fail('vertex_link', 'Vertex link must be one interval or circle', *corners)
        first = starts[0] if is_boundary else min(corners)
        ordered, seen, current = [], set(), first
        while current not in seen:
            ordered.append(current)
            seen.add(current)
            if current not in successor:
                break
            current = successor[current]
        if len(seen) != len(corners) or (not is_boundary and current != first):
            _fail('vertex_link', 'Disconnected or inconsistent vertex link', *corners)
        labels = tuple(edge_end(c) for c in ordered)
        if is_boundary:
            labels = (edge_end(prev[first], False),) + labels
        record = Vertex(min(corners), tuple(sorted(corners)), is_boundary, labels)
        records[record.id] = record
        for corner in corners:
            vertex_of[corner] = record.id
    # On a manifold boundary there is one incoming and one outgoing free side
    # per boundary vertex. Traverse those sides, retaining their occurrence IDs.
    outgoing, incoming = {}, {}
    for side in sides:
        if side in active:
            continue
        a, b = vertex_of[side], vertex_of[nxt[side]]
        if a in outgoing or b in incoming:
            _fail('vertex_link', 'Branched boundary at a vertex', a, b)
        outgoing[a], incoming[b] = side, side
    if set(outgoing) != set(incoming):
        _fail('vertex_link', 'Boundary chains do not close')
    cycles, visited = [], set()
    for first in sorted(outgoing.values()):
        if first in visited:
            continue
        cycle, current = [], first
        while current not in visited:
            visited.add(current)
            cycle.append(current)
            current = outgoing[vertex_of[nxt[current]]]
        if current != first:
            _fail('boundary_cycle', 'Boundary traversal merges distinct cycles', first)
        cycles.append(tuple(cycle))
    components = []
    face_groups = {}
    for face in cell.faces:
        face_groups.setdefault(faces.find(face.id), []).append(face.id)
    for face_ids in sorted(face_groups.values(), key=lambda ids: min(ids)):
        face_ids = tuple(sorted(face_ids))
        face_set = set(face_ids)
        component_sides = {s for s in sides if face_of[s] in face_set}
        component_vertices = {vertex_of[s] for s in component_sides}
        edge_count = len(component_sides) - sum(s in active for s in component_sides)//2
        component_cycles = tuple(c for c in cycles if face_of[c[0]] in face_set)
        chi = len(component_vertices)-edge_count+len(face_ids)
        twice_genus = 2-len(component_cycles)-chi
        if twice_genus < 0 or twice_genus % 2:
            _fail('surface_topology', 'Invalid orientable component topology', *face_ids)
        interior, on_boundary = set(), set()
        for mark in cell.marks:
            if mark.face in face_set:
                interior.add(mark.id)
            elif mark.corner is not None:
                copies = mark_corners[mark.id] if mark_corners is not None else (mark.corner,)
                for corner in copies:
                    if face_of[corner] in face_set:
                        target = on_boundary if records[vertex_of[corner]].boundary else interior
                        target.add(mark.id)
        components.append(Component(face_ids, len(component_vertices), edge_count,
                                    chi, twice_genus//2, component_cycles,
                                    tuple(sorted(interior)), tuple(sorted(on_boundary))))
    return tuple(components), tuple(sorted(records.values(), key=lambda r: r.id)), vertex_of


def _cyclic_equal(a, b):
    if len(a) != len(b) or not a:
        return False
    # Recovered edge ends are unique, so there is at most one matching rotation.
    try:
        offset = b.index(a[0])
    except ValueError:
        return False
    return tuple(a) == tuple(b[offset:]+b[:offset])


def _validate_incidence(cell, data, vertices, vertex_of):
    records = {v.id: v for v in vertices}
    declared = set()
    for incidence in cell.incidences:
        _id(incidence.corner)
        if incidence.corner not in vertex_of:
            _fail('unknown_vertex', 'Unknown incidence corner', incidence.corner)
        vertex = records[vertex_of[incidence.corner]]
        if vertex.id in declared:
            _fail('duplicate_incidence', 'Vertex has multiple incidence declarations', vertex.id)
        declared.add(vertex.id)
        if incidence.corners and (len(incidence.corners) != len(set(incidence.corners))
                                  or set(incidence.corners) != set(vertex.corners)):
            _fail('vertex_identity', 'Declared corner class does not match actual side gluing', vertex.id)
        for end in incidence.ends:
            if len(end) != 2 or end[1] not in ('start', 'end'):
                _fail('vertex_rotation', 'Edge ends need an ID and start/end designation', vertex.id)
            _id(end[0])
        ends = tuple(tuple(end) for end in incidence.ends)
        if not (ends == vertex.ends if vertex.boundary else _cyclic_equal(ends, vertex.ends)):
            _fail('vertex_rotation', 'Declared edge-end order differs from the recovered vertex link', vertex.id)
    _unique((p.id for p in cell.parents), 'parent cut IDs')
    numbers, used, visits = set(), {}, {}
    parent_ids = {p.id for p in cell.parents}
    sides, nxt, prev, face_of, paired, mate, boundary = data
    marked_vertices = {vertex_of[m.corner] for m in cell.marks if m.corner is not None}
    attachments = {}
    for attachment in cell.attachments:
        if attachment.corner not in vertex_of:
            _fail('unknown_vertex', 'Attachment needs an actual corner', attachment.corner)
        vertex = vertex_of[attachment.corner]
        if vertex in attachments or attachment.ending == attachment.through:
            _fail('invalid_attachment', 'Attachment must join two distinct parents at a unique vertex', vertex)
        if {attachment.ending, attachment.through} - parent_ids:
            _fail('invalid_attachment', 'Attachment refers to an unknown parent', vertex)
        attachments[vertex] = attachment
    for parent in cell.parents:
        if type(parent.number) is not int or parent.number < 1 or parent.number in numbers:
            _fail('cut_number', 'Parent numbers must be distinct positive integers', parent.id)
        numbers.add(parent.number)
        if parent.kind not in ('arc', 'closed') or not parent.walk:
            _fail('parent_walk', 'Parent needs a nonempty arc or closed walk', parent.id)
        walk_vertices = []
        for side in parent.walk:
            _id(side)
            if side not in paired or paired[side].id not in cell.cuts:
                _fail('parent_walk', 'Parent walk must use selected paired edges', parent.id, side)
            pair = paired[side]
            if pair.id in used:
                _fail('shared_edge', 'Repeated/shared parent edges are unsupported', parent.id, pair.id)
            used[pair.id] = parent.id
            a, b = vertex_of[side], vertex_of[nxt[side]]
            if walk_vertices and walk_vertices[-1] != a:
                _fail('parent_walk', 'Parent walk is discontinuous', parent.id, side)
            if not walk_vertices:
                walk_vertices.append(a)
            walk_vertices.append(b)
            start = (pair.id, 'start' if side == pair.first else 'end')
            end = (pair.id, 'end' if side == pair.first else 'start')
            visits.setdefault(a, {}).setdefault(parent.id, []).append(start)
            visits.setdefault(b, {}).setdefault(parent.id, []).append(end)
        if parent.kind == 'closed':
            if parent.endpoints or walk_vertices[0] != walk_vertices[-1]:
                _fail('parent_closure', 'Closed parent must close and have no arc endpoints', parent.id)
            unique_vertices = walk_vertices[:-1]
            if any(records[v].boundary for v in unique_vertices):
                _fail('parent_boundary', 'Closed parents must lie in the surface interior', parent.id)
        else:
            if len(parent.endpoints) != 2 or any(e not in vertex_of for e in parent.endpoints):
                _fail('parent_endpoint', 'Arc needs two explicit corner endpoints', parent.id)
            if tuple(vertex_of[e] for e in parent.endpoints) != (walk_vertices[0], walk_vertices[-1]):
                _fail('parent_endpoint', 'Arc endpoint locators do not match its walk', parent.id)
            if any(not records[v].boundary and v not in marked_vertices
                   and not (v in attachments and attachments[v].ending == parent.id)
                   for v in (walk_vertices[0], walk_vertices[-1])):
                _fail('parent_endpoint', 'Arc endpoints must lie on a boundary or mark', parent.id)
            if any(records[v].boundary or v in marked_vertices for v in walk_vertices[1:-1]):
                _fail('parent_boundary', 'Arc interior cannot pass through boundary or marked vertices', parent.id)
            unique_vertices = walk_vertices
        if len(unique_vertices) != len(set(unique_vertices)):
            _fail('parent_self_intersection', 'Parent revisits a vertex; refine or supply an embedded walk', parent.id)
    if cell.parents and set(used) != set(cell.cuts):
        _fail('unassigned_cut', 'Every selected edge needs exactly one parent when parents are supplied')
    intersections = {}
    for crossing in cell.intersections:
        _id(crossing.corner)
        if crossing.kind != 'genuine':
            _fail('projection_crossing', 'Projection crossings cannot supply topological vertex incidence', crossing.corner)
        if crossing.corner not in vertex_of:
            _fail('unknown_vertex', 'Intersection needs an actual cellulation corner', crossing.corner)
        vertex = vertex_of[crossing.corner]
        if vertex in intersections:
            _fail('duplicate_intersection', 'Multiple intersection records at one vertex', vertex)
        if len(crossing.parents) != 2 or len(set(crossing.parents)) != 2 or set(crossing.parents)-parent_ids:
            _fail('unsupported_intersection', 'Initially an intersection needs exactly two distinct known parents', vertex)
        intersections[vertex] = set(crossing.parents)
    actual, actual_attachments = set(), set()
    for vertex, parents in visits.items():
        if len(parents) < 2:
            continue
        if vertex in attachments:
            attachment = attachments[vertex]
            if (records[vertex].boundary or vertex in intersections
                    or set(parents) != {attachment.ending, attachment.through}
                    or len(parents[attachment.ending]) != 1 or len(parents[attachment.through]) != 2):
                _fail('invalid_attachment', 'Attachment needs one ending arc and one interior through-parent', vertex)
            actual_attachments.add(vertex)
            continue
        actual.add(vertex)
        if intersections.get(vertex) != set(parents):
            _fail('undeclared_intersection', 'Shared parent vertex needs a matching genuine intersection', vertex)
        record = records[vertex]
        if record.boundary or len(parents) != 2 or any(len(ends) != 2 for ends in parents.values()):
            _fail('unsupported_intersection', 'Only interior transverse two-parent intersections are supported', vertex)
        owner = {end: parent for parent, ends in parents.items() for end in ends}
        order = [owner[end] for end in record.ends if end in owner]
        if len(order) != 4 or any(order[i] == order[(i+1)%4] for i in range(4)):
            _fail('nontransverse_intersection', 'Parent edge ends do not alternate at the intersection', vertex)
    if set(attachments) != actual_attachments:
        _fail('invalid_attachment', 'Declared attachment does not match the parent walks')
    if set(intersections) != actual:
        _fail('false_intersection', 'Declared parents do not meet at the supplied vertex', *sorted(set(intersections)-actual))


def validate_cut_system(cell, spec, *, scope='abstract_cellulation'):
    """Return computed topology and diagnostics without repairing the input.

    Supported scope is an explicit abstract cellulation. No render binding is
    certified. Bad combinatorial data returns diagnostics; callers must supply
    the typed records and finite sequences specified above.
    """
    full, complement, vertices = (), (), ()
    try:
        if scope != 'abstract_cellulation':
            _fail('unsupported_binding', 'Rendered presentation certification is not implemented')
        data = _prepare(cell, spec)
        full, vertices, vertex_of = _reconstruct(cell, data)
        if len(full) != 1:
            _fail('surface_components', 'Expected one connected surface')
        if full[0].genus != spec.genus:
            _fail('surface_genus', 'Recovered genus differs from the requested surface', spec.id)
        boundary_map = data[-1]
        recovered_ids = []
        for cycle in full[0].boundary_cycles:
            labels = {boundary_map[s] for s in cycle}
            if len(labels) != 1:
                _fail('boundary_identity', 'One recovered boundary cycle has mixed boundary IDs', *cycle)
            recovered_ids.append(next(iter(labels)))
        if len(recovered_ids) != len(set(recovered_ids)) or set(recovered_ids) != set(spec.boundaries):
            _fail('boundary_identity', 'Recovered boundary cycles do not match distinct requested IDs')
        by_vertex = {v.id: v for v in vertices}
        mark_corners, occupied = {}, set()
        for mark in cell.marks:
            if mark.corner is not None:
                vertex = vertex_of[mark.corner]
                if vertex in occupied:
                    _fail('duplicate_mark_location', 'Distinct marks cannot occupy the same vertex', mark.id, vertex)
                occupied.add(vertex)
                mark_corners[mark.id] = by_vertex[vertex].corners
        _validate_incidence(cell, data, vertices, vertex_of)
        complement, _, _ = _reconstruct(cell, data, cell.cuts, mark_corners)
        diagnostics = []
        for component in complement:
            if component.genus != 0 or len(component.boundary_cycles) != 1:
                diagnostics.append(Diagnostic('residual_topology',
                    f'Complement has genus {component.genus} and {len(component.boundary_cycles)} boundaries; expected a disk',
                    component.faces))
            if component.interior_marks:
                diagnostics.append(Diagnostic('interior_marks', 'Complement retains interior marked points', component.interior_marks))
        return CutReport(full, complement, tuple(diagnostics), scope, vertices)
    except _Invalid as error:
        return CutReport(full, complement, (error.diagnostic,), scope, vertices)
