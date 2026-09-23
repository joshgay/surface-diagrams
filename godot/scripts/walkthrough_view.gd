class_name WalkthroughView
extends PanelContainer

signal closed
const FIXTURE := "res://fixtures/walkthroughs/point-and-label-v1.json"
const SECONDS_PER_STEP := 1.5

var document: WalkthroughDocument
var timeline_position := 0.0
var step_index := -1
var playing := false
var play_direction := 1
var browser_mode := OS.has_feature("web")
var source: TextEdit
var selector: OptionButton
var timeline: HSlider
var timeline_label: Label
var play_button: Button
var direction_option: OptionButton
var details: Label
var verification: Label
var selected_list: ItemList
var before_canvas: DiagramCanvas
var after_canvas: DiagramCanvas
var before_label: Label
var after_label: Label
var grid: GridContainer
var status: Label
var open_dialog: FileDialog
var save_dialog: FileDialog

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
	_button(tools, "Back to editor", _close)
	_button(tools, "Open walkthrough", func(): open_dialog.popup_centered_ratio(0.85)).visible = not browser_mode
	_button(tools, "Save walkthrough", func(): _choose_save()).visible = not browser_mode
	_button(tools, "JSON import / source", func(): source.visible = not source.visible)
	_button(tools, "Import pasted JSON", func(): import_source(source.text))
	_button(tools, "Generic example", func(): import_source(FileAccess.get_file_as_string(FIXTURE)))
	var warning := _label(body, "SUPPLIED WALKTHROUGH. Playback crossfades complete endpoint records only. It does not compute an intermediate state or prove that an operation preserves any mathematical property.")
	warning.add_theme_color_override("font_color", Color("#a54439"))
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
	selector.item_selected.connect(func(index: int): set_timeline_position(float(index)))
	body.add_child(selector)
	var playback := HFlowContainer.new()
	body.add_child(playback)
	direction_option = OptionButton.new()
	direction_option.add_item("Play forward")
	direction_option.add_item("Play reverse")
	direction_option.custom_minimum_size.y = 44
	direction_option.item_selected.connect(func(index: int): set_play_direction(1 if index == 0 else -1))
	playback.add_child(direction_option)
	_button(playback, "|<", _start)
	_button(playback, "Previous", _previous)
	play_button = _button(playback, "Play forward", toggle_play)
	_button(playback, "Next", _next)
	_button(playback, ">|", _end)
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.custom_minimum_size.y = 44
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.value_changed.connect(func(value: float): set_timeline_position(value))
	body.add_child(timeline)
	timeline_label = _label(body, "Timeline is view state.")
	verification = _label(body, "")
	verification.add_theme_color_override("font_color", Color("#a06a1a"))
	details = _label(body, "")
	selected_list = ItemList.new()
	selected_list.custom_minimum_size.y = 84
	selected_list.allow_reselect = true
	selected_list.item_selected.connect(_selected_row)
	body.add_child(selected_list)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var before_column := _column("Complete supplied before-state")
	before_label = _label(before_column, "")
	before_canvas = _canvas(before_column)
	var after_column := _column("Complete supplied after-state")
	after_label = _label(after_column, "")
	after_canvas = _canvas(after_column)
	status = _label(body, "")
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.add_filter("*.json", "Walkthrough JSON")
	open_dialog.file_selected.connect(open_path)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.add_filter("*.json", "Walkthrough JSON")
	save_dialog.file_selected.connect(save_path)
	add_child(save_dialog)
	resized.connect(_responsive)
	get_viewport().size_changed.connect(_responsive)
	closed.connect(_stop_playback)
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
	canvas.read_only = true
	canvas.custom_minimum_size.y = 330
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.record_selected.connect(_record_selected)
	parent.add_child(canvas)
	return canvas

func _responsive() -> void:
	if grid != null: grid.columns = 1 if get_viewport_rect().size.x < 900 else 2

func open_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > DiagramDocument.MAX_BYTES:
		status.text = "Not opened: missing file or walkthrough exceeds 256 KiB. Current walkthrough unchanged."
		return
	import_source(file.get_as_text())

func import_source(text: String) -> bool:
	var parsed := WalkthroughDocument.parse(text)
	if not parsed.ok:
		status.text = "Not opened: " + parsed.error + ". Current walkthrough unchanged."
		return false
	document = parsed.document
	timeline_position = 0.0
	step_index = -1
	playing = false
	play_direction = 1
	direction_option.select(0)
	play_button.text = "Play forward"
	source.text = document.to_json()
	selector.clear()
	for step in document.to_dict().steps:
		selector.add_item("%s | %s" % [step.id, step.name])
	timeline.max_value = document.to_dict().steps.size()
	timeline.set_value_no_signal(0.0)
	set_timeline_position(0.0, true)
	status.text = "Loaded complete supplied endpoint records. Verification and provenance below are imported metadata, not Studio conclusions."
	return true

func set_timeline_position(value: float, from_playback: bool = false) -> void:
	if document == null: return
	if not from_playback: _stop_playback()
	var sample := WalkthroughTimeline.sample(document, value)
	if not sample.ok: return
	timeline_position = sample.position
	timeline.set_value_no_signal(timeline_position)
	var changed: bool = step_index != sample.step_index
	step_index = sample.step_index
	selector.select(step_index)
	var step: Dictionary = sample.step
	if changed:
		before_canvas.set_document(sample.before)
		after_canvas.set_document(sample.after)
	before_label.text = "%s: %s" % [step.before, sample.before.data.title]
	after_label.text = "%s: %s" % [step.after, sample.after.data.title]
	# This is a visual fade between two complete records. No interpolated record
	# exists, is serialized, or is presented as a mathematical state.
	before_canvas.modulate.a = 1.0 - 0.65 * sample.local
	after_canvas.modulate.a = 0.35 + 0.65 * sample.local
	selected_list.clear()
	for selected in step.selected:
		selected_list.add_item("%s  %s" % [selected.kind, selected.id])
		selected_list.set_item_metadata(selected_list.item_count - 1, selected)
	if not step.selected.is_empty():
		selected_list.select(0)
		_select_record(step.selected[0])
	verification.text = "Recorded verification: %s, authority: %s. Studio does not validate this claim. %s" % [step.verification.status, step.verification.authority, step.verification.note]
	details.text = "%s\nOperation label: %s\nProvenance: %s, %s. %s" % [step.name, step.operation, step.provenance.kind, step.provenance.source, step.provenance.note]
	timeline_label.text = "Step %d/%d, %.1f%% visual crossfade. Current supplied reference: %s. No intermediate mathematical record is computed." % [step_index + 1, document.to_dict().steps.size(), sample.local * 100.0, sample.current_reference]

func _record_selected(record: Dictionary) -> void:
	if document == null or not record.has("kind") or not record.has("id"): return
	_select_record({"kind": record.kind, "id": record.id})
	details.text += "\nInspecting stable record %s:%s in both supplied endpoints." % [record.kind, record.id]

func _selected_row(index: int) -> void:
	_select_record(selected_list.get_item_metadata(index))

func _select_record(selected: Dictionary) -> void:
	for canvas in [before_canvas, after_canvas]:
		for record in canvas.document.inspector_records():
			if record.kind == selected.kind and record.id == selected.id:
				canvas.select_record(record)
				break

func set_play_direction(direction: int) -> void:
	if direction not in [-1, 1]: return
	play_direction = direction
	direction_option.select(0 if direction == 1 else 1)
	_stop_playback()
	play_button.text = "Play forward" if direction == 1 else "Play reverse"

func toggle_play() -> void:
	if document == null: return
	if playing:
		_stop_playback()
		return
	var end: float = document.to_dict().steps.size()
	if play_direction == 1 and timeline_position >= end: set_timeline_position(0.0, true)
	if play_direction == -1 and timeline_position <= 0.0: set_timeline_position(end, true)
	playing = true
	play_button.text = "Pause"

func advance(delta: float) -> void:
	if not playing or document == null or not is_finite(delta) or delta <= 0.0: return
	var next := WalkthroughTimeline.advance(document, timeline_position, delta / SECONDS_PER_STEP, play_direction)
	set_timeline_position(next, true)
	if next <= 0.0 or next >= document.to_dict().steps.size(): _stop_playback()

func _process(delta: float) -> void:
	advance(delta)

func _start() -> void: set_timeline_position(0.0)

func _end() -> void:
	if document != null: set_timeline_position(float(document.to_dict().steps.size()))

func _previous() -> void:
	if document == null: return
	var sample := WalkthroughTimeline.sample(document, timeline_position)
	set_timeline_position(float(sample.step_index if sample.local > 0.0 else maxi(0, sample.step_index - 1)))

func _next() -> void:
	if document == null: return
	var sample := WalkthroughTimeline.sample(document, timeline_position)
	set_timeline_position(float(mini(document.to_dict().steps.size(), sample.step_index + 1)))

func _stop_playback() -> void:
	playing = false
	if play_button != null: play_button.text = "Play forward" if play_direction == 1 else "Play reverse"

func _choose_save() -> void:
	if document == null: return
	save_dialog.current_file = "supplied-walkthrough.json"
	save_dialog.popup_centered_ratio(0.85)

func save_path(path: String) -> bool:
	if document == null: return false
	var error := document.save_path(path)
	status.text = "Saved exact walkthrough record." if error.is_empty() else error
	return error.is_empty()

func _close() -> void:
	closed.emit()
