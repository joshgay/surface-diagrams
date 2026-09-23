class_name SurfaceWorkspaceView
extends PanelContainer

signal closed
const FIXTURE := "res://fixtures/surfaces/disk-v1.json"
var document: SurfaceViewDocument
var source: TextEdit
var status: Label
var details: Label
var record_list: ItemList
var canvas_2d: DiagramCanvas
var surface_3d: ExploratorySurface3D
var grid: GridContainer
var open_dialog: FileDialog
var browser_mode := OS.has_feature("web")
var selected_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var tools := HFlowContainer.new()
	body.add_child(tools)
	_button(tools, "Back to editor", func(): closed.emit())
	_button(tools, "Open surface JSON", func(): open_dialog.popup_centered_ratio(0.85)).visible = not browser_mode
	_button(tools, "JSON import / source", func(): source.visible = not source.visible)
	_button(tools, "Import pasted JSON", func(): import_source(source.text))
	_button(tools, "Generic disk", func(): import_source(FileAccess.get_file_as_string(FIXTURE)))
	_button(tools, "Fit 3D", func(): surface_3d.fit_view())
	var labels := CheckButton.new()
	labels.text = "Orientation labels"
	labels.button_pressed = true
	labels.custom_minimum_size.y = 44
	labels.toggled.connect(func(value: bool): surface_3d.set_orientation_labels_visible(value))
	tools.add_child(labels)
	var warning := _label(body, "EXPLORATORY 3D: supplied illustrative coordinates, not certified library geometry, a computed lift, or the unfinished bordered mesh. The linked 2D recipe remains the publication authority.")
	warning.add_theme_color_override("font_color", Color("#a54439"))
	source = TextEdit.new()
	source.custom_minimum_size.y = 220
	source.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	source.virtual_keyboard_enabled = true
	source.visible = false
	body.add_child(source)
	record_list = ItemList.new()
	record_list.custom_minimum_size.y = 120
	record_list.add_theme_constant_override("v_separation", 20)
	record_list.item_selected.connect(_list_selected)
	body.add_child(record_list)
	var visibility_tools := HFlowContainer.new()
	body.add_child(visibility_tools)
	_button(visibility_tools, "Hide selected", _hide_selected)
	_button(visibility_tools, "Isolate selected", _isolate_selected)
	_button(visibility_tools, "Show all", _show_all)
	details = _label(body, "Select the same stable ID in either view.")
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var two_d := _column("Linked 2D recipe (schematic)")
	canvas_2d = DiagramCanvas.new()
	canvas_2d.read_only = true
	canvas_2d.custom_minimum_size.y = 380
	canvas_2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_2d.record_selected.connect(_record_selected)
	two_d.add_child(canvas_2d)
	var three_d := _column("Exploratory supplied 3D view")
	surface_3d = ExploratorySurface3D.new()
	surface_3d.custom_minimum_size.y = 380
	surface_3d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_3d.record_picked.connect(_record_selected)
	three_d.add_child(surface_3d)
	status = _label(body, "")
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.add_filter("*.json", "Surface view JSON")
	open_dialog.file_selected.connect(open_path)
	add_child(open_dialog)
	resized.connect(_responsive)
	get_viewport().size_changed.connect(_responsive)
	_responsive()

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _column(caption: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(column)
	_label(column, caption)
	return column

func _responsive() -> void:
	if grid != null: grid.columns = 1 if get_viewport_rect().size.x < 900 else 2

func open_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > DiagramDocument.MAX_BYTES:
		status.text = "Not opened: missing file or record exceeds 256 KiB. Current view unchanged."
		return
	import_source(file.get_as_text())

func import_source(text: String) -> bool:
	var parsed := SurfaceViewDocument.parse(text)
	if not parsed.ok:
		status.text = "Not opened: " + parsed.error + ". Current view unchanged."
		return false
	document = parsed.document
	selected_id = ""
	source.text = document.to_json()
	record_list.clear()
	for record in document.records():
		record_list.add_item(record.label)
		record_list.set_item_metadata(record_list.item_count - 1, record)
	canvas_2d.set_document(document.planar_document())
	surface_3d.set_document(document)
	details.text = "Select the same stable ID in either view. Orbit by dragging; wheel zooms. Camera and visibility never edit this record."
	status.text = "Loaded supplied exploratory geometry. No lift, equivalence, routing, or publication geometry was computed."
	return true

func select_id(id: String) -> bool:
	if document == null: return false
	var records := document.records()
	var selected: Dictionary = {}
	for index in records.size():
		if records[index].id == id:
			selected = records[index]
			record_list.select(index)
			break
	if selected.is_empty(): return false
	selected_id = id
	surface_3d.select_id(id)
	for record in document.planar_document().inspector_records():
		if record.id == id:
			canvas_2d.select_record(record)
			break
	details.text = "%s selected in both views. %s This is identity linkage, not proof that the supplied 3D polyline is a certified lift." % [id, selected.label]
	return true

func _record_selected(record: Dictionary) -> void:
	if record.has("id"): select_id(record.id)

func _list_selected(index: int) -> void:
	select_id(record_list.get_item_metadata(index).id)

func _hide_selected() -> void:
	if surface_3d.hide_selected():
		status.text = "Hidden " + selected_id + " in the exploratory 3D view only. The data and 2D recipe are unchanged."

func _isolate_selected() -> void:
	if surface_3d.isolate_selected():
		status.text = "Isolated " + selected_id + " in the exploratory 3D view only."

func _show_all() -> void:
	surface_3d.show_all()
	status.text = "All supplied 3D records visible."
