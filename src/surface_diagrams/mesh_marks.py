"""Supplementary mesh cuts reaching automatically placed marked vertices."""
from dataclasses import replace
from heapq import heappop, heappush

from .cut_systems import Mark, ParentCut, Attachment, _prepare, _reconstruct
from .standard_cuts import CutSystem
from .disk_routes import ItineraryError


def mark_mesh(system, triangles, sites, names):
    cell = system.cellulation
    _, vertices, vertex_of = _reconstruct(cell, _prepare(cell, system.surface))
    faces = {f.id:f for f in cell.faces}
    following = {s:f.sides[(i+1)%3] for f in cell.faces for i,s in enumerate(f.sides)}
    pairs = {s:p for p in cell.pairs for s in (p.first,p.second)}
    front = {s for t in triangles if t.sheet == 'front' for s in faces[t.face].sides}
    back = {s for t in triangles if t.sheet == 'back' for s in faces[t.face].sides}
    seam = {vertex_of[s] for s in front} & {vertex_of[s] for s in back}
    graph = {}
    for side in sorted(front):
        a,b = vertex_of[side],vertex_of[following[side]]
        if a not in seam and b not in seam:
            graph.setdefault(a, []).append((b,side))
    parents, marks, attachments, cuts = list(cell.parents), [], [], list(cell.cuts)
    for name,site in zip(names,sites):
        target = vertex_of[site]
        memberships = {}
        degrees = {}
        for parent in parents:
            for side in parent.walk:
                for vertex in (vertex_of[side],vertex_of[following[side]]):
                    memberships.setdefault(vertex,set()).add(parent.id)
                    degrees[vertex] = degrees.get(vertex,0)+1
        eligible = {v for v in memberships if len(memberships[v]) == 1 and degrees[v] == 2 and v not in seam}
        # Unit mesh-edge weights keep the combinatorial cut unchanged by views
        # or geometric scaling. Stop at the first admissible chain vertex.
        queue = [(0,target)]
        previous = {target:None}
        anchor = None
        while queue:
            distance,vertex = heappop(queue)
            if vertex in eligible:
                anchor = vertex
                break
            for other,side in graph.get(vertex,()):
                if other in previous or (other in memberships and other not in eligible):
                    continue
                previous[other] = (vertex,side)
                heappush(queue,(distance+1,other))
        if anchor is None:
            raise ItineraryError('no disjoint supplementary mesh cut reaches mark '+name)
        backward = []
        vertex = anchor
        while previous[vertex] is not None:
            vertex,side = previous[vertex]
            pair = pairs[side]
            backward.append(pair.second if side == pair.first else pair.first)
        walk = tuple(backward)
        if not walk:
            raise ItineraryError('automatic mark lies on an existing cut')
        parent_id = 'mark:'+name
        number = len(parents)+1
        parents.append(ParentCut(parent_id,number,'arc',walk,(walk[0],site)))
        marks.append(Mark(name,corner=site))
        attachments.append(Attachment(walk[0],parent_id,next(iter(memberships[anchor]))))
        cuts.extend(pairs[s].id for s in walk)
    result = CutSystem(replace(cell,parents=tuple(parents),marks=tuple(marks),
                               attachments=cell.attachments+tuple(attachments),cuts=tuple(cuts)),
                       replace(system.surface,marks=tuple(names)))
    report = result.validate()
    if not report.certified:
        raise ItineraryError('marked mesh failed certification: '+str(report.diagnostics))
    return result
