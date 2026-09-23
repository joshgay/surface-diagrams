class_name DiagramEditHistory
extends RefCounted

const MAX_HISTORY := 100

var current: DiagramDocument
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func set_document(document: DiagramDocument) -> void:
	current = document
	undo_stack.clear()
	redo_stack.clear()

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
	if state.undo.size() > MAX_HISTORY or state.redo.size() > MAX_HISTORY:
		return _failure("Recovery history exceeds %d commands" % MAX_HISTORY)
	var validated_undo: Array[Dictionary] = []
	var validated_redo: Array[Dictionary] = []
	var expected := ""
	for raw_command in state.undo:
		var checked := _validate_command(raw_command)
		if not checked.ok:
			return checked
		if not expected.is_empty() and checked.command.before != expected:
			return _failure("Recovery undo history is not contiguous")
		expected = checked.command.after
		validated_undo.append(checked.command)
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
	current = parsed_current.document
	undo_stack = validated_undo
	redo_stack = validated_redo
	return {"ok": true, "error": "", "document": current}

func undo() -> Dictionary:
	if not can_undo():
		return _failure("Nothing to undo")
	var command: Dictionary = undo_stack[-1]
	var parsed := DiagramDocument.parse(command.before)
	if not parsed.ok:
		return _failure("Stored undo record is invalid: " + parsed.error)
	undo_stack.pop_back()
	redo_stack.append(command)
	current = parsed.document
	return {"ok": true, "error": "", "document": current,
		"label": "Undo " + command.label, "selection": command.selection.duplicate(true)}

func redo() -> Dictionary:
	if not can_redo():
		return _failure("Nothing to redo")
	var command: Dictionary = redo_stack[-1]
	var parsed := DiagramDocument.parse(command.after)
	if not parsed.ok:
		return _failure("Stored redo record is invalid: " + parsed.error)
	redo_stack.pop_back()
	undo_stack.append(command)
	current = parsed.document
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
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	current = candidate
	return {"ok": true, "error": "", "document": current, "label": label,
		"selection": selection.duplicate(true)}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

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
	}}

static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))
