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

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

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
