extends Control

var document: DiagramDocument
var canvas: DiagramCanvas
var record_list: ItemList
var title_label: Label
var status_label: Label
var source_view: TextEdit
var open_dialog: FileDialog
var save_dialog: FileDialog

func _ready() -> void:
	_build_interface()
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
	camera_note.text = "Mouse wheel: zoom   Middle drag: pan"
	camera_note.add_theme_color_override("font_color", Color("#6b7b78"))
	canvas_tools.add_child(camera_note)
	canvas = DiagramCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_box.add_child(canvas)
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

func _show_open() -> void:
	open_dialog.popup_centered_ratio(0.8)

func _show_save() -> void:
	if document == null: return
	save_dialog.current_file = _safe_filename(document.data.title) + ".json"
	save_dialog.popup_centered_ratio(0.8)

func _open_resource(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_path(path: String) -> void:
	_open_result(DiagramDocument.load_path(path), path)

func _open_result(result: Dictionary, path: String) -> void:
	if not result.ok:
		status_label.text = "Not opened: " + result.error
		status_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	document = result.document
	title_label.text = document.data.title
	record_list.clear()
	for row in document.summary_rows(): record_list.add_item(row)
	source_view.text = document.to_json()
	canvas.set_document(document)
	status_label.text = "%s opened from %s. Viewer only: this native preview is schematic and does not certify geometry or an algebraic relation." % [document.data.kind.capitalize(), path]
	status_label.add_theme_color_override("font_color", Color("#415b55"))

func _save_path(path: String) -> void:
	if not path.to_lower().ends_with(".json"): path += ".json"
	var error := document.save_path(path)
	status_label.text = "Saved exact normalized recipe to " + path if error.is_empty() else error
	status_label.add_theme_color_override("font_color", Color("#415b55") if error.is_empty() else Color("#a54439"))

func _safe_filename(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "-"
	result = result.strip_edges()
	while result.begins_with("-"): result = result.substr(1)
	while result.ends_with("-"): result = result.left(-1)
	return result if not result.is_empty() else "diagram"
