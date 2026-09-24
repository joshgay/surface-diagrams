class_name WorkspaceRecovery
extends RefCounted

const FORMAT := "surface-diagrams-studio-recovery"
const VERSION := 2
const LEGACY_VERSION := 1
const LEGACY_MAX_BYTES := 1024 * 1024
# A compact history contains at most 101 distinct endpoint documents. The 32 MiB
# import cap is explicit and comfortably covers the exercised maximum structural
# fixture; JSON escaping still counts toward the cap and can cause rejection.
const MAX_BYTES := 32 * 1024 * 1024
const PATH := "user://workspace-recovery-v2.json"
const BACKUP_PATH := "user://workspace-recovery-v2.last-good.json"
const LEGACY_PATH := "user://workspace-recovery-v1.json"
const SLOT_FORMAT := "surface-diagrams-studio-recovery-slot"
const SLOT_VERSION := 1
const MAX_SLOT_BYTES := 34 * 1024 * 1024
const MAX_GENERATION := 2147483647

static func encode(baseline_source: String, history: DiagramEditHistory,
		drafts: Dictionary, selection: Dictionary) -> Dictionary:
	if history == null or history.current == null:
		return _failure("Cannot recover an empty workspace")
	var envelope := {
		"format": FORMAT,
		"version": VERSION,
		"baseline": baseline_source,
		"history": history.to_compact_state(),
		"drafts": drafts.duplicate(true),
		"selection": selection.duplicate(true),
	}
	var text := JSON.stringify(envelope, "\t", false, true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Recovery record exceeds 32 MiB")
	var checked := parse(text)
	if not checked.ok:
		return checked
	return {"ok": true, "error": "", "text": text}

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Recovery record exceeds 32 MiB")
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
	if raw.format != FORMAT or not _integer(raw.version) \
			or int(raw.version) not in [LEGACY_VERSION, VERSION]:
		return _failure("Expected %s version 1 or 2" % FORMAT)
	var recovery_version := int(raw.version)
	if recovery_version == LEGACY_VERSION and text.to_utf8_buffer().size() > LEGACY_MAX_BYTES:
		return _failure("Version-1 recovery record exceeds 1 MiB")
	if typeof(raw.baseline) != TYPE_STRING:
		return _failure("Recovery baseline must be JSON text")
	var baseline := DiagramDocument.parse(raw.baseline)
	if not baseline.ok:
		return _failure("Recovery baseline is invalid: " + baseline.error)
	var restored_history := DiagramEditHistory.new()
	var history_result := restored_history.restore_state(raw.history) if recovery_version == LEGACY_VERSION \
		else restored_history.restore_compact_state(raw.history)
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
		"recovery_version": recovery_version,
		"baseline_source": baseline.document.to_json(),
		"history_state": restored_history.to_state(),
		"drafts": drafts_result.value,
		"selection": selection_result.value,
	}

static func load_file() -> Dictionary:
	var scan := _scan_candidates()
	if not scan.found:
		return {"ok": true, "found": false, "error": ""}
	if scan.valid.is_empty():
		return {"ok": false, "found": true,
			"error": "No valid workspace recovery slot: " + "; ".join(scan.errors)}
	var selected: Dictionary = _newest_candidate(scan.valid)
	var result: Dictionary = selected.duplicate(true)
	for key in ["raw_payload", "raw_text", "priority", "path"]:
		result.erase(key)
	result.found = true
	result.generation = selected.generation
	result.slot_version = selected.slot_version
	result.slot_source = selected.slot_source
	result.recovered_from_backup = selected.slot_source == "last-known-good"
	return result

static func save_file(baseline_source: String, history: DiagramEditHistory,
		drafts: Dictionary, selection: Dictionary) -> String:
	var encoded := encode(baseline_source, history, drafts, selection)
	if not encoded.ok:
		return encoded.error
	var payload = JSON.parse_string(encoded.text)
	if typeof(payload) != TYPE_DICTIONARY:
		return "Could not prepare the workspace recovery record"
	var scan := _scan_candidates()
	var generation := 1
	if not scan.valid.is_empty():
		var previous: Dictionary = _newest_candidate(scan.valid)
		if previous.generation >= MAX_GENERATION:
			return "Workspace recovery generation limit reached"
		generation = previous.generation + 1
		if previous.slot_source != "last-known-good":
			var backup_encoded := _encode_slot(previous.raw_payload, previous.generation)
			if not backup_encoded.ok:
				return backup_encoded.error
			var backup_error := _write_verified_slot(BACKUP_PATH, backup_encoded.text,
				previous.generation)
			if not backup_error.is_empty():
				return backup_error
	var slot_encoded := _encode_slot(payload, generation)
	if not slot_encoded.ok:
		return slot_encoded.error
	var write_error := _write_verified_slot(PATH, slot_encoded.text, generation)
	if not write_error.is_empty():
		return write_error
	if scan.valid.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	if FileAccess.file_exists(LEGACY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))
	return ""

static func clear_file() -> void:
	for path: String in [PATH, BACKUP_PATH, LEGACY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var temporary: String = path + ".tmp"
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))

static func parse_slot(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_SLOT_BYTES:
		return _failure("Recovery slot exceeds 34 MiB")
	var parser := JSON.new()
	var code := parser.parse(text)
	if code != OK:
		return _failure("Invalid recovery slot JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("Recovery slot must be an object")
	var duplicate := DiagramDocument._duplicate_field(text)
	if not duplicate.is_empty():
		return _failure("Duplicate recovery slot JSON field: " + duplicate)
	var raw: Dictionary = parser.data
	var fields := _keys(raw, ["format", "version", "generation", "payload", "sha256"])
	if not fields.ok:
		return fields
	if raw.format != SLOT_FORMAT or not _integer(raw.version) or int(raw.version) != SLOT_VERSION:
		return _failure("Expected %s version %d" % [SLOT_FORMAT, SLOT_VERSION])
	if not _integer(raw.generation) or int(raw.generation) < 0 or int(raw.generation) > MAX_GENERATION:
		return _failure("Recovery slot generation is invalid")
	if typeof(raw.payload) != TYPE_DICTIONARY:
		return _failure("Recovery slot payload must be an object")
	if typeof(raw.sha256) != TYPE_STRING or raw.sha256.length() != 64:
		return _failure("Recovery slot checksum is invalid")
	var payload_text := JSON.stringify(raw.payload, "", false, true)
	if _slot_checksum(int(raw.generation), raw.payload) != raw.sha256:
		return _failure("Recovery slot checksum does not match its generation and payload")
	var parsed := parse(payload_text)
	if not parsed.ok:
		return parsed
	parsed.generation = int(raw.generation)
	parsed.slot_version = SLOT_VERSION
	parsed.raw_payload = raw.payload.duplicate(true)
	return parsed

static func _encode_slot(payload: Dictionary, generation: int) -> Dictionary:
	if generation < 0 or generation > MAX_GENERATION:
		return _failure("Recovery slot generation is invalid")
	var payload_text := JSON.stringify(payload, "", false, true)
	var parsed := parse(payload_text)
	if not parsed.ok:
		return parsed
	var slot := {
		"format": SLOT_FORMAT,
		"version": SLOT_VERSION,
		"generation": generation,
		"payload": payload.duplicate(true),
		"sha256": _slot_checksum(generation, payload),
	}
	var text := JSON.stringify(slot, "\t", false, true) + "\n"
	if text.to_utf8_buffer().size() > MAX_SLOT_BYTES:
		return _failure("Recovery slot exceeds 34 MiB")
	var checked := parse_slot(text)
	if not checked.ok:
		return checked
	return {"ok": true, "error": "", "text": text}

static func _scan_candidates() -> Dictionary:
	var valid: Array[Dictionary] = []
	var errors: Array[String] = []
	var found := false
	for specification in [
		{"path": PATH, "source": "primary", "priority": 3, "allow_raw": true},
		{"path": BACKUP_PATH, "source": "last-known-good", "priority": 2, "allow_raw": false},
		{"path": LEGACY_PATH, "source": "legacy", "priority": 1, "allow_raw": true},
	]:
		var candidate := _read_candidate(specification.path, specification.source,
			specification.priority, specification.allow_raw)
		if not candidate.found:
			continue
		found = true
		if candidate.ok:
			valid.append(candidate)
		else:
			errors.append("%s: %s" % [specification.source, candidate.error])
	return {"found": found, "valid": valid, "errors": errors}

static func _read_candidate(path: String, source: String, priority: int,
		allow_raw: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "found": false, "error": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "found": true, "error": "Could not read file"}
	if file.get_length() > MAX_SLOT_BYTES:
		return {"ok": false, "found": true, "error": "File exceeds 34 MiB"}
	var text := file.get_as_text()
	var slot := parse_slot(text)
	if slot.ok:
		slot.found = true
		slot.path = path
		slot.slot_source = source
		slot.priority = priority
		slot.raw_text = text
		return slot
	if allow_raw:
		var raw := parse(text)
		if raw.ok:
			raw.found = true
			raw.path = path
			raw.slot_source = source
			raw.slot_version = 0
			raw.generation = 0
			raw.priority = priority
			raw.raw_text = text
			raw.raw_payload = JSON.parse_string(text)
			return raw
		return {"ok": false, "found": true, "error": raw.error}
	return {"ok": false, "found": true, "error": slot.error}

static func _newest_candidate(candidates: Array[Dictionary]) -> Dictionary:
	var newest: Dictionary = candidates[0]
	for candidate in candidates.slice(1):
		if candidate.generation > newest.generation or (candidate.generation == newest.generation \
				and candidate.priority > newest.priority):
			newest = candidate
	return newest

static func _write_verified_slot(path: String, text: String, generation: int) -> String:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Could not write the workspace recovery slot"
	file.store_string(text)
	file.close()
	var temporary_file := FileAccess.open(temporary, FileAccess.READ)
	if temporary_file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "Could not verify the workspace recovery slot"
	var checked := parse_slot(temporary_file.get_as_text())
	if not checked.ok or checked.generation != generation:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "Could not verify the workspace recovery slot"
	var temporary_absolute := ProjectSettings.globalize_path(temporary)
	var target_absolute := ProjectSettings.globalize_path(path)
	var rename_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error == ERR_ALREADY_EXISTS:
		DirAccess.remove_absolute(target_absolute)
		rename_error = DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return "Could not replace the workspace recovery slot"
	var installed := FileAccess.open(path, FileAccess.READ)
	if installed == null:
		return "Could not reopen the workspace recovery slot"
	checked = parse_slot(installed.get_as_text())
	if not checked.ok or checked.generation != generation:
		return "Installed workspace recovery slot failed verification"
	return ""

static func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

static func _slot_checksum(generation: int, payload: Dictionary) -> String:
	return _sha256_text(JSON.stringify({
		"format": SLOT_FORMAT,
		"version": SLOT_VERSION,
		"generation": generation,
		"payload": payload,
	}, "", false, true))

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
