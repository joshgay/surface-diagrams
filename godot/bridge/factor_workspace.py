"""Version-1 data-only adapter to the library's literal factor panels.

Partial states remain importable but cannot be exported as a complete action
sequence. No state is computed, and exponents never modify supplied braid words.
"""
import json
import re

from surface_diagrams import DiagramDocument, FactorPanel, FactorizationDiagram, Panel

MAX_BYTES = 256 * 1024
ID = re.compile(r"[A-Za-z][A-Za-z0-9_-]{0,39}\Z")


def keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected.split()):
        raise ValueError(f"{label} requires exactly: {expected}")


def integer(value, low, high):
    return (type(value) in (int, float) and low <= value <= high
            and value == int(value))


def text(value, maximum):
    return isinstance(value, str) and len(value) <= maximum and all(ord(c) >= 32 for c in value)


def identifier(value):
    return isinstance(value, str) and ID.fullmatch(value) is not None


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON field: " + key)
        result[key] = value
    return result


def parse(source):
    if len(source.encode("utf-8")) > MAX_BYTES:
        raise ValueError("workspace exceeds 256 KiB")
    raw = json.loads(source, object_pairs_hook=no_duplicates)
    keys(raw, "format version title strands direction documents initial_state factors", "workspace")
    if raw["format"] != "surface-diagrams-factor-workspace" or not integer(raw["version"], 1, 1):
        raise ValueError("expected factor workspace version 1")
    if not text(raw["title"], 120) or not integer(raw["strands"], 1, 32):
        raise ValueError("invalid title or strand count")
    if raw["direction"] not in ("bottom-to-top", "top-to-bottom"):
        raise ValueError("invalid presentation direction")
    docs = raw["documents"]
    if not isinstance(docs, dict) or len(docs) > 33 or not all(identifier(k) for k in docs):
        raise ValueError("expected at most 33 safe diagram IDs")
    documents = {key: DiagramDocument.from_dict(value) for key, value in docs.items()}
    if any(doc.to_dict()["kind"] != "planar" for doc in documents.values()):
        raise ValueError("support and state diagrams must be planar")

    def reference(value, nullable):
        return (nullable and value is None) or (isinstance(value, str) and value in documents)

    if not reference(raw["initial_state"], True):
        raise ValueError("unknown initial state")
    if not isinstance(raw["factors"], list) or len(raw["factors"]) > 16:
        raise ValueError("expected at most 16 factors")
    ids, groups, previous, total = set(), set(), "", 0
    for factor in raw["factors"]:
        keys(factor, "id exponent group support braid_word after", "factor")
        if not identifier(factor["id"]) or factor["id"] in ids:
            raise ValueError("factor IDs must be safe and distinct")
        ids.add(factor["id"])
        if not integer(factor["exponent"], -1000000, 1000000) or factor["exponent"] == 0:
            raise ValueError("invalid factor exponent")
        group = factor["group"]
        if not text(group, 80) or (group and not group.strip()):
            raise ValueError("invalid group label")
        if group and group != previous:
            if group in groups:
                raise ValueError("groups must be contiguous")
            groups.add(group)
        previous = group
        if not reference(factor["support"], False) or not reference(factor["after"], True):
            raise ValueError("unknown support or after-state reference")
        word = factor["braid_word"]
        if not isinstance(word, list) or any(not integer(g, 1-raw["strands"], raw["strands"]-1) or g == 0 for g in word):
            raise ValueError("invalid signed braid block")
        total += len(word)
        if total > 128:
            raise ValueError("combined braid exceeds 128 crossings")
    return raw, documents


def diagram(source):
    raw, documents = parse(source)
    references = [raw["initial_state"]] + [f["after"] for f in raw["factors"]]
    if any(ref is not None for ref in references) and any(ref is None for ref in references):
        raise ValueError("Incomplete supplied states: export requires all states or no states; nothing is computed")

    def panel(reference):
        if reference is None:
            return None
        doc = documents[reference]
        # Use the document, not doc.diagram(): drawing() retains literal labels.
        return Panel(doc, doc.title, style=doc.style)

    factors = tuple(FactorPanel(f["id"], panel(f["support"]), exponent=int(f["exponent"]),
        braid_word=tuple(int(g) for g in f["braid_word"]), state=panel(f["after"]), group=f["group"])
        for f in raw["factors"])
    return FactorizationDiagram(factors, strands=int(raw["strands"]),
        initial_state=panel(raw["initial_state"]), direction=raw["direction"]), raw["title"]
