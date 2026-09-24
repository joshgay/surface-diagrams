class_name WorkspaceViewState
extends RefCounted

# Native presentation data is deliberately separate from DiagramDocument. This
# envelope is bounded and declarative; it cannot name a script or resource.
const FORMAT := "surface-diagrams-studio-view-state"
const VERSION := 1
const MAX_PAN := 1000000.0

static func defaults(document: DiagramDocument) -> Dictionary:
	var direction := ""
	var playhead := -1.0
	if document != null and document.data.kind == "braid":
		direction = document.data.braid.direction
		playhead = float(document.data.braid.word.size())
	return {
		"format": FORMAT,
		"version": VERSION,
		"camera": {"zoom": 1.0, "pan": [0.0, 0.0]},
		"braid": {"playhead": playhead, "presentation": direction},
		"panels": {"records": false, "source": false, "move_points": false},
	}

static func capture(document: DiagramDocument, canvas: DiagramCanvas,
		braid_editor: BraidEditor, showing_records: bool, source_visible: bool,
		move_points: bool) -> Dictionary:
	var value := defaults(document)
	if canvas != null:
		value.camera = {"zoom": canvas.zoom, "pan": [canvas.pan.x, canvas.pan.y]}
	if document != null and document.data.kind == "braid" and braid_editor != null:
		value.braid = {"playhead": braid_editor.playhead,
			"presentation": braid_editor.direction}
	value.panels = {"records": showing_records, "source": source_visible,
		"move_points": move_points}
	return value

static func normalize(value: Variant, document: DiagramDocument) -> Dictionary:
	if document == null:
		return _failure("View state needs a mathematical record")
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("View state must be an object")
	var raw: Dictionary = value
	var fields := _keys(raw, ["format", "version", "camera", "braid", "panels"])
	if not fields.ok:
		return fields
	if raw.format != FORMAT or not _integer(raw.version) or int(raw.version) != VERSION:
		return _failure("Expected %s version %d" % [FORMAT, VERSION])
	if typeof(raw.camera) != TYPE_DICTIONARY:
		return _failure("View camera must be an object")
	fields = _keys(raw.camera, ["zoom", "pan"])
	if not fields.ok:
		return fields
	if not _finite_number(raw.camera.zoom) or float(raw.camera.zoom) < 0.25 or float(raw.camera.zoom) > 4.0:
		return _failure("View zoom is outside the supported range")
	if typeof(raw.camera.pan) != TYPE_ARRAY or raw.camera.pan.size() != 2:
		return _failure("View pan must contain two coordinates")
	for coordinate in raw.camera.pan:
		if not _finite_number(coordinate) or absf(float(coordinate)) > MAX_PAN:
			return _failure("View pan coordinate is outside the supported range")
	if typeof(raw.braid) != TYPE_DICTIONARY:
		return _failure("Braid view must be an object")
	fields = _keys(raw.braid, ["playhead", "presentation"])
	if not fields.ok:
		return fields
	if not _finite_number(raw.braid.playhead) or typeof(raw.braid.presentation) != TYPE_STRING:
		return _failure("Braid view is invalid")
	var playhead := float(raw.braid.playhead)
	var presentation: String = raw.braid.presentation
	if document.data.kind == "braid":
		if playhead < 0.0 or playhead > document.data.braid.word.size():
			return _failure("Braid playhead is outside the literal supplied word")
		if presentation not in ["bottom-to-top", "top-to-bottom"]:
			return _failure("Braid presentation is invalid")
	elif playhead != -1.0 or not presentation.is_empty():
		return _failure("Planar view state cannot contain braid playback")
	if typeof(raw.panels) != TYPE_DICTIONARY:
		return _failure("Panel state must be an object")
	fields = _keys(raw.panels, ["records", "source", "move_points"])
	if not fields.ok:
		return fields
	for key in ["records", "source", "move_points"]:
		if typeof(raw.panels[key]) != TYPE_BOOL:
			return _failure("Panel field %s must be boolean" % key)
	return {"ok": true, "error": "", "value": {
		"format": FORMAT,
		"version": VERSION,
		"camera": {"zoom": float(raw.camera.zoom),
			"pan": [float(raw.camera.pan[0]), float(raw.camera.pan[1])]},
		"braid": {"playhead": playhead, "presentation": presentation},
		"panels": {"records": raw.panels.records, "source": raw.panels.source,
			"move_points": raw.panels.move_points},
	}}

static func _keys(value: Dictionary, expected: Array) -> Dictionary:
	for key in value.keys():
		if key not in expected:
			return _failure("View state has unknown field " + str(key))
	for key in expected:
		if not value.has(key):
			return _failure("View state is missing " + str(key))
	return {"ok": true, "error": ""}

static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT \
		and is_finite(value) and value == floor(value))

static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
