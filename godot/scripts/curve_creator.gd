class_name CurveCreator
extends VBoxContainer

signal create_requested(curve: Dictionary)
signal draft_changed(active: bool, curve: Dictionary, message: String)

var document: DiagramDocument
var active := false
var draft: Dictionary = {}
var form: VBoxContainer
var id_edit: LineEdit
var kind_label: Label
var start_spin: SpinBox
var end_spin: SpinBox
var direction_option: OptionButton
var start_side_option: OptionButton
var end_side_option: OptionButton
var start_up_check: CheckBox
var cut_grid: GridContainer
var cuts_label: Label
var warning_label: Label
var create_button: Button

func _init() -> void:
	add_theme_constant_override("separation", 5)
	set_accessibility_name("New curve editor")
	var heading := Label.new()
	heading.text = "Create a curve"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#167464"))
	add_child(heading)
	var starters := HFlowContainer.new()
	add_child(starters)
	for spec in [["New arc", "arc"], ["New loop", "loop"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size.y = 44
		button.set_accessibility_name(spec[0])
		button.pressed.connect(start.bind(spec[1]))
		starters.add_child(button)
	form = VBoxContainer.new()
	form.visible = false
	add_child(form)
	kind_label = Label.new()
	kind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(kind_label)
	var id_row := HBoxContainer.new()
	form.add_child(id_row)
	var id_label := Label.new()
	id_label.text = "Stable ID"
	id_row.add_child(id_label)
	id_edit = LineEdit.new()
	id_edit.max_length = 40
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.custom_minimum_size.y = 44
	id_edit.set_accessibility_name("New curve stable ID")
	id_edit.text_changed.connect(_id_changed)
	id_row.add_child(id_edit)
	_label_control(id_edit, id_label)
	var endpoint_row := HFlowContainer.new()
	form.add_child(endpoint_row)
	start_spin = _number_control(endpoint_row, "Start endpoint", _start_changed)
	end_spin = _number_control(endpoint_row, "End endpoint", _end_changed)
	direction_option = _option_control(endpoint_row, "Direction", ["default", "up", "down"], _direction_changed)
	start_side_option = _option_control(endpoint_row, "Start rim", ["none", "left", "right"], _start_side_changed)
	end_side_option = _option_control(endpoint_row, "End rim", ["none", "left", "right"], _end_side_changed)
	start_up_check = CheckBox.new()
	start_up_check.text = "Loop starts upward"
	start_up_check.custom_minimum_size.y = 44
	start_up_check.set_accessibility_name("Loop starts upward")
	start_up_check.toggled.connect(_start_up_changed)
	form.add_child(start_up_check)
	var instruction := Label.new()
	instruction.text = "Pick cuts in literal visit order. No visit is sorted, cancelled, or inferred."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color("#6b7b78"))
	form.add_child(instruction)
	cut_grid = GridContainer.new()
	form.add_child(cut_grid)
	cuts_label = Label.new()
	cuts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuts_label.set_accessibility_name("New curve literal cut itinerary")
	form.add_child(cuts_label)
	var actions := HFlowContainer.new()
	form.add_child(actions)
	for spec in [["Remove last", _remove_last], ["Clear cuts", _clear_cuts], ["Cancel draft", cancel]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size.y = 44
		button.set_accessibility_name(spec[0])
		button.pressed.connect(spec[1])
		actions.add_child(button)
	create_button = Button.new()
	create_button.text = "Validate and create"
	create_button.custom_minimum_size.y = 44
	create_button.set_accessibility_name("Validate and create exact curve")
	create_button.pressed.connect(_create)
	actions.add_child(create_button)
	warning_label = Label.new()
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.set_accessibility_name("New curve validation status")
	warning_label.set_accessibility_live(AccessibilityServer.LIVE_POLITE)
	form.add_child(warning_label)
	_describe_control(create_button, warning_label)

func configure(value: DiagramDocument) -> void:
	document = value
	visible = document != null and document.data.kind == "planar"
	if not visible:
		active = false
		draft.clear()
		form.visible = false
		return
	_build_cut_buttons(document.data.surface.objects.size() + 1)
	var endpoint_max: int = document.data.surface.objects.size() + 1
	start_spin.max_value = endpoint_max
	end_spin.max_value = endpoint_max
	if active:
		_refresh()

func start(kind: String) -> void:
	if document == null or document.data.kind != "planar" or kind not in ["arc", "loop"]:
		return
	active = true
	var id := _next_id(kind)
	if kind == "arc":
		draft = {"id": id, "kind": "arc", "color": "#ff00d4", "cuts": [],
			"start": 0, "end": document.data.surface.objects.size() + 1,
			"direction": "default", "start_side": null, "end_side": null}
	else:
		draft = {"id": id, "kind": "loop", "color": "#ff00d4", "cuts": [], "start_up": true}
	_sync_controls()
	form.visible = true
	_refresh()

func append_cut(cut: int) -> void:
	if not active or cut < 0 or cut > document.data.surface.objects.size():
		return
	if draft.cuts.size() >= DiagramDocument.MAX_CUTS:
		warning_label.text = "Draft limit: 64 visits. Earlier input was not trimmed or simplified."
		warning_label.add_theme_color_override("font_color", Color("#a54439"))
		return
	draft.cuts.append(cut)
	_refresh()

func finish_success() -> void:
	active = false
	draft.clear()
	form.visible = false
	draft_changed.emit(false, {}, "")

func show_rejection(message: String) -> void:
	warning_label.text = message
	warning_label.add_theme_color_override("font_color", Color("#a54439"))

func cancel() -> void:
	if not active:
		return
	active = false
	draft.clear()
	form.visible = false
	draft_changed.emit(false, {}, "Creation draft cancelled explicitly.")

func _number_control(parent: Control, label_text: String, callback: Callable) -> SpinBox:
	var field := VBoxContainer.new()
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.step = 1
	spin.custom_minimum_size.y = 44
	spin.set_accessibility_name(label_text)
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.value_changed.connect(callback)
	field.add_child(spin)
	_label_control(spin, label)
	return spin

func _option_control(parent: Control, label_text: String, values: Array,
		callback: Callable) -> OptionButton:
	var field := VBoxContainer.new()
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	option.set_accessibility_name(label_text)
	for value in values:
		option.add_item(value)
	option.item_selected.connect(callback)
	field.add_child(option)
	_label_control(option, label)
	return option

func _build_cut_buttons(count: int) -> void:
	for child in cut_grid.get_children():
		cut_grid.remove_child(child)
		child.queue_free()
	cut_grid.columns = mini(5, count)
	for cut in count:
		var button := Button.new()
		button.text = "c%d" % cut
		button.custom_minimum_size = Vector2(44, 44)
		button.tooltip_text = "Append cut %d to the new curve" % cut
		button.set_accessibility_name("Append cut %d to new curve" % cut)
		button.pressed.connect(append_cut.bind(cut))
		cut_grid.add_child(button)

func _label_control(control: Control, label: Control) -> void:
	var paths: Array[NodePath] = [control.get_path_to(label)]
	control.set_accessibility_labeled_by_nodes(paths)

func _describe_control(control: Control, description: Control) -> void:
	var paths: Array[NodePath] = [control.get_path_to(description)]
	control.set_accessibility_described_by_nodes(paths)

func _next_id(kind: String) -> String:
	var used := {}
	for curve in document.data.curves:
		used[curve.id] = true
	var prefix := "arc" if kind == "arc" else "loop"
	var index := 1
	while used.has(prefix + str(index)):
		index += 1
	return prefix + str(index)

func _sync_controls() -> void:
	id_edit.text = draft.id
	var arc: bool = draft.kind == "arc"
	kind_label.text = "New %s draft. Color is explicitly Richard's magenta #ff00d4." % draft.kind
	start_spin.get_parent().visible = arc
	end_spin.get_parent().visible = arc
	direction_option.get_parent().visible = arc
	start_side_option.get_parent().visible = arc
	end_side_option.get_parent().visible = arc
	start_up_check.visible = not arc
	if arc:
		start_spin.set_value_no_signal(draft.start)
		end_spin.set_value_no_signal(draft.end)
		direction_option.select(["default", "up", "down"].find(draft.direction))
		start_side_option.select([null, "left", "right"].find(draft.start_side))
		end_side_option.select([null, "left", "right"].find(draft.end_side))
	else:
		start_up_check.set_pressed_no_signal(draft.start_up)

func _id_changed(value: String) -> void:
	if active:
		draft.id = value
		_refresh()

func _start_changed(value: float) -> void:
	if active and draft.kind == "arc":
		draft.start = int(value)
		_refresh()

func _end_changed(value: float) -> void:
	if active and draft.kind == "arc":
		draft.end = int(value)
		_refresh()

func _direction_changed(index: int) -> void:
	if active and draft.kind == "arc":
		draft.direction = ["default", "up", "down"][index]
		_refresh()

func _start_side_changed(index: int) -> void:
	if active and draft.kind == "arc":
		draft.start_side = [null, "left", "right"][index]
		_refresh()

func _end_side_changed(index: int) -> void:
	if active and draft.kind == "arc":
		draft.end_side = [null, "left", "right"][index]
		_refresh()

func _start_up_changed(value: bool) -> void:
	if active and draft.kind == "loop":
		draft.start_up = value
		_refresh()

func _remove_last() -> void:
	if active and not draft.cuts.is_empty():
		draft.cuts.pop_back()
		_refresh()

func _clear_cuts() -> void:
	if active:
		draft.cuts.clear()
		_refresh()

func _create() -> void:
	if active:
		create_requested.emit(draft.duplicate(true))

func _refresh() -> void:
	if not active:
		return
	cuts_label.text = "Draft cuts: %s" % [draft.cuts]
	var warning := _draft_warning()
	warning_label.text = warning
	warning_label.add_theme_color_override("font_color", Color("#a54439") if "reject" in warning.to_lower() else Color("#415b55"))
	draft_changed.emit(true, draft.duplicate(true), warning)

func _draft_warning() -> String:
	var regex := RegEx.new()
	regex.compile(DiagramDocument.ID_PATTERN)
	if regex.search(draft.id) == null:
		return "Schema will reject this stable ID. It must start with a letter and use at most 40 safe characters."
	for curve in document.data.curves:
		if curve.id == draft.id:
			return "Schema will reject duplicate curve ID %s." % draft.id
	if document.data.curves.size() >= DiagramDocument.MAX_CURVES:
		return "Schema will reject a seventeenth curve."
	for index in range(1, draft.cuts.size()):
		if draft.cuts[index] == draft.cuts[index - 1]:
			return "Schema will reject consecutive equal cut visits as nonminimal."
	if draft.kind == "loop":
		if draft.cuts.size() < 2 or draft.cuts.size() % 2 != 0:
			return "Schema will reject this loop until it has a positive even number of literal cut visits."
		if draft.cuts[0] == draft.cuts[-1]:
			return "Schema will reject equal first and last loop cuts as a cyclic cancellation."
	elif draft.start == draft.end:
		return "Schema will reject an arc with identical endpoints."
	elif not draft.cuts.is_empty() and (draft.cuts[0] in [draft.start - 1, draft.start] or draft.cuts[-1] in [draft.end - 1, draft.end]):
		return "Schema will reject a terminal cut adjacent to its arc endpoint as nonminimal."
	return "Draft fields are literal. Create runs strict schema and Python routing validation before changing the accepted record."
