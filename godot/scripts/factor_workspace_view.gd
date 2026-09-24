class_name FactorWorkspaceView
extends PanelContainer

signal closed
var workspace: FactorWorkspace
var factor_index := -1
var selector: OptionButton
var details: Label
var message: Label
var support_canvas: DiagramCanvas
var before_canvas: DiagramCanvas
var after_canvas: DiagramCanvas
var braid_canvas: DiagramCanvas
var before_label: Label
var after_label: Label
var scroll: ScrollContainer
var grid: GridContainer
var view_tabs: HBoxContainer
var view_tab_buttons: Array[Button] = []
var view_columns: Array[Control] = []
var compact_view := 0
var source: TextEdit
var export_svg: Button
var export_tikz: Button
var export_dialog: FileDialog
var open_dialog: FileDialog
var rendered: Dictionary = {}
var export_kind := ""
var browser_mode := OS.has_feature("web")
var timeline_position := 0.0
var direction := ""
var playing := false
var timeline: HSlider
var play_button: Button
var direction_option: OptionButton
var timeline_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_accessibility_name("Factor sequence workspace")
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var tools := HFlowContainer.new()
	body.add_child(tools)
	_button(tools, "Back to editor", _close)
	_button(tools, "Open workspace", func(): open_dialog.popup_centered_ratio(0.85)).visible = not browser_mode
	_button(tools, "JSON import / source", func(): source.visible = not source.visible)
	_button(tools, "Import pasted JSON", func(): import_source(source.text))
	_button(tools, "Generic example", func(): import_source(FileAccess.get_file_as_string("res://fixtures/workspaces/grouped-v1.json")))
	export_svg = _button(tools, "Export exact SVG", _choose_export.bind("svg"))
	export_tikz = _button(tools, "Export exact TikZ", _choose_export.bind("tikz"))
	var note := _label(body, "Read-only factor workspace. Supports, states and braid blocks are supplied data, not computed actions or a verified lift. Exponents are labels, not instructions to repeat a block. Views below are schematic.")
	note.add_theme_color_override("font_color", Color("#167464"))
	source = TextEdit.new()
	source.custom_minimum_size.y = 220
	source.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	source.virtual_keyboard_enabled = true
	source.visible = false
	source.set_accessibility_name("Factor workspace JSON source")
	source.set_accessibility_description("Bounded imported source. Editing this field does not alter the loaded workspace until Import pasted JSON is activated.")
	body.add_child(source)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 44
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.item_selected.connect(select_factor)
	selector.set_accessibility_name("Selected factor")
	body.add_child(selector)
	var timeline_tools := HFlowContainer.new()
	body.add_child(timeline_tools)
	direction_option = OptionButton.new()
	direction_option.add_item("Bottom to top")
	direction_option.add_item("Top to bottom")
	direction_option.custom_minimum_size.y = 44
	direction_option.item_selected.connect(_direction_selected)
	direction_option.set_accessibility_name("Braid presentation direction")
	timeline_tools.add_child(direction_option)
	_button(timeline_tools, "Start", _start)
	_button(timeline_tools, "Previous factor", _previous)
	play_button = _button(timeline_tools, "Play factors", toggle_play)
	_button(timeline_tools, "Next factor", _next)
	_button(timeline_tools, "End", _end)
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.custom_minimum_size.y = 44
	timeline.value_changed.connect(_timeline_changed)
	timeline.set_accessibility_name("Factor playback position")
	timeline.set_accessibility_description("View-only position through the supplied factor sequence and literal braid blocks.")
	body.add_child(timeline)
	timeline_label = _label(body, "Timeline is view state. Supplied planar states switch at factor boundaries; they are not interpolated or computed.")
	_label(body, "Keyboard: Left/Right step, Home/End jump, Space plays or pauses, D changes braid presentation, Escape returns to the editor.")
	details = _label(body, "")
	view_tabs = HBoxContainer.new()
	view_tabs.visible = false
	view_tabs.set_accessibility_name("Factor view switcher")
	body.add_child(view_tabs)
	for caption in ["Support", "States", "Braid"]:
		var button := _button(view_tabs, caption, show_compact_view.bind(caption.to_lower()))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_accessibility_description("Show only the %s view on a compact screen." % caption.to_lower())
		view_tab_buttons.append(button)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var supports := _column("Support")
	view_columns.append(supports)
	support_canvas = _canvas(supports)
	support_canvas.set_accessibility_name("Selected factor support diagram")
	var states := _column("Supplied states")
	view_columns.append(states)
	before_label = _label(states, "")
	before_canvas = _canvas(states)
	before_canvas.set_accessibility_name("Supplied factor before-state diagram")
	after_label = _label(states, "")
	after_canvas = _canvas(states)
	after_canvas.set_accessibility_name("Supplied factor after-state diagram")
	var braids := _column("Continuous supplied braid")
	view_columns.append(braids)
	braid_canvas = _canvas(braids)
	braid_canvas.set_accessibility_name("Continuous supplied factor braid")
	braid_canvas.custom_minimum_size.y = 360
	braid_canvas.record_selected.connect(_crossing_selected)
	message = _label(body, "")
	message.set_accessibility_name("Factor workspace status")
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.add_filter("*.json", "Factor workspace JSON")
	open_dialog.file_selected.connect(open_path)
	add_child(open_dialog)
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_selected.connect(save_export)
	add_child(export_dialog)
	resized.connect(_responsive)
	get_viewport().size_changed.connect(_responsive)
	closed.connect(_stop_playback)
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

func _column(caption: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(column)
	_label(column, caption)
	return column

func _canvas(parent: Node) -> DiagramCanvas:
	var canvas := DiagramCanvas.new()
	canvas.custom_minimum_size.y = 220
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.read_only = true
	parent.add_child(canvas)
	return canvas

func focus_entry() -> void:
	if selector != null and selector.visible and selector.item_count > 0:
		selector.grab_focus()

func handle_keyboard(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.keycode == KEY_ESCAPE:
		_close()
		return true
	if _text_entry_focused():
		return false
	match event.keycode:
		KEY_LEFT:
			_previous()
		KEY_RIGHT:
			_next()
		KEY_HOME:
			_start()
		KEY_END:
			_end()
		KEY_SPACE:
			toggle_play()
		KEY_D:
			set_direction("top-to-bottom" if direction == "bottom-to-top" else "bottom-to-top")
		_:
			return false
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and handle_keyboard(event):
		get_viewport().set_input_as_handled()

func _text_entry_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or (focused != null and focused.get_parent() is SpinBox)

func _responsive() -> void:
	# Use the available viewport, not a temporarily expanded container minimum.
	# Otherwise the desktop grid can prevent its own phone breakpoint.
	if grid == null:
		return
	var compact := get_viewport_rect().size.x < 900
	if compact:
		var focused_index := _focused_column_index(view_columns)
		if focused_index >= 0:
			compact_view = focused_index
	grid.columns = 1 if compact else 3
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
	var names := ["support", "states", "braid"]
	var index := names.find(name)
	if index < 0:
		return false
	compact_view = index
	_responsive()
	return true

func open_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > DiagramDocument.MAX_BYTES:
		message.text = "Not opened: missing file or workspace exceeds 256 KiB. Current workspace unchanged."
		return
	import_source(file.get_as_text())

func import_source(text: String) -> bool:
	var parsed := FactorWorkspace.parse(text)
	if not parsed.ok:
		message.text = "Not opened: " + parsed.error + ". Current workspace unchanged."
		return false
	workspace = parsed.workspace
	playing = false
	play_button.text = "Play factors"
	timeline_position = 0.0
	direction = workspace.to_dict().direction
	direction_option.select(0 if direction == "bottom-to-top" else 1)
	source.text = workspace.to_json()
	selector.clear()
	for factor in workspace.to_dict().factors:
		selector.add_item("[%s]^%d | %s" % [factor.id, factor.exponent, factor.group])
	braid_canvas.set_document(workspace.braid_document())
	timeline.max_value = workspace.to_dict().factors.size()
	timeline.set_value_no_signal(0.0)
	# Empty sequences have no synthetic selected factor or supplied state.
	factor_index = -1
	for canvas in [support_canvas, before_canvas, after_canvas]: canvas.set_document(null)
	details.text = "Empty factor sequence"
	before_label.text = "Before: not supplied"
	after_label.text = "After: not supplied"
	if selector.item_count > 0:
		set_timeline_position(0.0)
	else:
		set_timeline_position(0.0)
		if workspace.to_dict().initial_state != null:
			var initial: String = workspace.to_dict().initial_state
			before_canvas.set_document(workspace.diagram(initial))
			before_label.text = "Initial: " + initial + " (supplied; no factors)"
	rendered = {"ok": false, "error": "Browser: Python geometry and publication export unavailable."} if browser_mode else PythonGeometryBridge.render(workspace)
	export_svg.disabled = not rendered.ok
	export_tikz.disabled = not rendered.ok
	message.text = "Python geometry rendered. Supplied correspondence is not mathematically verified." if rendered.ok else rendered.error
	return true

func select_factor(index: int) -> void:
	set_timeline_position(float(index))

func set_timeline_position(value: float, from_playback: bool = false) -> void:
	if workspace == null or not is_finite(value): return
	if not from_playback:
		playing = false
		play_button.text = "Play factors"
	var sample := FactorTimeline.sample(workspace, value, direction)
	if not sample.ok: return
	timeline_position = sample.position
	timeline.set_value_no_signal(timeline_position)
	braid_canvas.set_braid_view(sample.braid_time, direction)
	if sample.factor_index < 0:
		factor_index = -1
		timeline_label.text = "Empty factor sequence. No factor or braid action is manufactured."
		return
	var focus: Dictionary = sample.focus
	var changed: bool = sample.factor_index != factor_index
	factor_index = sample.factor_index
	selector.select(factor_index)
	if changed:
		support_canvas.set_document(workspace.diagram(focus.factor.support))
		before_canvas.set_document(workspace.diagram(focus.before))
		after_canvas.set_document(workspace.diagram(focus.after))
	before_label.text = "Before: " + (str(focus.before) + " (supplied)" if focus.before != null else "NOT SUPPLIED; not inferred")
	after_label.text = "After: " + (str(focus.after) + " (supplied)" if focus.after != null else "NOT SUPPLIED; not computed")
	var progress: float = sample.local * 100.0
	timeline_label.text = "Factor %d/%d, %.1f%% through its supplied braid block. Global braid position %.3f. Planar states are the factor's supplied endpoints, not an animation result." % [factor_index + 1, workspace.to_dict().factors.size(), progress, sample.braid_time]
	details.text = "%s\nApplication step %d: [%s]^%d. Literal word %s. Crossing interval [%d, %d). Entry IDs %s; exit IDs %s. %s" % [workspace.to_dict().title, factor_index + 1, focus.factor.id, focus.factor.exponent, focus.factor.braid_word, focus.start, focus.end, focus.entry_ids, focus.exit_ids, "Explicit empty block; identities unchanged during this timed stage." if focus.start == focus.end else "Tap a braid crossing to select its factor and exact local position."]
	var crossing := -1
	if focus.end > focus.start and sample.local > 0.0:
		crossing = mini(ceili(sample.braid_time) - 1, focus.end - 1)
	braid_canvas.select_record({} if crossing < 0 else {"kind": "crossing", "index": crossing})

func _crossing_selected(record: Dictionary) -> void:
	if workspace == null or record.get("kind", "") != "crossing": return
	var index: int = record.index
	var factor := workspace.factor_for_crossing(index)
	if factor >= 0:
		var focus := workspace.focus(factor)
		var local := (float(index - focus.start) + 0.5) / maxf(1.0, focus.end - focus.start)
		set_timeline_position(factor + local)
		braid_canvas.select_record(record)

func set_direction(value: String) -> void:
	if workspace == null or value not in ["bottom-to-top", "top-to-bottom"]: return
	direction = value
	direction_option.select(0 if direction == "bottom-to-top" else 1)
	set_timeline_position(timeline_position, true)

func toggle_play() -> void:
	if workspace == null or workspace.to_dict().factors.is_empty(): return
	if playing:
		playing = false
	else:
		if timeline_position >= workspace.to_dict().factors.size(): set_timeline_position(0.0, true)
		playing = true
	play_button.text = "Pause" if playing else "Play factors"

func advance(delta: float) -> void:
	if not playing or workspace == null or not is_finite(delta) or delta <= 0.0: return
	set_timeline_position(FactorTimeline.advance(workspace, timeline_position, delta), true)
	if timeline_position >= workspace.to_dict().factors.size():
		playing = false
		play_button.text = "Play factors"

func _process(delta: float) -> void:
	advance(delta)

func _direction_selected(index: int) -> void:
	set_direction("bottom-to-top" if index == 0 else "top-to-bottom")

func _timeline_changed(value: float) -> void:
	set_timeline_position(value)

func _start() -> void: set_timeline_position(0.0)

func _previous() -> void:
	var sample := FactorTimeline.sample(workspace, timeline_position, direction)
	if not sample.ok or sample.factor_index < 0: return
	set_timeline_position(float(sample.factor_index if sample.local > 0.0 else maxi(0, sample.factor_index - 1)))

func _next() -> void:
	var sample := FactorTimeline.sample(workspace, timeline_position, direction)
	if not sample.ok or sample.factor_index < 0: return
	set_timeline_position(float(mini(workspace.to_dict().factors.size(), sample.factor_index + 1)))

func _end() -> void:
	if workspace != null: set_timeline_position(float(workspace.to_dict().factors.size()))

func _close() -> void:
	closed.emit()

func _stop_playback() -> void:
	playing = false
	play_button.text = "Play factors"

func _choose_export(kind: String) -> void:
	if not rendered.get("ok", false): return
	export_kind = kind
	export_dialog.current_file = "supplied-factor-workspace." + kind
	export_dialog.popup_centered_ratio(0.85)

func save_export(path: String) -> bool:
	if not rendered.get("ok", false) or export_kind not in ["svg", "tikz"]: return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		message.text = "Could not write export"
		return false
	file.store_string(rendered[export_kind])
	message.text = "Saved exact Python " + export_kind.to_upper() + ". This does not certify the supplied correspondence."
	return true
