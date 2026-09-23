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
var grid: GridContainer
var source: TextEdit
var export_svg: Button
var export_tikz: Button
var export_dialog: FileDialog
var open_dialog: FileDialog
var rendered: Dictionary = {}
var export_kind := ""
var browser_mode := OS.has_feature("web")

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
	body.add_child(source)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 44
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.item_selected.connect(select_factor)
	body.add_child(selector)
	details = _label(body, "")
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var supports := _column("Support")
	support_canvas = _canvas(supports)
	var states := _column("Supplied states")
	before_label = _label(states, "")
	before_canvas = _canvas(states)
	after_label = _label(states, "")
	after_canvas = _canvas(states)
	var braids := _column("Continuous supplied braid")
	braid_canvas = _canvas(braids)
	braid_canvas.custom_minimum_size.y = 360
	braid_canvas.record_selected.connect(_crossing_selected)
	message = _label(body, "")
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

func _canvas(parent: Node) -> DiagramCanvas:
	var canvas := DiagramCanvas.new()
	canvas.custom_minimum_size.y = 220
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.read_only = true
	parent.add_child(canvas)
	return canvas

func _responsive() -> void:
	# Use the available viewport, not a temporarily expanded container minimum.
	# Otherwise the desktop grid can prevent its own phone breakpoint.
	if grid != null: grid.columns = 1 if get_viewport_rect().size.x < 900 else 3

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
	source.text = workspace.to_json()
	selector.clear()
	for factor in workspace.to_dict().factors:
		selector.add_item("[%s]^%d | %s" % [factor.id, factor.exponent, factor.group])
	braid_canvas.set_document(workspace.braid_document())
	# Empty sequences have no synthetic selected factor or supplied state.
	factor_index = -1
	for canvas in [support_canvas, before_canvas, after_canvas]: canvas.set_document(null)
	details.text = "Empty factor sequence"
	before_label.text = "Before: not supplied"
	after_label.text = "After: not supplied"
	if selector.item_count > 0:
		select_factor(0)
	elif workspace.to_dict().initial_state != null:
		var initial: String = workspace.to_dict().initial_state
		before_canvas.set_document(workspace.diagram(initial))
		before_label.text = "Initial: " + initial + " (supplied; no factors)"
	rendered = {"ok": false, "error": "Browser: Python geometry and publication export unavailable."} if browser_mode else PythonGeometryBridge.render(workspace)
	export_svg.disabled = not rendered.ok
	export_tikz.disabled = not rendered.ok
	message.text = "Python geometry rendered. Supplied correspondence is not mathematically verified." if rendered.ok else rendered.error
	return true

func select_factor(index: int) -> void:
	if workspace == null: return
	var focus := workspace.focus(index)
	if focus.is_empty(): return
	factor_index = index
	selector.select(index)
	support_canvas.set_document(workspace.diagram(focus.factor.support))
	before_canvas.set_document(workspace.diagram(focus.before))
	after_canvas.set_document(workspace.diagram(focus.after))
	before_label.text = "Before: " + (str(focus.before) + " (supplied)" if focus.before != null else "NOT SUPPLIED; not inferred")
	after_label.text = "After: " + (str(focus.after) + " (supplied)" if focus.after != null else "NOT SUPPLIED; not computed")
	details.text = "%s\nApplication step %d: [%s]^%d. Literal word %s. Crossing interval [%d, %d). Entry IDs %s; exit IDs %s. %s" % [workspace.to_dict().title, index + 1, focus.factor.id, focus.factor.exponent, focus.factor.braid_word, focus.start, focus.end, focus.entry_ids, focus.exit_ids, "Explicit empty block; identities unchanged." if focus.start == focus.end else "Tap a braid crossing to select its factor."]
	# Full braid stays visible. An empty block is selected in the factor list;
	# it never borrows a neighboring crossing to manufacture a selection.
	braid_canvas.select_record({} if focus.start == focus.end else {"kind": "crossing", "index": focus.start})

func _crossing_selected(record: Dictionary) -> void:
	if workspace == null or record.get("kind", "") != "crossing": return
	var index: int = record.index
	var factor := workspace.factor_for_crossing(index)
	if factor >= 0:
		select_factor(factor)
		braid_canvas.select_record(record)

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
