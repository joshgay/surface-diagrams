class_name FactorWorkspace
extends RefCounted

# A separate versioned presentation envelope. References name supplied records,
# never programs or actions. Selection and camera state do not belong here.
const MAX_FACTORS := 16
const MAX_DOCUMENTS := 33
var _data: Dictionary

func _init(value: Dictionary) -> void:
	_data = value.duplicate(true)

static func parse(source: String) -> Dictionary:
	if source.to_utf8_buffer().size() > DiagramDocument.MAX_BYTES:
		return DiagramDocument._failure("Workspace exceeds 256 KiB")
	var json := JSON.new()
	if json.parse(source) != OK:
		return DiagramDocument._failure("Invalid workspace JSON")
	if not DiagramDocument._duplicate_field(source).is_empty():
		return DiagramDocument._failure("Duplicate workspace JSON field")
	var raw = json.data
	var fields := ["format", "version", "title", "strands", "direction", "documents", "initial_state", "factors"]
	var check := DiagramDocument._keys(raw, fields, fields, "workspace")
	if not check.ok: return check
	if raw.format != "surface-diagrams-factor-workspace" or not DiagramDocument._integer(raw.version) or raw.version != 1:
		return DiagramDocument._failure("Expected factor workspace version 1")
	check = DiagramDocument._text(raw.title, "workspace title", 120)
	if not check.ok: return check
	if not DiagramDocument._integer(raw.strands) or raw.strands < 1 or raw.strands > 32:
		return DiagramDocument._failure("Workspace strands must be 1..32")
	if raw.direction not in ["bottom-to-top", "top-to-bottom"]:
		return DiagramDocument._failure("Invalid workspace direction")
	if typeof(raw.documents) != TYPE_DICTIONARY or raw.documents.size() > MAX_DOCUMENTS:
		return DiagramDocument._failure("Workspace permits at most 33 named diagrams")
	var normalized: Dictionary = raw.duplicate(true)
	for id in raw.documents:
		check = DiagramDocument._record_id(id, "diagram reference")
		if not check.ok: return check
		var parsed := DiagramDocument.parse(JSON.stringify(raw.documents[id]))
		if not parsed.ok: return parsed
		if parsed.document.data.kind != "planar":
			return DiagramDocument._failure("Support and state records must be planar diagrams")
		normalized.documents[id] = parsed.document.to_dict()
	if not _reference(raw.initial_state, raw.documents, true):
		return DiagramDocument._failure("Unknown initial_state reference")
	if typeof(raw.factors) != TYPE_ARRAY or raw.factors.size() > MAX_FACTORS:
		return DiagramDocument._failure("Workspace permits at most 16 factors")
	var ids := {}
	var groups := {}
	var previous_group := ""
	var total := 0
	for factor in raw.factors:
		fields = ["id", "exponent", "group", "support", "braid_word", "after"]
		check = DiagramDocument._keys(factor, fields, fields, "factor")
		if not check.ok: return check
		check = DiagramDocument._record_id(factor.id, "factor ID")
		if not check.ok: return check
		if ids.has(factor.id): return DiagramDocument._failure("Factor IDs must be distinct")
		ids[factor.id] = true
		if not DiagramDocument._integer(factor.exponent) or factor.exponent == 0 or absf(factor.exponent) > 1000000:
			return DiagramDocument._failure("Factor exponent must be a nonzero integer within +/-1000000")
		check = DiagramDocument._text(factor.group, "group", 80)
		if not check.ok: return check
		if not factor.group.is_empty() and factor.group.strip_edges().is_empty():
			return DiagramDocument._failure("Group must not be whitespace only")
		if not factor.group.is_empty() and factor.group != previous_group:
			if groups.has(factor.group): return DiagramDocument._failure("Groups must be contiguous")
			groups[factor.group] = true
		previous_group = factor.group
		if not _reference(factor.support, raw.documents, false) or not _reference(factor.after, raw.documents, true):
			return DiagramDocument._failure("Unknown support or after-state reference")
		check = DiagramDocument._braid({"strands": raw.strands, "word": factor.braid_word})
		if not check.ok: return check
		total += factor.braid_word.size()
		if total > DiagramDocument.MAX_WORD: return DiagramDocument._failure("Combined braid exceeds 128 crossings")
	normalized.version = 1
	normalized.strands = int(raw.strands)
	for factor in normalized.factors:
		factor.exponent = int(factor.exponent)
		for index in factor.braid_word.size(): factor.braid_word[index] = int(factor.braid_word[index])
	return {"ok": true, "workspace": FactorWorkspace.new(normalized), "error": ""}

static func _reference(value: Variant, documents: Dictionary, nullable: bool) -> bool:
	return (value == null and nullable) or (typeof(value) == TYPE_STRING and documents.has(value))

func to_dict() -> Dictionary:
	return _data.duplicate(true)

func to_json() -> String:
	return JSON.stringify(_data, "\t", false, true) + "\n"

func save_path(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "Could not write workspace"
	file.store_string(to_json())
	return ""

func diagram(id: Variant) -> DiagramDocument:
	return DiagramDocument.new(_data.documents[id]) if id != null else null

func braid_document() -> DiagramDocument:
	var word: Array = []
	for factor in _data.factors: word.append_array(factor.braid_word)
	return DiagramDocument.parse(JSON.stringify({"format": "surface-diagrams", "version": 1,
		"kind": "braid", "title": "Supplied concatenated blocks (not a verified lift)",
		"braid": {"strands": _data.strands, "word": word, "direction": _data.direction}})).document

func focus(index: int) -> Dictionary:
	if index < 0 or index >= _data.factors.size(): return {}
	var factor: Dictionary = _data.factors[index]
	var start := 0
	for prior in index: start += _data.factors[prior].braid_word.size()
	var end: int = start + factor.braid_word.size()
	var orders := BraidTimeline.orders(braid_document())
	return {"factor": factor.duplicate(true), "start": start, "end": end,
		"entry_ids": orders[start], "exit_ids": orders[end],
		"before": _data.initial_state if index == 0 else _data.factors[index - 1].after,
		"after": factor.after}

func factor_for_crossing(index: int) -> int:
	var offset := 0
	for row in _data.factors.size():
		var end: int = offset + _data.factors[row].braid_word.size()
		if index >= offset and index < end: return row
		offset = end
	return -1

func complete_states() -> bool:
	if _data.initial_state == null: return false
	for factor in _data.factors:
		if factor.after == null: return false
	return true
