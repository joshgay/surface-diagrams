class_name WorkspaceRecovery
extends RefCounted

const FORMAT := "surface-diagrams-studio-recovery"
const VERSION := 1
const MAX_BYTES := 1024 * 1024
const PATH := "user://workspace-recovery-v1.json"

static func encode(baseline_source: String, history: DiagramEditHistory,
		drafts: Dictionary, selection: Dictionary) -> Dictionary:
	if history == null or history.current == null:
		return _failure("Cannot recover an empty workspace")
	var envelope := {
		"format": FORMAT,
		"version": VERSION,
		"baseline": baseline_source,
		"history": history.to_state(),
		"drafts": drafts.duplicate(true),
		"selection": selection.duplicate(true),
	}
	var text := JSON.stringify(envelope, "\t", false, true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Recovery record exceeds 1 MiB")
	var checked := parse(text)
	if not checked.ok:
		return checked
	return {"ok": true, "error": "", "text": text}

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Recovery record exceeds 1 MiB")
	var parser := JSON.new()
	var code := parser.parse(text)
	if code != OK:
		return _failure("Invalid recovery JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("Recovery record must be an object")
	var duplicate := DiagramDocument._duplicate_field(text)
	if not duplicate.is_empty():
		return _failure("Duplicate recovery JSON field: " + duplicate)
	var raw: Dictionary = parser.data
	var fields := _keys(raw, ["format", "version", "baseline", "history", "drafts", "selection"])
	if not fields.ok:
		return fields
	if raw.format != FORMAT or not _integer(raw.version) or int(raw.version) != VERSION:
		return _failure("Expected %s version %d" % [FORMAT, VERSION])
	if typeof(raw.baseline) != TYPE_STRING:
		return _failure("Recovery baseline must be JSON text")
	var baseline := DiagramDocument.parse(raw.baseline)
	if not baseline.ok:
		return _failure("Recovery baseline is invalid: " + baseline.error)
	var restored_history := DiagramEditHistory.new()
	var history_result := restored_history.restore_state(raw.history)
	if not history_result.ok:
		return history_result
	if baseline.document.data.kind != restored_history.current.data.kind:
		return _failure("Recovery baseline and current record have different kinds")
	var drafts_result := _drafts(raw.drafts, restored_history.current)
	if not drafts_result.ok:
		return drafts_result
	var selection_result := _selection(raw.selection, restored_history.current)
	if not selection_result.ok:
		return selection_result
	return {
		"ok": true,
		"error": "",
		"baseline_source": baseline.document.to_json(),
		"history_state": restored_history.to_state(),
		"drafts": drafts_result.value,
		"selection": selection_result.value,
	}

static func load_file() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"ok": true, "found": false, "error": ""}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "found": true, "error": "Could not read the workspace recovery record"}
	if file.get_length() > MAX_BYTES:
		return {"ok": false, "found": true, "error": "Recovery record exceeds 1 MiB"}
	var parsed := parse(file.get_as_text())
	parsed.found = true
	return parsed

static func save_file(baseline_source: String, history: DiagramEditHistory,
		drafts: Dictionary, selection: Dictionary) -> String:
	var encoded := encode(baseline_source, history, drafts, selection)
	if not encoded.ok:
		return encoded.error
	var temporary := PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Could not write the workspace recovery record"
	file.store_string(encoded.text)
	file.close()
	var temporary_absolute := ProjectSettings.globalize_path(temporary)
	var target_absolute := ProjectSettings.globalize_path(PATH)
	var rename_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error == ERR_ALREADY_EXISTS:
		DirAccess.remove_absolute(target_absolute)
		rename_error = DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return "Could not replace the workspace recovery record"
	return ""

static func clear_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var temporary := PATH + ".tmp"
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))

static func _drafts(value: Variant, document: DiagramDocument) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("Recovery drafts must be an object")
	if value.size() > DiagramDocument.MAX_CURVES:
		return _failure("Recovery contains too many curve drafts")
	var curves := {}
	if document.data.kind == "planar":
		for curve in document.data.curves:
			curves[curve.id] = true
	var result := {}
	for id in value.keys():
		if typeof(id) != TYPE_STRING or not curves.has(id):
			return _failure("Recovery draft references unknown curve " + str(id))
		var cuts = value[id]
		if typeof(cuts) != TYPE_ARRAY or cuts.size() > DiagramDocument.MAX_CUTS:
			return _failure("Recovery draft for %s exceeds the visit limit" % id)
		var normalized: Array = []
		for cut in cuts:
			if not _integer(cut) or int(cut) < 0 or int(cut) > document.data.surface.objects.size():
				return _failure("Recovery draft for %s has an invalid cut" % id)
			normalized.append(int(cut))
		result[id] = normalized
	return {"ok": true, "error": "", "value": result}

static func _selection(value: Variant, document: DiagramDocument) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("Recovery selection must be an object")
	if value.is_empty():
		return {"ok": true, "error": "", "value": {}}
	for key in value.keys():
		if key not in ["kind", "id", "index"]:
			return _failure("Recovery selection has unknown field " + str(key))
	if typeof(value.get("kind", "")) != TYPE_STRING or typeof(value.get("id", "")) != TYPE_STRING:
		return _failure("Recovery selection is invalid")
	if not value.has("index") or not _integer(value.index):
		return _failure("Recovery selection needs an integer index")
	var normalized := {"kind": value.kind, "id": value.id, "index": int(value.index)}
	for record in document.inspector_records():
		if record.kind == normalized.kind and record.id == normalized.id and record.index == normalized.index:
			return {"ok": true, "error": "", "value": normalized}
	return _failure("Recovery selection does not identify a current record")

static func _keys(value: Dictionary, expected: Array) -> Dictionary:
	for key in value.keys():
		if key not in expected:
			return _failure("Recovery record has unknown field " + str(key))
	for key in expected:
		if not value.has(key):
			return _failure("Recovery record is missing " + key)
	return {"ok": true, "error": ""}

static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
