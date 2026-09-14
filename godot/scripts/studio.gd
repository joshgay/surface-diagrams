extends Control

var document: DiagramDocument
var canvas: DiagramCanvas
var record_list: ItemList
var title_label: Label
var status_label: Label
var source_view: TextEdit
var open_dialog: FileDialog
var save_dialog: FileDialog
var export_dialog: FileDialog
var geometry_label: Label
var svg_button: Button
var tikz_button: Button
var undo_button: Button
var redo_button: Button
var geometry_result: Dictionary = {"ok": false, "error": "Not rendered", "svg": "", "tikz": ""}
var export_kind := ""
var history := DiagramEditHistory.new()
var candidate_geometry: Dictionary = {}
var browser_mode := OS.has_feature("web")
var browser_drafts: CheckButton
var upload_callback: JavaScriptObject

func _ready() -> void:
	_build_interface()
	if browser_mode and OS.has_feature("web"):
		upload_callback = JavaScriptBridge.create_callback(_browser_file_received)
	_open_resource("res://fixtures/planar-v1.json")

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#f3f6f2")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var brand := Label.new()
	brand.text = "Surface Diagrams Studio"
	brand.add_theme_font_size_override("font_size", 24)
	brand.add_theme_color_override("font_color", Color("#167464"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	for spec in [["Planar fixture", Callable(self, "_open_resource").bind("res://fixtures/planar-v1.json")], ["Braid fixture", Callable(self, "_open_resource").bind("res://fixtures/braid-v1.json")], ["Open JSON", Callable(self, "_show_open")], ["Save JSON", Callable(self, "_show_save")]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		heading.add_child(button)
	if browser_mode:
		browser_drafts = CheckButton.new()
		browser_drafts.text = "Enable unvalidated browser draft editing (no geometry certification or publication export)"
		browser_drafts.tooltip_text = "Only record, neighbor, and ellipse constraints run in this prototype. Downloaded JSON must be validated by the Python library before publication."
		root.add_child(browser_drafts)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 340
	split.add_child(inspector)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(title_label)
	var note := Label.new()
	note.text = "Records are data. Camera changes do not edit IDs, order, cuts, or braid words."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#6b7b78"))
	inspector.add_child(note)
	record_list = ItemList.new()
	record_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	record_list.allow_reselect = true
	record_list.item_selected.connect(_select_record)
	inspector.add_child(record_list)
	var source_button := Button.new()
	source_button.text = "Show normalized source"
	source_button.pressed.connect(func(): source_view.visible = not source_view.visible)
	inspector.add_child(source_button)
	source_view = TextEdit.new()
	source_view.editable = false
	source_view.visible = false
	source_view.custom_minimum_size.y = 220
	inspector.add_child(source_view)
	var canvas_box := VBoxContainer.new()
	split.add_child(canvas_box)
	var canvas_tools := HBoxContainer.new()
	canvas_box.add_child(canvas_tools)
	var fit_button := Button.new()
	fit_button.text = "Fit"
	fit_button.pressed.connect(func(): canvas.fit_view())
	canvas_tools.add_child(fit_button)
	var camera_note := Label.new()
	camera_note.text = "Left drag: edit point/label   Wheel: zoom   Middle drag: pan"
	camera_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_note.add_theme_color_override("font_color", Color("#6b7b78"))
	canvas_tools.add_child(camera_note)
	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.disabled = true
	undo_button.pressed.connect(_undo)
	canvas_tools.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.disabled = true
	redo_button.pressed.connect(_redo)
	canvas_tools.add_child(redo_button)
	svg_button = Button.new()
	svg_button.text = "Export exact SVG"
	svg_button.disabled = true
	svg_button.pressed.connect(Callable(self, "_show_export").bind("svg"))
	canvas_tools.add_child(svg_button)
	tikz_button = Button.new()
	tikz_button.text = "Export exact TikZ"
	tikz_button.disabled = true
	tikz_button.pressed.connect(Callable(self, "_show_export").bind("tikz"))
	canvas_tools.add_child(tikz_button)
	canvas = DiagramCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.focus_mode = Control.FOCUS_ALL
	canvas.mouse_default_cursor_shape = Control.CURSOR_MOVE
	canvas.record_selected.connect(_canvas_record_selected)
	canvas.edit_commit_requested.connect(_canvas_edit_commit)
	canvas.edit_preview_changed.connect(_canvas_preview_changed)
	canvas.edit_rejected.connect(_show_edit_error)
	canvas_box.add_child(canvas)
	geometry_label = Label.new()
	geometry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	geometry_label.add_theme_color_override("font_color", Color("#6b7b78"))
	canvas_box.add_child(geometry_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#415b55"))
	root.add_child(status_label)
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.add_filter("*.json", "Surface diagram JSON")
	open_dialog.file_selected.connect(_open_path)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.add_filter("*.json", "Surface diagram JSON")
	save_dialog.file_selected.connect(_save_path)
	add_child(save_dialog)
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_selected.connect(_save_export)
	add_child(export_dialog)

func _show_open() -> void:
	if browser_mode:
		var files = JavaScriptBridge.get_interface("SurfaceStudioFiles") if OS.has_feature("web") else null
		if files == null:
			_show_edit_error("Browser upload adapter unavailable. The current record is unchanged.")
		else:
			files.open(upload_callback)
		return
	open_dialog.popup_centered_ratio(0.8)

func _show_save() -> void:
	if document == null: return
	if browser_mode:
		var files = JavaScriptBridge.get_interface("SurfaceStudioFiles") if OS.has_feature("web") else null
		if files == null:
			_show_edit_error("Browser download adapter unavailable.")
			return
		var error: String = files.download(document.to_json(), _safe_filename(document.data.title) + "-unvalidated.json")
		if not error.is_empty():
			_show_edit_error(error)
		else:
			status_label.text = "JSON download requested. This browser record is not geometry-validated; validate with the Python library before publication."
		return
	save_dialog.current_file = _safe_filename(document.data.title) + ".json"
	save_dialog.popup_centered_ratio(0.8)

func _show_export(kind: String) -> void:
	if document == null or not geometry_result.ok:
		return
	export_kind = kind
	export_dialog.clear_filters()
	if kind == "svg":
		export_dialog.add_filter("*.svg", "Scalable Vector Graphics")
	else:
		export_dialog.add_filter("*.tikz", "TikZ source")
	export_dialog.current_file = _safe_filename(document.data.title) + (".svg" if kind == "svg" else ".tikz")
	export_dialog.popup_centered_ratio(0.8)

func _open_resource(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_path(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_result(result: Dictionary, path: String) -> void:
	if not result.ok:
		status_label.text = "Not opened: " + result.error
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	history.set_document(result.document)
	if browser_mode:
		browser_drafts.button_pressed = false
	_present_document(result.document, true)
	var mode := "Editable planar record" if document.data.kind == "planar" else "Braid viewer"
	status_label.text = "%s opened from %s. %s; publication geometry remains the Python library's result." % [document.data.kind.capitalize(), path, mode]
	status_label.add_theme_color_override("font_color", Color("#415b55"))
	if browser_mode:
		status_label.text = "Browser proof of concept: inspect records, or explicitly enable unvalidated draft editing. No geometry certification. Save JSON downloads a local file; this site does not upload your data to a server."

func _browser_file_received(arguments: Array) -> void:
	if arguments.size() != 2:
		_show_edit_error("Invalid browser upload response; current record unchanged.")
		return
	var source := str(arguments[0])
	var error := str(arguments[1])
	if not error.is_empty():
		_show_edit_error(error)
	elif not source.is_empty():
		_open_result(DiagramDocument.parse(source), "browser file")

func _present_document(value: DiagramDocument, reset_camera: bool,
		selection: Dictionary = {}, rendered: Dictionary = {}) -> void:
	document = value
	title_label.text = document.data.title
	record_list.clear()
	for record in document.inspector_records():
		record_list.add_item(record.label)
		record_list.set_item_metadata(record_list.item_count - 1, record)
	source_view.text = document.to_json()
	if reset_camera:
		canvas.set_document(document)
	else:
		canvas.update_document(document, selection)
	if not selection.is_empty():
		_select_matching_row(selection)
	geometry_result = _render_geometry(document, rendered)
	svg_button.disabled = not geometry_result.ok
	tikz_button.disabled = not geometry_result.ok
	if geometry_result.ok:
		geometry_label.text = "Python library accepted this recipe. Exact publication SVG and TikZ are ready to export; the interactive canvas remains schematic."
		geometry_label.add_theme_color_override("font_color", Color("#167464"))
	else:
		geometry_label.text = "Exact Python geometry unavailable: " + geometry_result.error
		geometry_label.add_theme_color_override("font_color", Color("#a54439"))
	_update_history_buttons()

func _render_geometry(value: DiagramDocument, rendered: Dictionary = {}) -> Dictionary:
	if browser_mode:
		return {"ok": false, "error": "Browser prototype: record validation only. No curve routing checks or certified SVG/TikZ exports.", "svg": "", "tikz": ""}
	return rendered if rendered.get("ok", false) else PythonGeometryBridge.render(value)

func _save_path(path: String) -> void:
	if not path.to_lower().ends_with(".json"): path += ".json"
	var error := document.save_path(path)
	status_label.text = "Saved exact normalized recipe to " + path if error.is_empty() else error
	status_label.add_theme_color_override("font_color", Color("#415b55") if error.is_empty() else Color("#a54439"))

func _save_export(path: String) -> void:
	if not geometry_result.ok or export_kind not in ["svg", "tikz"]:
		return
	var extension := ".svg" if export_kind == "svg" else ".tikz"
	if not path.to_lower().ends_with(extension):
		path += extension
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status_label.text = "Could not write " + path
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	file.store_string(geometry_result[export_kind])
	status_label.text = "Exported exact Python-library %s to %s" % [export_kind.to_upper(), path]
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _select_record(index: int) -> void:
	var record = record_list.get_item_metadata(index)
	if typeof(record) != TYPE_DICTIONARY:
		return
	canvas.select_record(record)
	var identity := ""
	if not record.id.is_empty():
		identity = " " + record.id
	elif record.index >= 0:
		identity = " %d" % (record.index + 1)
	status_label.text = "Selected %s%s. Selection changes the view only; the mathematical record is unchanged." % [record.kind, identity]
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _canvas_record_selected(record: Dictionary) -> void:
	_select_matching_row(record)
	status_label.text = "Selected %s %s. Drag to preview a move; release validates before the record changes." % [record.kind, record.id]
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _canvas_preview_changed(valid: bool, message: String) -> void:
	status_label.text = "Move preview only; release to validate." if valid else message
	status_label.add_theme_color_override("font_color", Color("#415b55") if valid else Color("#a54439"))

func _canvas_edit_commit(kind: String, id: String, position: Vector2) -> void:
	candidate_geometry = {}
	var result: Dictionary
	if kind == "object":
		result = history.move_object(id, position.x, _validate_candidate_geometry)
	elif kind == "label":
		result = history.move_label(id, position, _validate_candidate_geometry)
	else:
		_show_edit_error("Unsupported editable record kind: " + kind)
		return
	if not result.ok:
		_show_edit_error("Move rejected: " + result.error + ". The last accepted record is unchanged.")
		canvas.update_document(document, {"kind": kind, "id": id})
		return
	_present_document(result.document, false, result.selection, candidate_geometry)
	status_label.text = "%s accepted. IDs, horizontal order, endpoints, cuts, and curve itineraries were preserved." % result.label
	if browser_mode:
		status_label.text = result.label + " stored as an UNVALIDATED browser draft. IDs and order preserved; curve geometry was not checked."
	status_label.add_theme_color_override("font_color", Color("#167464"))

func _validate_candidate_geometry(candidate: DiagramDocument) -> Dictionary:
	if browser_mode:
		if not browser_drafts.button_pressed:
			return {"ok": false, "error": "Enable unvalidated browser draft editing to experiment. Python geometry is unavailable in this prototype"}
		# Explicit opt-in is essential: schema acceptance is NOT geometry acceptance.
		# No successful geometry_result is fabricated, and exports remain disabled.
		return {"ok": true, "geometry_validated": false}
	candidate_geometry = PythonGeometryBridge.render(candidate)
	return candidate_geometry

func _undo() -> void:
	var result := history.undo()
	if not result.ok:
		_show_edit_error(result.error)
		return
	_present_document(result.document, false, result.selection)
	status_label.text = result.label + ". The exact prior recipe was restored."
	status_label.add_theme_color_override("font_color", Color("#167464"))

func _redo() -> void:
	var result := history.redo()
	if not result.ok:
		_show_edit_error(result.error)
		return
	_present_document(result.document, false, result.selection)
	status_label.text = result.label + ". The exact accepted recipe was restored."
	status_label.add_theme_color_override("font_color", Color("#167464"))

func _show_edit_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#a54439"))

func _select_matching_row(selection: Dictionary) -> void:
	for index in record_list.item_count:
		var record = record_list.get_item_metadata(index)
		if typeof(record) == TYPE_DICTIONARY and record.kind == selection.get("kind", "") and record.id == selection.get("id", "") and (not selection.has("index") or record.index == selection.index):
			record_list.select(index)
			canvas.select_record(record)
			return

func _update_history_buttons() -> void:
	undo_button.disabled = not history.can_undo()
	redo_button.disabled = not history.can_redo()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var command: bool = key_event.ctrl_pressed or key_event.meta_pressed
	if command and key_event.keycode == KEY_Z:
		if key_event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	elif command and key_event.keycode == KEY_Y:
		_redo()
		get_viewport().set_input_as_handled()

func _safe_filename(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "-"
	result = result.strip_edges()
	while result.begins_with("-"): result = result.substr(1)
	while result.ends_with("-"): result = result.left(-1)
	return result if not result.is_empty() else "diagram"
