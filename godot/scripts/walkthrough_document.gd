class_name WalkthroughDocument
extends RefCounted

# A walkthrough is a chain of complete supplied records. Operation names,
# provenance, and verification are metadata; none of them execute an action.
const FORMAT := "surface-diagrams-walkthrough"
const MAX_DOCUMENTS := 65
const MAX_STEPS := 64
const MAX_SELECTED := 64
const VERIFICATION_STATUSES := ["unverified", "source-asserted", "independently-verified", "machine-verified"]
const PROVENANCE_KINDS := ["original-generic-example", "supplied-record", "published-source"]
var _data: Dictionary

func _init(value: Dictionary) -> void:
	_data = value.duplicate(true)

static func parse(source: String) -> Dictionary:
	if source.to_utf8_buffer().size() > DiagramDocument.MAX_BYTES:
		return DiagramDocument._failure("Walkthrough exceeds 256 KiB")
	var json := JSON.new()
	if json.parse(source) != OK:
		return DiagramDocument._failure("Invalid walkthrough JSON")
	if not DiagramDocument._duplicate_field(source).is_empty():
		return DiagramDocument._failure("Duplicate walkthrough JSON field")
	var raw = json.data
	var fields := ["format", "version", "title", "documents", "initial_state", "steps"]
	var check := DiagramDocument._keys(raw, fields, fields, "walkthrough")
	if not check.ok: return check
	if raw.format != FORMAT or not DiagramDocument._integer(raw.version) or raw.version != 1:
		return DiagramDocument._failure("Expected walkthrough version 1")
	check = DiagramDocument._text(raw.title, "walkthrough title", 120)
	if not check.ok: return check
	if typeof(raw.documents) != TYPE_DICTIONARY or raw.documents.is_empty() or raw.documents.size() > MAX_DOCUMENTS:
		return DiagramDocument._failure("Walkthrough needs 1..65 named documents")
	var normalized_documents := {}
	for id in raw.documents:
		check = DiagramDocument._record_id(id, "document reference")
		if not check.ok: return check
		var parsed := DiagramDocument.parse(JSON.stringify(raw.documents[id]))
		if not parsed.ok: return parsed
		normalized_documents[id] = parsed.document.to_dict()
	if typeof(raw.initial_state) != TYPE_STRING or not normalized_documents.has(raw.initial_state):
		return DiagramDocument._failure("Unknown initial_state reference")
	var initial := DiagramDocument.new(normalized_documents[raw.initial_state])
	var document_kind: String = initial.data.kind
	var signature := _signature(initial)
	for id in normalized_documents:
		var candidate := DiagramDocument.new(normalized_documents[id])
		if candidate.data.kind != document_kind:
			return DiagramDocument._failure("A walkthrough cannot mix planar and braid states")
		if _signature(candidate) != signature:
			return DiagramDocument._failure("Every supplied state must preserve stable IDs, kinds, and order")
		if document_kind == "braid" and not _same_braid_structure(initial, candidate):
			return DiagramDocument._failure("Every braid state must preserve strands, spacing, colors, and stored presentation")
	if typeof(raw.steps) != TYPE_ARRAY or raw.steps.is_empty() or raw.steps.size() > MAX_STEPS:
		return DiagramDocument._failure("Walkthrough needs 1..64 supplied steps")
	var normalized_steps: Array = []
	var step_ids := {}
	var expected_before: String = raw.initial_state
	for index in raw.steps.size():
		var step = raw.steps[index]
		fields = ["id", "name", "operation", "before", "after", "selected", "provenance", "verification"]
		var required := fields.duplicate()
		if document_kind == "braid":
			fields.append("braid")
			required.append("braid")
		check = DiagramDocument._keys(step, fields, required, "steps[%d]" % index)
		if not check.ok: return check
		check = DiagramDocument._record_id(step.id, "step ID")
		if not check.ok: return check
		if step_ids.has(step.id): return DiagramDocument._failure("Step IDs must be distinct")
		step_ids[step.id] = true
		check = DiagramDocument._text(step.name, "step name", 120)
		if not check.ok: return check
		check = DiagramDocument._text(step.operation, "operation label", 120)
		if not check.ok: return check
		if typeof(step.before) != TYPE_STRING or typeof(step.after) != TYPE_STRING or not normalized_documents.has(step.before) or not normalized_documents.has(step.after):
			return DiagramDocument._failure("Step before/after must reference complete supplied states")
		if step.before != expected_before:
			return DiagramDocument._failure("Walkthrough steps must form an explicit continuous chain")
		expected_before = step.after
		var selected_result := _selected(step.selected, signature)
		if not selected_result.ok: return selected_result
		var provenance_result := _provenance(step.provenance)
		if not provenance_result.ok: return provenance_result
		var verification_result := _verification(step.verification)
		if not verification_result.ok: return verification_result
		var normalized_step := {"id": step.id, "name": step.name, "operation": step.operation,
			"before": step.before, "after": step.after, "selected": selected_result.value,
			"provenance": provenance_result.value, "verification": verification_result.value}
		if document_kind == "braid":
			var braid_result := _braid_step(step.braid, DiagramDocument.new(normalized_documents[step.before]), DiagramDocument.new(normalized_documents[step.after]))
			if not braid_result.ok: return braid_result
			normalized_step.braid = braid_result.value
		normalized_steps.append(normalized_step)
	return {"ok": true, "document": WalkthroughDocument.new({"format": FORMAT,
		"version": 1, "title": raw.title, "documents": normalized_documents,
		"initial_state": raw.initial_state, "steps": normalized_steps}), "error": ""}

static func _signature(document: DiagramDocument) -> Dictionary:
	if document.data.kind == "braid":
		var strands: Array = []
		for id in range(1, int(document.data.braid.strands) + 1): strands.append([id, "strand"])
		return {"strand": strands}
	var result := {"object": [], "curve": [], "label": []}
	for object in document.data.surface.objects:
		result.object.append([object.id, object.kind])
	for curve in document.data.curves:
		result.curve.append([curve.id, curve.kind])
	for label in document.data.labels:
		result.label.append([label.id, "label"])
	return result

static func _selected(value: Variant, signature: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.is_empty() or value.size() > MAX_SELECTED:
		return DiagramDocument._failure("Each step needs 1..64 selected stable records")
	var allowed := {}
	for kind in signature:
		for item in signature[kind]: allowed[kind + ":" + str(item[0])] = true
	var seen := {}
	var normalized: Array = []
	for index in value.size():
		var selected = value[index]
		var check := DiagramDocument._keys(selected, ["kind", "id"], ["kind", "id"], "selected[%d]" % index)
		if not check.ok: return check
		if selected.kind not in ["object", "curve", "label", "strand"]:
			return DiagramDocument._failure("Selected record kind is unsupported")
		if selected.kind == "strand" and not DiagramDocument._integer(selected.id):
			return DiagramDocument._failure("Selected strand ID must be an integer")
		var normalized_id: Variant = int(selected.id) if selected.kind == "strand" else selected.id
		var key: String = selected.kind + ":" + str(normalized_id)
		if not allowed.has(key): return DiagramDocument._failure("Selected stable record is absent from supplied states")
		if seen.has(key): return DiagramDocument._failure("Selected records must be distinct")
		seen[key] = true
		normalized.append({"kind": selected.kind, "id": normalized_id})
	return {"ok": true, "value": normalized}

static func _same_braid_structure(a: DiagramDocument, b: DiagramDocument) -> bool:
	var left: Dictionary = a.data.braid
	var right: Dictionary = b.data.braid
	return left.strands == right.strands and left.spacing == right.spacing and left.step == right.step and left.colors == right.colors and left.direction == right.direction

static func _braid_step(value: Variant, before: DiagramDocument, after: DiagramDocument) -> Dictionary:
	var fields := ["word", "entry_ids", "exit_ids"]
	var check := DiagramDocument._keys(value, fields, fields, "braid step")
	if not check.ok: return check
	if typeof(value.word) != TYPE_ARRAY or value.word.is_empty():
		return DiagramDocument._failure("A braid walkthrough step needs a nonempty literal word")
	check = DiagramDocument._braid({"strands": before.data.braid.strands, "word": value.word})
	if not check.ok: return check
	var word: Array = []
	for generator in value.word: word.append(int(generator))
	var expected_word: Array = before.data.braid.word.duplicate()
	expected_word.append_array(word)
	if after.data.braid.word != expected_word:
		return DiagramDocument._failure("Braid after-state must equal the exact before-word plus the supplied step word")
	var entry_result := _strand_order(value.entry_ids, int(before.data.braid.strands), "entry_ids")
	if not entry_result.ok: return entry_result
	var exit_result := _strand_order(value.exit_ids, int(before.data.braid.strands), "exit_ids")
	if not exit_result.ok: return exit_result
	var actual_entry: Array = BraidTimeline.orders(before).back()
	var actual_exit: Array = BraidTimeline.orders(after).back()
	if entry_result.value != actual_entry:
		return DiagramDocument._failure("Supplied entry_ids do not match the complete before-state")
	if exit_result.value != actual_exit or _transport(entry_result.value, word) != exit_result.value:
		return DiagramDocument._failure("Supplied exit_ids do not match literal strand transport")
	return {"ok": true, "value": {"word": word, "entry_ids": entry_result.value, "exit_ids": exit_result.value}}

static func _strand_order(value: Variant, strands: int, where: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.size() != strands:
		return DiagramDocument._failure(where + " must list every strand identity exactly once")
	var normalized: Array = []
	for id in value:
		if not DiagramDocument._integer(id) or int(id) < 1 or int(id) > strands or int(id) in normalized:
			return DiagramDocument._failure(where + " must be a permutation of 1..n")
		normalized.append(int(id))
	return {"ok": true, "value": normalized}

static func _transport(entry: Array, word: Array) -> Array:
	var order := entry.duplicate()
	for generator in word:
		var left := absi(int(generator)) - 1
		var swap = order[left]
		order[left] = order[left + 1]
		order[left + 1] = swap
	return order

static func _provenance(value: Variant) -> Dictionary:
	var fields := ["kind", "source", "note"]
	var check := DiagramDocument._keys(value, fields, fields, "step provenance")
	if not check.ok: return check
	if value.kind not in PROVENANCE_KINDS:
		return DiagramDocument._failure("Unknown provenance kind")
	for field in ["source", "note"]:
		check = DiagramDocument._text(value[field], "provenance " + field, 500)
		if not check.ok: return check
	return {"ok": true, "value": {"kind": value.kind, "source": value.source, "note": value.note}}

static func _verification(value: Variant) -> Dictionary:
	var fields := ["status", "authority", "note"]
	var check := DiagramDocument._keys(value, fields, fields, "step verification")
	if not check.ok: return check
	if value.status not in VERIFICATION_STATUSES:
		return DiagramDocument._failure("Unknown verification status")
	for field in ["authority", "note"]:
		check = DiagramDocument._text(value[field], "verification " + field, 500)
		if not check.ok: return check
	return {"ok": true, "value": {"status": value.status, "authority": value.authority, "note": value.note}}

func to_dict() -> Dictionary:
	return _data.duplicate(true)

func to_json() -> String:
	return JSON.stringify(_data, "\t", false, true) + "\n"

func save_path(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "Could not write walkthrough"
	file.store_string(to_json())
	return ""

func diagram(id: String) -> DiagramDocument:
	return DiagramDocument.new(_data.documents[id]) if _data.documents.has(id) else null

func step(index: int) -> Dictionary:
	return _data.steps[index].duplicate(true) if index >= 0 and index < _data.steps.size() else {}

func final_state() -> String:
	return _data.steps.back().after

func kind() -> String:
	return diagram(_data.initial_state).data.kind
