class_name DiagramEditHistory
extends RefCounted

const MAX_HISTORY := 100
const RETENTION_AUDIT_FORMAT := "surface-diagrams-history-retention"
const RETENTION_AUDIT_VERSION := 1

var current: DiagramDocument
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
# Runtime-only parsed targets mirror the public serialized stacks. Recovery and
# interchange remain JSON-only; these snapshots only avoid reparsing records
# which were already accepted by DiagramDocument.
var _undo_targets: Array[Dictionary] = []
var _redo_targets: Array[Dictionary] = []

func set_document(document: DiagramDocument) -> void:
	current = document
	undo_stack.clear()
	redo_stack.clear()
	_undo_targets.clear()
	_redo_targets.clear()

func move_object(id: String, x: float, validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_object_x(id, x)
	if not proposal.ok:
		return proposal
	return _validate_and_commit(proposal.document, validator, "Move object " + id,
		{"kind": "object", "id": id})

func move_label(id: String, position: Vector2, validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_label_position(id, position)
	if not proposal.ok:
		return proposal
	return _validate_and_commit(proposal.document, validator, "Move label " + id,
		{"kind": "label", "id": id})

func set_curve_cuts(id: String, cuts: Array, validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_curve_cuts(id, cuts)
	if not proposal.ok:
		return proposal
	return _validate_and_commit(proposal.document, validator, "Set cuts for curve " + id,
		{"kind": "curve", "id": id})

func add_curve(curve: Dictionary, validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_added_curve(curve)
	if not proposal.ok:
		return proposal
	var id: String = curve.get("id", "")
	return _validate_and_commit(proposal.document, validator, "Create curve " + id,
		{"kind": "curve", "id": id})

func edit_braid_word(action: String, index: int, generator: int = 0,
		validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_braid_word_edit(action, index, generator)
	if not proposal.ok:
		return proposal
	var length: int = proposal.document.data.braid.word.size()
	var selected_index := mini(index, length - 1)
	var selection := {"kind": "crossing", "id": "", "index": selected_index} if length > 0 else {"kind": "braid", "id": "", "index": -1}
	return _validate_and_commit(proposal.document, validator,
		"%s crossing %d" % [action.capitalize(), index + 1], selection)

func reindex_objects(ids: Array, selected_id: String,
		validator: Callable = Callable()) -> Dictionary:
	if current == null:
		return _failure("No document is open")
	var proposal := current.with_object_order(ids)
	if not proposal.ok:
		return proposal
	return _validate_and_commit(proposal.document, validator,
		"Reindex planar object row", {"kind": "object", "id": selected_id})

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func to_state() -> Dictionary:
	return {
		"current": current.to_json() if current != null else "",
		"undo": undo_stack.duplicate(true),
		"redo": redo_stack.duplicate(true),
	}

# Deterministic logical accounting for the bounded history. This intentionally
# does not claim to measure allocator, heap, or process memory: Godot may share
# immutable String storage. Serialized command bytes are the compact UTF-8 JSON
# equivalent of the retained command dictionaries. Snapshot byte counts report
# the source and immutable document slots held by the runtime-only caches.
func retention_audit() -> Dictionary:
	var undo := _stack_retention(undo_stack, _undo_targets, "before")
	var redo := _stack_retention(redo_stack, _redo_targets, "after")
	var current_bytes := current.to_json().to_utf8_buffer().size() if current != null else 0
	var command_count: int = undo.command_count + redo.command_count
	var snapshot_count: int = undo.snapshot_count + redo.snapshot_count
	var command_source_bytes: int = undo.command_source_bytes + redo.command_source_bytes
	var snapshot_source_bytes: int = undo.snapshot_source_bytes + redo.snapshot_source_bytes
	var snapshot_document_bytes: int = undo.snapshot_document_bytes + redo.snapshot_document_bytes
	var logical_source_bytes := command_source_bytes + snapshot_source_bytes + snapshot_document_bytes + current_bytes
	var maximum_logical_source_bytes := (MAX_HISTORY * 4 + 1) * DiagramDocument.MAX_BYTES
	return {
		"format": RETENTION_AUDIT_FORMAT,
		"version": RETENTION_AUDIT_VERSION,
		"history_limit": MAX_HISTORY,
		"undo": undo,
		"redo": redo,
		"totals": {
			"command_count": command_count,
			"serialized_command_bytes": undo.serialized_command_bytes + redo.serialized_command_bytes,
			"command_source_bytes": command_source_bytes,
			"snapshot_count": snapshot_count,
			"snapshot_source_bytes": snapshot_source_bytes,
			"snapshot_document_bytes": snapshot_document_bytes,
			"current_document_bytes": current_bytes,
			"logical_source_bytes": logical_source_bytes,
			"stale_snapshot_count": undo.stale_snapshot_count + redo.stale_snapshot_count,
			"missing_snapshot_count": undo.missing_snapshot_count + redo.missing_snapshot_count,
			"orphan_snapshot_count": undo.orphan_snapshot_count + redo.orphan_snapshot_count,
		},
		"bounds": {
			"maximum_commands": MAX_HISTORY,
			"maximum_document_bytes": DiagramDocument.MAX_BYTES,
			"maximum_command_source_bytes": MAX_HISTORY * 2 * DiagramDocument.MAX_BYTES,
			"maximum_snapshot_source_bytes": MAX_HISTORY * DiagramDocument.MAX_BYTES,
			"maximum_snapshot_document_bytes": MAX_HISTORY * DiagramDocument.MAX_BYTES,
			"maximum_current_document_bytes": DiagramDocument.MAX_BYTES,
			"maximum_logical_source_bytes": maximum_logical_source_bytes,
		},
		"cache_aligned": undo.cache_aligned and redo.cache_aligned,
		"within_source_bounds": command_count <= MAX_HISTORY \
			and snapshot_count <= MAX_HISTORY \
			and command_source_bytes <= MAX_HISTORY * 2 * DiagramDocument.MAX_BYTES \
			and snapshot_source_bytes <= MAX_HISTORY * DiagramDocument.MAX_BYTES \
			and snapshot_document_bytes <= MAX_HISTORY * DiagramDocument.MAX_BYTES \
			and current_bytes <= DiagramDocument.MAX_BYTES \
			and logical_source_bytes <= maximum_logical_source_bytes,
	}

func restore_state(state: Variant) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return _failure("Recovery history must be an object")
	for key in state.keys():
		if key not in ["current", "undo", "redo"]:
			return _failure("Recovery history has unknown field " + str(key))
	for key in ["current", "undo", "redo"]:
		if not state.has(key):
			return _failure("Recovery history is missing " + key)
	if typeof(state.current) != TYPE_STRING:
		return _failure("Recovery current record must be JSON text")
	var parsed_current := DiagramDocument.parse(state.current)
	if not parsed_current.ok:
		return _failure("Recovery current record is invalid: " + parsed_current.error)
	if typeof(state.undo) != TYPE_ARRAY or typeof(state.redo) != TYPE_ARRAY:
		return _failure("Recovery undo and redo histories must be arrays")
	if state.undo.size() + state.redo.size() > MAX_HISTORY:
		return _failure("Recovery history exceeds %d total commands" % MAX_HISTORY)
	var validated_undo: Array[Dictionary] = []
	var validated_redo: Array[Dictionary] = []
	var validated_undo_targets: Array[Dictionary] = []
	var validated_redo_targets: Array[Dictionary] = []
	var expected := ""
	for raw_command in state.undo:
		var checked := _validate_command(raw_command)
		if not checked.ok:
			return checked
		if not expected.is_empty() and checked.command.before != expected:
			return _failure("Recovery undo history is not contiguous")
		expected = checked.command.after
		validated_undo.append(checked.command)
		validated_undo_targets.append(_target(checked.command.before, checked.before_document))
	if not validated_undo.is_empty() and expected != parsed_current.document.to_json():
		return _failure("Recovery undo history does not end at the current record")
	expected = parsed_current.document.to_json()
	for index in range(state.redo.size() - 1, -1, -1):
		var checked := _validate_command(state.redo[index])
		if not checked.ok:
			return checked
		if checked.command.before != expected:
			return _failure("Recovery redo history is not contiguous")
		expected = checked.command.after
		validated_redo.push_front(checked.command)
		validated_redo_targets.push_front(_target(checked.command.after, checked.after_document))
	current = parsed_current.document
	undo_stack = validated_undo
	redo_stack = validated_redo
	_undo_targets = validated_undo_targets
	_redo_targets = validated_redo_targets
	return {"ok": true, "error": "", "document": current}

func undo() -> Dictionary:
	if not can_undo():
		return _failure("Nothing to undo")
	if _undo_targets.size() != undo_stack.size():
		_undo_targets.clear()
	var index := undo_stack.size() - 1
	var command: Dictionary = undo_stack[-1]
	var resolved := _resolve_target(_undo_targets, index, command.before)
	if not resolved.ok:
		return _failure("Stored undo record is invalid: " + resolved.error)
	var after_document := current
	undo_stack.pop_back()
	if not _undo_targets.is_empty():
		_undo_targets.pop_back()
	redo_stack.append(command)
	_redo_targets.append(_target(command.after, after_document) if after_document.to_json() == command.after else {})
	current = resolved.document
	return {"ok": true, "error": "", "document": current,
		"label": "Undo " + command.label, "selection": command.selection.duplicate(true)}

func redo() -> Dictionary:
	if not can_redo():
		return _failure("Nothing to redo")
	if _redo_targets.size() != redo_stack.size():
		_redo_targets.clear()
	var index := redo_stack.size() - 1
	var command: Dictionary = redo_stack[-1]
	var resolved := _resolve_target(_redo_targets, index, command.after)
	if not resolved.ok:
		return _failure("Stored redo record is invalid: " + resolved.error)
	var before_document := current
	redo_stack.pop_back()
	if not _redo_targets.is_empty():
		_redo_targets.pop_back()
	undo_stack.append(command)
	_undo_targets.append(_target(command.before, before_document) if before_document.to_json() == command.before else {})
	current = resolved.document
	return {"ok": true, "error": "", "document": current,
		"label": "Redo " + command.label, "selection": command.selection.duplicate(true)}

func _validate_and_commit(candidate: DiagramDocument, validator: Callable,
		label: String, selection: Dictionary) -> Dictionary:
	if validator.is_valid():
		var validation = validator.call(candidate)
		if typeof(validation) != TYPE_DICTIONARY or not validation.get("ok", false):
			var error: String = validation.get("error", "Candidate validation failed") if typeof(validation) == TYPE_DICTIONARY else "Candidate validator returned an invalid result"
			return _failure(error)
	var command := {"label": label, "selection": selection.duplicate(true),
		"before": current.to_json(), "after": candidate.to_json()}
	undo_stack.append(command)
	_undo_targets.append(_target(command.before, current))
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
		_undo_targets.pop_front()
	redo_stack.clear()
	_redo_targets.clear()
	current = candidate
	return {"ok": true, "error": "", "document": current, "label": label,
		"selection": selection.duplicate(true)}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _target(source: String, document: DiagramDocument) -> Dictionary:
	return {"source": source, "document": document}

static func _stack_retention(commands: Array[Dictionary], targets: Array[Dictionary],
		target_field: String) -> Dictionary:
	var serialized_command_bytes := 0
	var command_source_bytes := 0
	for command in commands:
		serialized_command_bytes += JSON.stringify(command, "", false, true).to_utf8_buffer().size()
		for field in ["before", "after"]:
			var source = command.get(field, null)
			if typeof(source) == TYPE_STRING:
				command_source_bytes += source.to_utf8_buffer().size()
	var snapshot_source_bytes := 0
	var snapshot_document_bytes := 0
	for target in targets:
		var source = target.get("source", null)
		if typeof(source) == TYPE_STRING:
			snapshot_source_bytes += source.to_utf8_buffer().size()
		var document = target.get("document")
		if document is DiagramDocument:
			snapshot_document_bytes += document.to_json().to_utf8_buffer().size()
	var paired := mini(commands.size(), targets.size())
	var stale := 0
	for index in paired:
		var expected = commands[index].get(target_field, null)
		var target: Dictionary = targets[index]
		var source = target.get("source", null)
		var document = target.get("document")
		if typeof(expected) != TYPE_STRING or typeof(source) != TYPE_STRING \
				or source != expected or not (document is DiagramDocument) \
				or document.to_json() != source:
			stale += 1
	var missing := maxi(commands.size() - targets.size(), 0)
	var orphan := maxi(targets.size() - commands.size(), 0)
	var first_source := ""
	var last_source := ""
	if not targets.is_empty():
		if typeof(targets.front().get("source", null)) == TYPE_STRING:
			first_source = targets.front().source
		if typeof(targets.back().get("source", null)) == TYPE_STRING:
			last_source = targets.back().source
	return {
		"command_count": commands.size(),
		"serialized_command_bytes": serialized_command_bytes,
		"command_source_bytes": command_source_bytes,
		"snapshot_count": targets.size(),
		"snapshot_source_bytes": snapshot_source_bytes,
		"snapshot_document_bytes": snapshot_document_bytes,
		"stale_snapshot_count": stale,
		"missing_snapshot_count": missing,
		"orphan_snapshot_count": orphan,
		"first_snapshot_sha256": _sha256_text(first_source),
		"last_snapshot_sha256": _sha256_text(last_source),
		"cache_aligned": stale == 0 and missing == 0 and orphan == 0,
	}

static func _sha256_text(value: String) -> String:
	if value.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

static func _resolve_target(targets: Array[Dictionary], index: int, source: String) -> Dictionary:
	if index >= 0 and index < targets.size():
		var target: Dictionary = targets[index]
		if target.get("source", "") == source and target.get("document") is DiagramDocument:
			return {"ok": true, "error": "", "document": target.document}
	# Serialized stacks are intentionally public and recovery data is untrusted.
	# If a command changed or has no cache, preserve the old parse-and-reject path.
	var parsed := DiagramDocument.parse(source)
	if not parsed.ok:
		return parsed
	return {"ok": true, "error": "", "document": parsed.document}

static func _validate_command(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("Recovery command must be an object")
	for key in value.keys():
		if key not in ["label", "selection", "before", "after"]:
			return _failure("Recovery command has unknown field " + str(key))
	for key in ["label", "selection", "before", "after"]:
		if not value.has(key):
			return _failure("Recovery command is missing " + key)
	if typeof(value.label) != TYPE_STRING or value.label.length() < 1 or value.label.length() > 160:
		return _failure("Recovery command label is invalid")
	if typeof(value.selection) != TYPE_DICTIONARY:
		return _failure("Recovery command selection must be an object")
	for key in value.selection.keys():
		if key not in ["kind", "id", "index"]:
			return _failure("Recovery command selection has unknown field " + str(key))
	if typeof(value.selection.get("kind", "")) != TYPE_STRING or typeof(value.selection.get("id", "")) != TYPE_STRING:
		return _failure("Recovery command selection is invalid")
	if value.selection.has("index") and not _integer(value.selection.index):
		return _failure("Recovery command selection index must be an integer")
	if typeof(value.before) != TYPE_STRING or typeof(value.after) != TYPE_STRING:
		return _failure("Recovery command records must be JSON text")
	var before := DiagramDocument.parse(value.before)
	var after := DiagramDocument.parse(value.after)
	if not before.ok or not after.ok:
		return _failure("Recovery command contains an invalid diagram record")
	var selection: Dictionary = value.selection.duplicate(true)
	if selection.has("index"):
		selection.index = int(selection.index)
	return {"ok": true, "error": "", "command": {
		"label": value.label,
		"selection": selection,
		"before": before.document.to_json(),
		"after": after.document.to_json(),
	}, "before_document": before.document, "after_document": after.document}

static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))
