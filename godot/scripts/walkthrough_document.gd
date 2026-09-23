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
		if parsed.document.data.kind != "planar":
			return DiagramDocument._failure("Walkthrough version 1 supports complete planar states only")
		normalized_documents[id] = parsed.document.to_dict()
	if typeof(raw.initial_state) != TYPE_STRING or not normalized_documents.has(raw.initial_state):
		return DiagramDocument._failure("Unknown initial_state reference")
	var signature := _signature(DiagramDocument.new(normalized_documents[raw.initial_state]))
	for id in normalized_documents:
		if _signature(DiagramDocument.new(normalized_documents[id])) != signature:
			return DiagramDocument._failure("Every supplied state must preserve stable IDs, kinds, and order")
	if typeof(raw.steps) != TYPE_ARRAY or raw.steps.is_empty() or raw.steps.size() > MAX_STEPS:
		return DiagramDocument._failure("Walkthrough needs 1..64 supplied steps")
	var normalized_steps: Array = []
	var step_ids := {}
	var expected_before: String = raw.initial_state
	for index in raw.steps.size():
		var step = raw.steps[index]
		fields = ["id", "name", "operation", "before", "after", "selected", "provenance", "verification"]
		check = DiagramDocument._keys(step, fields, fields, "steps[%d]" % index)
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
		normalized_steps.append({"id": step.id, "name": step.name, "operation": step.operation,
			"before": step.before, "after": step.after, "selected": selected_result.value,
			"provenance": provenance_result.value, "verification": verification_result.value})
	return {"ok": true, "document": WalkthroughDocument.new({"format": FORMAT,
		"version": 1, "title": raw.title, "documents": normalized_documents,
		"initial_state": raw.initial_state, "steps": normalized_steps}), "error": ""}

static func _signature(document: DiagramDocument) -> Dictionary:
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
		for item in signature[kind]: allowed[kind + ":" + item[0]] = true
	var seen := {}
	var normalized: Array = []
	for index in value.size():
		var selected = value[index]
		var check := DiagramDocument._keys(selected, ["kind", "id"], ["kind", "id"], "selected[%d]" % index)
		if not check.ok: return check
		if selected.kind not in ["object", "curve", "label"]:
			return DiagramDocument._failure("Selected record kind is unsupported")
		var key: String = selected.kind + ":" + str(selected.id)
		if not allowed.has(key): return DiagramDocument._failure("Selected stable record is absent from supplied states")
		if seen.has(key): return DiagramDocument._failure("Selected records must be distinct")
		seen[key] = true
		normalized.append({"kind": selected.kind, "id": selected.id})
	return {"ok": true, "value": normalized}

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
