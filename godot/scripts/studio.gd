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
var curve_inspector: CurveInspector
var curve_creator: CurveCreator
var braid_editor: BraidEditor
var geometry_result: Dictionary = {"ok": false, "error": "Not rendered", "svg": "", "tikz": ""}
var export_kind := ""
var history := DiagramEditHistory.new()
var candidate_geometry: Dictionary = {}
var browser_mode := OS.has_feature("web")
var browser_drafts: CheckButton
var upload_callback: JavaScriptObject
var baseline_source := ""
var pending_action: Callable
var pending_description := ""
var unsaved_dialog: ConfirmationDialog
var recovery_dialog: ConfirmationDialog
var startup_recovery: Dictionary = {}
var recovery_error := ""
var row_reindex_panel: HFlowContainer
var row_reindex_label: Label
var reindex_left_button: Button
var reindex_right_button: Button
var reindex_dialog: ConfirmationDialog
var reindex_preview: TextEdit
var pending_reindex: Dictionary = {}
var pending_reindex_geometry: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_interface()
	if browser_mode and OS.has_feature("web"):
		upload_callback = JavaScriptBridge.create_callback(_browser_file_received)
	_open_result(DiagramDocument.load_path("res://fixtures/planar-v1.json"), "res://fixtures/planar-v1.json", false)
	if not browser_mode:
		_offer_recovery()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#f3f6f2")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var heading := HFlowContainer.new()
	root.add_child(heading)
	var brand := Label.new()
	brand.text = "Surface Diagrams Studio"
	brand.add_theme_font_size_override("font_size", 24)
	brand.add_theme_color_override("font_color", Color("#167464"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	for spec in [["Planar fixture", Callable(self, "_open_resource").bind("res://fixtures/planar-v1.json")], ["Multi-curve fixture", Callable(self, "_open_resource").bind("res://fixtures/multi-curve-v1.json")], ["Braid fixture", Callable(self, "_open_resource").bind("res://fixtures/braid-v1.json")], ["Open JSON", Callable(self, "_show_open")], ["Save JSON", Callable(self, "_show_save")]]:
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
	row_reindex_panel = HFlowContainer.new()
	row_reindex_panel.visible = false
	inspector.add_child(row_reindex_panel)
	row_reindex_label = Label.new()
	row_reindex_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row_reindex_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_reindex_panel.add_child(row_reindex_label)
	reindex_left_button = Button.new()
	reindex_left_button.text = "Reindex one slot left"
	reindex_left_button.pressed.connect(Callable(self, "_request_reindex").bind(-1))
	row_reindex_panel.add_child(reindex_left_button)
	reindex_right_button = Button.new()
	reindex_right_button.text = "Reindex one slot right"
	reindex_right_button.pressed.connect(Callable(self, "_request_reindex").bind(1))
	row_reindex_panel.add_child(reindex_right_button)
	curve_inspector = CurveInspector.new()
	curve_inspector.apply_requested.connect(_apply_curve_cuts)
	curve_inspector.draft_changed.connect(_curve_draft_changed)
	inspector.add_child(curve_inspector)
	curve_creator = CurveCreator.new()
	curve_creator.create_requested.connect(_create_curve)
	curve_creator.draft_changed.connect(_creation_draft_changed)
	inspector.add_child(curve_creator)
	braid_editor = BraidEditor.new()
	braid_editor.edit_requested.connect(_edit_braid_word)
	braid_editor.view_changed.connect(_braid_view_changed)
	braid_editor.selection_requested.connect(_braid_selection_requested)
	inspector.add_child(braid_editor)
	var source_button := Button.new()
	source_button.text = "Show accepted source"
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
	canvas.cut_picked.connect(_cut_picked)
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
	unsaved_dialog = ConfirmationDialog.new()
	unsaved_dialog.title = "Unsaved workspace changes"
	unsaved_dialog.ok_button_text = "Discard and continue"
	unsaved_dialog.get_cancel_button().text = "Cancel"
	unsaved_dialog.confirmed.connect(_discard_and_continue)
	unsaved_dialog.canceled.connect(_cancel_pending_action)
	add_child(unsaved_dialog)
	recovery_dialog = ConfirmationDialog.new()
	recovery_dialog.title = "Recovered workspace found"
	recovery_dialog.ok_button_text = "Restore recovered work"
	recovery_dialog.get_cancel_button().text = "Discard recovery"
	recovery_dialog.confirmed.connect(_restore_startup_recovery)
	recovery_dialog.canceled.connect(_discard_startup_recovery)
	add_child(recovery_dialog)
	reindex_dialog = ConfirmationDialog.new()
	reindex_dialog.title = "Confirm explicit row reindex"
	reindex_dialog.ok_button_text = "Apply validated reindex"
	reindex_dialog.get_cancel_button().text = "Cancel"
	reindex_dialog.dialog_text = "This moves stable object records between fixed numbered slots. Review every changed endpoint attachment and cut corridor below."
	reindex_dialog.confirmed.connect(_confirm_reindex)
	reindex_dialog.canceled.connect(_cancel_reindex)
	reindex_preview = TextEdit.new()
	reindex_preview.editable = false
	reindex_preview.custom_minimum_size = Vector2(720, 340)
	reindex_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	reindex_dialog.add_child(reindex_preview)
	add_child(reindex_dialog)

func _show_open() -> void:
	if _request_before_destructive_action(Callable(self, "_show_open_after_guard"), "open another JSON file"):
		_show_open_after_guard()

func _show_open_after_guard() -> void:
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
			baseline_source = document.to_json()
			if not curve_inspector.drafts.is_empty() or curve_creator.active:
				status_label.text += " Unapplied curve drafts are NOT in this download."
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
	var action := Callable(self, "_open_resource_after_guard").bind(path)
	if _request_before_destructive_action(action, "open " + path.get_file()):
		action.call()

func _open_resource_after_guard(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_path(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_result(result: Dictionary, path: String, clear_recovery: bool = true) -> void:
	if not result.ok:
		status_label.text = "Not opened: " + result.error
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	history.set_document(result.document)
	curve_inspector.clear_drafts()
	curve_creator.finish_success()
	baseline_source = result.document.to_json()
	if clear_recovery:
		WorkspaceRecovery.clear_file()
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
	curve_inspector.inspect(document, selection)
	curve_creator.configure(document)
	braid_editor.configure(document, selection, reset_camera)
	_refresh_reindex_controls(selection)
	_refresh_draft_markers()
	if selection.get("kind", "") != "curve":
		canvas.set_curve_draft("", [])
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
	if error.is_empty():
		baseline_source = document.to_json()
	status_label.text = "Saved exact normalized recipe to " + path if error.is_empty() else error
	if error.is_empty() and (not curve_inspector.drafts.is_empty() or curve_creator.active):
		status_label.text += " Unapplied curve drafts remain in memory and are NOT in this file."
	status_label.add_theme_color_override("font_color", Color("#415b55") if error.is_empty() else Color("#a54439"))
	if error.is_empty():
		_persist_recovery()

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
	curve_inspector.inspect(document, record)
	braid_editor.inspect(record)
	_refresh_reindex_controls(record)
	if record.kind != "curve":
		canvas.set_curve_draft("", [])
	var identity := ""
	if not record.id.is_empty():
		identity = " " + record.id
	elif record.index >= 0:
		identity = " %d" % (record.index + 1)
	status_label.text = "Selected %s%s. Selection changes the view only; the mathematical record is unchanged." % [record.kind, identity]
	status_label.add_theme_color_override("font_color", Color("#415b55"))
	_persist_recovery()

func _canvas_record_selected(record: Dictionary) -> void:
	_select_matching_row(record)
	curve_inspector.inspect(document, record)
	braid_editor.inspect(record)
	_refresh_reindex_controls(record)
	canvas.set_curve_draft("", [])
	status_label.text = "Selected %s %s. Drag to preview a move; release validates before the record changes." % [record.kind, record.id]
	if record.kind == "crossing":
		status_label.text = "Selected crossing %d. Its signed generator and transported strand IDs are shown in the inspector." % (record.index + 1)
	status_label.add_theme_color_override("font_color", Color("#415b55"))
	_persist_recovery()

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
	_persist_recovery()

func _curve_draft_changed(id: String, cuts: Array, message: String) -> void:
	canvas.set_curve_draft(id, cuts)
	_refresh_draft_markers()
	if not id.is_empty():
		status_label.text = "%s Draft cuts=%s" % [message, cuts]
		status_label.add_theme_color_override("font_color", Color("#415b55"))
	_persist_recovery()

func _cut_picked(cut: int) -> void:
	if curve_creator.active:
		curve_creator.append_cut(cut)
	else:
		curve_inspector.append_cut(cut)

func _creation_draft_changed(is_active: bool, curve: Dictionary, message: String) -> void:
	canvas.pick_for_new_curve = is_active
	if is_active:
		canvas.set_curve_draft(str(curve.get("id", "")), curve.get("cuts", []))
	else:
		canvas.set_curve_draft("", [])
	if is_active:
		status_label.text = "%s New %s %s cuts=%s is an in-memory draft only." % [message, curve.get("kind", "curve"), curve.get("id", ""), curve.get("cuts", [])]
		status_label.add_theme_color_override("font_color", Color("#415b55"))
	elif not message.is_empty():
		status_label.text = message + " The accepted record and other curve drafts are unchanged."
		status_label.add_theme_color_override("font_color", Color("#415b55"))

func _create_curve(curve: Dictionary) -> void:
	candidate_geometry = {}
	var result := history.add_curve(curve, _validate_candidate_geometry)
	if not result.ok:
		var message: String = "Curve creation rejected: " + result.error + ". Draft retained; accepted record, history, and every other draft are unchanged."
		curve_creator.show_rejection(message)
		_show_edit_error(message)
		return
	curve_creator.finish_success()
	_present_document(result.document, false, result.selection, candidate_geometry)
	status_label.text = "Created %s %s as one validated command. Stable ID, literal endpoint/orientation fields, and ordered cut visits were preserved exactly." % [curve.get("kind", "curve"), curve.get("id", "")]
	if browser_mode:
		status_label.text = "Created UNVALIDATED browser %s %s as one command. Record schema passed, but Python routing was NOT checked." % [curve.get("kind", "curve"), curve.get("id", "")]
	status_label.add_theme_color_override("font_color", Color("#167464"))
	_persist_recovery()

func _braid_view_changed(playhead: float, direction: String) -> void:
	canvas.set_braid_view(playhead, direction)

func _braid_selection_requested(index: int) -> void:
	if document != null and document.data.kind == "braid":
		_select_matching_row(document.inspector_records()[index + 1])
		_select_record(index + 1)

func _edit_braid_word(action: String, index: int, generator: int) -> void:
	candidate_geometry = {}
	var result := history.edit_braid_word(action, index, generator, _validate_candidate_geometry)
	if not result.ok:
		_show_edit_error("Braid edit rejected: " + result.error + ". The exact source, timeline, and history are unchanged.")
		return
	_present_document(result.document, false, result.selection, candidate_geometry)
	braid_editor.set_step(mini(index + 1, result.document.data.braid.word.size()))
	status_label.text = "%s. Exact signed word and transported IDs are preserved without reduction." % result.label
	if browser_mode:
		status_label.text = result.label + " stored as an UNVALIDATED browser draft. Exact publication exports remain disabled."
	status_label.add_theme_color_override("font_color", Color("#167464"))
	_persist_recovery()

func _refresh_draft_markers() -> void:
	for index in record_list.item_count:
		var record: Dictionary = record_list.get_item_metadata(index)
		var dirty: bool = record.kind == "curve" and curve_inspector.drafts.has(record.id)
		record_list.set_item_text(index, record.label + (" [draft]" if dirty else ""))

func _apply_curve_cuts(id: String, cuts: Array) -> void:
	candidate_geometry = {}
	var result := history.set_curve_cuts(id, cuts, _validate_candidate_geometry)
	if not result.ok:
		_show_edit_error("Itinerary rejected: " + result.error + ". Draft retained; accepted curve and undo history unchanged.")
		return
	curve_inspector.discard_draft(id)
	_present_document(result.document, false, result.selection, candidate_geometry)
	status_label.text = "Applied curve %s cuts exactly as supplied: %s. No visit was sorted, cancelled, or inferred." % [id, cuts]
	if browser_mode:
		status_label.text = "UNVALIDATED browser itinerary draft for %s: %s. Curve routing was NOT checked; publication exports remain disabled." % [id, cuts]
	status_label.add_theme_color_override("font_color", Color("#415b55"))
	_persist_recovery()

func _refresh_reindex_controls(selection: Dictionary) -> void:
	var editable: bool = document != null and document.data.kind == "planar" and selection.get("kind", "") == "object"
	row_reindex_panel.visible = editable
	if not editable:
		return
	var index := -1
	var objects: Array = document.data.surface.objects
	for candidate_index in objects.size():
		if objects[candidate_index].id == selection.get("id", ""):
			index = candidate_index
			break
	row_reindex_label.text = "Explicit row reindex for %s. Ordinary dragging still cannot cross a neighbor." % selection.get("id", "")
	reindex_left_button.disabled = index <= 0
	reindex_right_button.disabled = index < 0 or index >= objects.size() - 1

func _request_reindex(offset: int) -> void:
	if canvas.selected_record.get("kind", "") != "object":
		_show_edit_error("Select a planar object before proposing a row reindex.")
		return
	var proposal := RowReindex.adjacent(document,
		canvas.selected_record.get("id", ""), offset)
	if not proposal.ok:
		_show_edit_error("Reindex not proposed: " + proposal.error)
		return
	candidate_geometry = {}
	var validation := _validate_candidate_geometry(proposal.document)
	if not validation.get("ok", false):
		_show_edit_error("Reindex rejected before confirmation: " + validation.get("error", "Candidate geometry failed") + ". The accepted row, history, recovery, and curve drafts are unchanged.")
		return
	proposal.before_source = document.to_json()
	pending_reindex = proposal
	pending_reindex_geometry = validation.duplicate(true)
	reindex_preview.text = RowReindex.preview_text(proposal)
	reindex_dialog.popup_centered(Vector2i(780, 520))
	status_label.text = "Reindex candidate validated. Review the complete slot, endpoint, and cut impact list before applying."
	if browser_mode:
		status_label.text = "UNVALIDATED browser reindex proposal. Review every slot, endpoint, and cut impact before applying; Python geometry is unavailable."
	status_label.add_theme_color_override("font_color", Color("#a06a1a"))

func _cancel_reindex() -> void:
	reindex_dialog.hide()
	pending_reindex.clear()
	pending_reindex_geometry.clear()
	status_label.text = "Cancelled row reindex. Accepted order, exact history, recovery, and all curve drafts were preserved."
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _confirm_reindex() -> void:
	reindex_dialog.hide()
	if pending_reindex.is_empty():
		return
	if document.to_json() != pending_reindex.before_source or history.current.to_json() != pending_reindex.before_source:
		pending_reindex.clear()
		pending_reindex_geometry.clear()
		_show_edit_error("Reindex proposal became stale; no change was applied.")
		return
	var proposal := pending_reindex.duplicate(true)
	var validated := pending_reindex_geometry.duplicate(true)
	var result := history.reindex_objects(proposal.new_order, proposal.selected_id,
		func(_candidate): return validated)
	pending_reindex.clear()
	pending_reindex_geometry.clear()
	if not result.ok:
		_show_edit_error("Reindex was not applied: " + result.error + ". Accepted order, history, recovery, and drafts are unchanged.")
		return
	_present_document(result.document, false, result.selection, validated)
	status_label.text = "Applied the confirmed row order %s as one command. Stable IDs moved between fixed slots; literal endpoint/cut numbers stayed unchanged, with attachments and corridors changed exactly as previewed." % [proposal.new_order]
	if browser_mode:
		status_label.text = "Applied UNVALIDATED browser row order %s. Slot semantics are exact, but Python geometry was NOT checked." % [proposal.new_order]
	status_label.add_theme_color_override("font_color", Color("#167464"))
	_persist_recovery()

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
	_persist_recovery()

func _redo() -> void:
	var result := history.redo()
	if not result.ok:
		_show_edit_error(result.error)
		return
	_present_document(result.document, false, result.selection)
	status_label.text = result.label + ". The exact accepted recipe was restored."
	status_label.add_theme_color_override("font_color", Color("#167464"))
	_persist_recovery()

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

func _has_unsaved_work() -> bool:
	if document == null:
		return false
	return document.to_json() != baseline_source or not curve_inspector.drafts.is_empty() or curve_creator.active

func _request_before_destructive_action(action: Callable, description: String) -> bool:
	if not _has_unsaved_work():
		return true
	pending_action = action
	pending_description = description
	var accepted_changed := document.to_json() != baseline_source
	var parts: Array[String] = []
	if accepted_changed:
		parts.append("accepted record changes")
	if not curve_inspector.drafts.is_empty():
		parts.append("%d unapplied curve draft%s" % [curve_inspector.drafts.size(), "" if curve_inspector.drafts.size() == 1 else "s"])
	if curve_creator.active:
		parts.append("one unapplied new-curve draft")
	unsaved_dialog.dialog_text = "The workspace has %s. Cancel to keep them, or discard them and %s." % [" and ".join(parts), description]
	unsaved_dialog.popup_centered(Vector2i(560, 220))
	status_label.text = "Waiting for an explicit cancel/discard choice; the current record, history, and drafts are unchanged."
	status_label.add_theme_color_override("font_color", Color("#a06a1a"))
	return false

func _cancel_pending_action() -> void:
	unsaved_dialog.hide()
	var description := pending_description
	pending_action = Callable()
	pending_description = ""
	status_label.text = "Cancelled %s. Accepted records, undo/redo history, and curve drafts were preserved." % description
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _discard_and_continue() -> void:
	unsaved_dialog.hide()
	var action := pending_action
	pending_action = Callable()
	pending_description = ""
	if action.is_valid():
		action.call()

func _persist_recovery() -> void:
	if browser_mode or document == null or baseline_source.is_empty():
		return
	if not startup_recovery.is_empty():
		return
	if not _has_unsaved_work():
		WorkspaceRecovery.clear_file()
		return
	var error := WorkspaceRecovery.save_file(baseline_source, history,
		curve_inspector.drafts, _current_selection())
	if not error.is_empty():
		recovery_error = error
		status_label.text = error + ". The in-memory workspace is unchanged."
		status_label.add_theme_color_override("font_color", Color("#a54439"))

func _current_selection() -> Dictionary:
	if canvas == null or canvas.selected_record.is_empty():
		return {}
	var selection := canvas.selected_record.duplicate(true)
	return {"kind": selection.get("kind", ""), "id": selection.get("id", ""),
		"index": int(selection.get("index", -1))}

func _offer_recovery() -> void:
	var recovered := WorkspaceRecovery.load_file()
	if not recovered.get("found", false):
		return
	if not recovered.ok:
		WorkspaceRecovery.clear_file()
		status_label.text = "Ignored an invalid workspace recovery record: " + recovered.error
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	startup_recovery = recovered
	var drafts: Dictionary = recovered.drafts
	var undo_count: int = recovered.history_state.undo.size()
	var redo_count: int = recovered.history_state.redo.size()
	recovery_dialog.dialog_text = "A bounded version-1 recovery record contains %d curve draft%s, %d undo step%s, and %d redo step%s. Restore it, or explicitly discard it." % [drafts.size(), "" if drafts.size() == 1 else "s", undo_count, "" if undo_count == 1 else "s", redo_count, "" if redo_count == 1 else "s"]
	recovery_dialog.popup_centered(Vector2i(580, 230))
	status_label.text = "Recovered work is available. The initial fixture remains unchanged until you choose Restore or Discard."
	status_label.add_theme_color_override("font_color", Color("#a06a1a"))

func _restore_startup_recovery() -> bool:
	recovery_dialog.hide()
	if startup_recovery.is_empty():
		return false
	var restored := history.restore_state(startup_recovery.history_state)
	if not restored.ok:
		status_label.text = "Could not restore workspace: " + restored.error
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return false
	baseline_source = startup_recovery.baseline_source
	curve_inspector.drafts = startup_recovery.drafts.duplicate(true)
	var selection: Dictionary = startup_recovery.selection.duplicate(true)
	_present_document(history.current, true, selection)
	startup_recovery.clear()
	_persist_recovery()
	status_label.text = "Recovered accepted edits, exact undo/redo history, selection, and unapplied curve drafts. Recovery is workspace data, not mathematical JSON."
	status_label.add_theme_color_override("font_color", Color("#167464"))
	return true

func _discard_startup_recovery() -> void:
	recovery_dialog.hide()
	startup_recovery.clear()
	WorkspaceRecovery.clear_file()
	status_label.text = "Discarded the recovery record. The initial fixture remains open."
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _request_close() -> bool:
	var action := Callable(self, "_quit_after_discard")
	if _request_before_destructive_action(action, "close Studio"):
		_quit_after_discard()
		return true
	return false

func _quit_after_discard() -> void:
	WorkspaceRecovery.clear_file()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_request_close()

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
