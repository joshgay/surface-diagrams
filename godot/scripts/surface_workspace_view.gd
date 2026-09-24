class_name SurfaceWorkspaceView
extends PanelContainer

signal closed
const FIXTURE := "res://fixtures/surfaces/disk-v1.json"
var document: SurfaceViewDocument
var source: TextEdit
var source_button: Button
var status: Label
var details: Label
var record_list: ItemList
var canvas_2d: DiagramCanvas
var surface_3d: ExploratorySurface3D
var scroll: ScrollContainer
var grid: GridContainer
var view_tabs: HBoxContainer
var view_tab_buttons: Array[Button] = []
var view_columns: Array[Control] = []
var compact_view := 0
var open_dialog: FileDialog
var browser_mode := OS.has_feature("web")
var selected_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_accessibility_name("Exploratory surface workspace")
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var tools := HFlowContainer.new()
	body.add_child(tools)
	_button(tools, "Back to editor", func(): closed.emit())
	_button(tools, "Open surface JSON", func(): open_dialog.popup_centered_ratio(0.85)).visible = not browser_mode
	source_button = _button(tools, "JSON import / source", func(): source.visible = not source.visible)
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
	source.set_accessibility_name("Exploratory surface JSON source")
	source.set_accessibility_description("Bounded supplied coordinates. Editing this field does not alter the loaded view until Import pasted JSON is activated.")
	body.add_child(source)
	record_list = ItemList.new()
	record_list.custom_minimum_size.y = 120
	record_list.add_theme_constant_override("v_separation", 20)
	record_list.item_selected.connect(_list_selected)
	record_list.set_accessibility_name("Linked stable records")
	body.add_child(record_list)
	var visibility_tools := HFlowContainer.new()
	body.add_child(visibility_tools)
	_button(visibility_tools, "Hide selected", _hide_selected)
	_button(visibility_tools, "Isolate selected", _isolate_selected)
	_button(visibility_tools, "Show all", _show_all)
	details = _label(body, "Select the same stable ID in either view.")
	view_tabs = HBoxContainer.new()
	view_tabs.visible = false
	view_tabs.set_accessibility_name("Surface view switcher")
	body.add_child(view_tabs)
	for spec in [["2D recipe", "surface-2d"], ["Exploratory 3D", "surface-3d"]]:
		var button := _button(view_tabs, spec[0], show_compact_view.bind(spec[1]))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_accessibility_description("Show only the %s on a compact screen." % spec[0])
		view_tab_buttons.append(button)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var two_d := _column("Linked 2D recipe (schematic)")
	view_columns.append(two_d)
	canvas_2d = DiagramCanvas.new()
	canvas_2d.read_only = true
	canvas_2d.custom_minimum_size.y = 380
	canvas_2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_2d.record_selected.connect(_record_selected)
	two_d.add_child(canvas_2d)
	canvas_2d.set_accessibility_name("Linked two dimensional recipe")
	var three_d := _column("Exploratory supplied 3D view")
	view_columns.append(three_d)
	surface_3d = ExploratorySurface3D.new()
	surface_3d.custom_minimum_size.y = 380
	surface_3d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_3d.record_picked.connect(_record_selected)
	three_d.add_child(surface_3d)
	surface_3d.set_accessibility_name("Linked exploratory three dimensional view")
	_set_control_relation(source_button, source)
	for index in view_tab_buttons.size():
		_set_control_relation(view_tab_buttons[index], view_columns[index])
	status = _label(body, "")
	status.set_accessibility_name("Exploratory surface status")
	status.set_accessibility_live(AccessibilityServer.LIVE_POLITE)
	_label(body, "Keyboard: Up/Down select a stable record, Home selects the first, F fits 3D, H hides, I isolates, A shows all, Escape returns to the editor.")
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
	button.set_accessibility_name(caption)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _set_control_relation(controller: Control, target: Control) -> void:
	var paths: Array[NodePath] = [controller.get_path_to(target)]
	controller.set_accessibility_controls_nodes(paths)

func _column(caption: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(column)
	_label(column, caption)
	return column

func _responsive() -> void:
	if grid == null:
		return
	var compact := get_viewport_rect().size.x < 900
	if compact:
		var focused_index := _focused_column_index(view_columns)
		if focused_index >= 0:
			compact_view = focused_index
	grid.columns = 1 if compact else 2
	view_tabs.visible = compact
	for index in view_columns.size():
		view_columns[index].visible = not compact or index == compact_view
	for index in view_tab_buttons.size():
		view_tab_buttons[index].set_pressed_no_signal(index == compact_view)
	call_deferred("_ensure_focused_control_visible")

func _focused_column_index(columns: Array[Control]) -> int:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return -1
	for index in columns.size():
		if focused == columns[index] or columns[index].is_ancestor_of(focused):
			return index
	return -1

func _ensure_focused_control_visible() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if scroll != null and focused != null and is_ancestor_of(focused) and focused.is_visible_in_tree():
		scroll.ensure_control_visible(focused)

func show_compact_view(name: String) -> bool:
	var names := ["surface-2d", "surface-3d"]
	var index := names.find(name)
	if index < 0:
		return false
	compact_view = index
	_responsive()
	return true

func focus_entry() -> void:
	if record_list != null:
		record_list.grab_focus()

func handle_keyboard(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.keycode == KEY_ESCAPE:
		closed.emit()
		return true
	if _text_entry_focused():
		return false
	match event.keycode:
		KEY_UP:
			_select_relative(-1)
		KEY_DOWN:
			_select_relative(1)
		KEY_HOME:
			_select_index(0)
		KEY_F:
			surface_3d.fit_view()
		KEY_H:
			_hide_selected()
		KEY_I:
			_isolate_selected()
		KEY_A:
			_show_all()
		_:
			return false
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and handle_keyboard(event):
		get_viewport().set_input_as_handled()

func _text_entry_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or (focused != null and focused.get_parent() is SpinBox)

func _select_relative(delta: int) -> void:
	if record_list.item_count == 0: return
	var selected := record_list.get_selected_items()
	var current := selected[0] if not selected.is_empty() else (-1 if delta > 0 else 0)
	_select_index(posmod(current + delta, record_list.item_count))

func _select_index(index: int) -> void:
	if index < 0 or index >= record_list.item_count: return
	record_list.select(index)
	_list_selected(index)

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
