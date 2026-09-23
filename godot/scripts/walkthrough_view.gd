class_name WalkthroughView
extends PanelContainer

signal closed
const PLANAR_FIXTURE := "res://fixtures/walkthroughs/point-and-label-v1.json"
const BRAID_FIXTURE := "res://fixtures/walkthroughs/signed-braid-v1.json"
const COVER_FIXTURE := "res://fixtures/walkthroughs/supplied-cover-disk-v1.json"
const FIXTURE := PLANAR_FIXTURE
const SECONDS_PER_STEP := 1.5

var document: WalkthroughDocument
var timeline_position := 0.0
var step_index := -1
var playing := false
var play_direction := 1
var braid_presentation := "bottom-to-top"
var browser_mode := OS.has_feature("web")
var source: TextEdit
var selector: OptionButton
var timeline: HSlider
var timeline_label: Label
var play_button: Button
var direction_option: OptionButton
var presentation_option: OptionButton
var details: Label
var verification: Label
var selected_list: ItemList
var before_canvas: DiagramCanvas
var after_canvas: DiagramCanvas
var before_label: Label
var after_label: Label
var grid: GridContainer
var cover_panel: VBoxContainer
var cover_grid: GridContainer
var cover_before_view: ExploratorySurface3D
var cover_after_view: ExploratorySurface3D
var cover_before_label: Label
var cover_after_label: Label
var cover_status: Label
var status: Label
var open_dialog: FileDialog
var save_dialog: FileDialog
var publication_button: Button
var publication_dialog: FileDialog
var publication: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_accessibility_name("Supplied transformation walkthrough")
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
	publication_button = _button(tools, "Export publication bundle", _choose_publication)
	publication_button.disabled = true
	_button(tools, "JSON import / source", func(): source.visible = not source.visible)
	_button(tools, "Import pasted JSON", func(): import_source(source.text))
	_button(tools, "Generic planar", func(): import_source(FileAccess.get_file_as_string(PLANAR_FIXTURE)))
	_button(tools, "Generic braid", func(): import_source(FileAccess.get_file_as_string(BRAID_FIXTURE)))
	_button(tools, "Generic supplied disk link", func(): import_source(FileAccess.get_file_as_string(COVER_FIXTURE)))
	var warning := _label(body, "SUPPLIED WALKTHROUGH. Playback crossfades complete endpoint records only. It does not compute an intermediate state or prove that an operation preserves any mathematical property.")
	warning.add_theme_color_override("font_color", Color("#a54439"))
	source = TextEdit.new()
	source.custom_minimum_size.y = 220
	source.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	source.virtual_keyboard_enabled = true
	source.visible = false
	source.set_accessibility_name("Walkthrough JSON source")
	source.set_accessibility_description("Bounded supplied source. Editing this field does not alter the loaded walkthrough until Import pasted JSON is activated.")
	body.add_child(source)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 44
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.item_selected.connect(func(index: int): set_timeline_position(float(index)))
	selector.set_accessibility_name("Selected walkthrough step")
	body.add_child(selector)
	var playback := HFlowContainer.new()
	body.add_child(playback)
	direction_option = OptionButton.new()
	direction_option.add_item("Play forward")
	direction_option.add_item("Play reverse")
	direction_option.custom_minimum_size.y = 44
	direction_option.item_selected.connect(func(index: int): set_play_direction(1 if index == 0 else -1))
	direction_option.set_accessibility_name("Walkthrough playback direction")
	playback.add_child(direction_option)
	presentation_option = OptionButton.new()
	presentation_option.add_item("Braid bottom to top")
	presentation_option.add_item("Braid top to bottom")
	presentation_option.custom_minimum_size.y = 44
	presentation_option.item_selected.connect(func(index: int): set_braid_presentation("bottom-to-top" if index == 0 else "top-to-bottom"))
	presentation_option.set_accessibility_name("Braid presentation direction")
	playback.add_child(presentation_option)
	_button(playback, "Start", _start)
	_button(playback, "Previous", _previous)
	play_button = _button(playback, "Play forward", toggle_play)
	_button(playback, "Next", _next)
	_button(playback, "End", _end)
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.custom_minimum_size.y = 44
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.value_changed.connect(func(value: float): set_timeline_position(value))
	timeline.set_accessibility_name("Walkthrough playback position")
	timeline.set_accessibility_description("View-only position between complete supplied endpoint records.")
	body.add_child(timeline)
	timeline_label = _label(body, "Timeline is view state.")
	_label(body, "Keyboard: Left/Right step, Home/End jump, Space plays or pauses, R reverses playback, B changes braid presentation, Escape returns to the editor.")
	verification = _label(body, "")
	verification.add_theme_color_override("font_color", Color("#a06a1a"))
	details = _label(body, "")
	selected_list = ItemList.new()
	selected_list.custom_minimum_size.y = 84
	selected_list.allow_reselect = true
	selected_list.item_selected.connect(_selected_row)
	selected_list.set_accessibility_name("Stable records selected by this supplied step")
	body.add_child(selected_list)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var before_column := _column("Complete supplied before-state")
	before_label = _label(before_column, "")
	before_canvas = _canvas(before_column)
	before_canvas.set_accessibility_name("Complete supplied before-state diagram")
	var after_column := _column("Complete supplied after-state")
	after_label = _label(after_column, "")
	after_canvas = _canvas(after_column)
	after_canvas.set_accessibility_name("Complete supplied after-state diagram")
	cover_panel = VBoxContainer.new()
	cover_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_panel.visible = false
	body.add_child(cover_panel)
	cover_status = _label(cover_panel, "")
	cover_status.add_theme_color_override("font_color", Color("#a54439"))
	cover_grid = GridContainer.new()
	cover_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_panel.add_child(cover_grid)
	var cover_before_column := _cover_column("Complete supplied exploratory before-view")
	cover_before_label = _label(cover_before_column, "")
	cover_before_view = _surface_view(cover_before_column)
	cover_before_view.set_accessibility_name("Complete supplied exploratory before-view")
	var cover_after_column := _cover_column("Complete supplied exploratory after-view")
	cover_after_label = _label(cover_after_column, "")
	cover_after_view = _surface_view(cover_after_column)
	cover_after_view.set_accessibility_name("Complete supplied exploratory after-view")
	status = _label(body, "")
	status.set_accessibility_name("Walkthrough status")
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
	publication_dialog = FileDialog.new()
	publication_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	publication_dialog.access = FileDialog.ACCESS_FILESYSTEM
	publication_dialog.add_filter("*.zip", "Deterministic publication bundle")
	publication_dialog.file_selected.connect(save_publication)
	add_child(publication_dialog)
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
	canvas.read_only = true
	canvas.custom_minimum_size.y = 330
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.record_selected.connect(_record_selected)
	parent.add_child(canvas)
	return canvas

func _cover_column(caption: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_grid.add_child(column)
	_label(column, caption)
	return column

func _surface_view(parent: Node) -> ExploratorySurface3D:
	var view := ExploratorySurface3D.new()
	view.custom_minimum_size.y = 330
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.record_picked.connect(_record_selected)
	parent.add_child(view)
	return view

func _responsive() -> void:
	if grid != null: grid.columns = 1 if get_viewport_rect().size.x < 900 else 2
	if cover_grid != null: cover_grid.columns = 1 if get_viewport_rect().size.x < 900 else 2

func focus_entry() -> void:
	if selector != null and selector.item_count > 0:
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
		KEY_R:
			set_play_direction(-play_direction)
		KEY_B:
			if document != null and document.kind() == "braid":
				set_braid_presentation("top-to-bottom" if braid_presentation == "bottom-to-top" else "bottom-to-top")
		_:
			return false
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and handle_keyboard(event):
		get_viewport().set_input_as_handled()

func _text_entry_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or (focused != null and focused.get_parent() is SpinBox)

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
	braid_presentation = document.diagram(document.to_dict().initial_state).data.braid.direction if document.kind() == "braid" else "bottom-to-top"
	direction_option.select(0)
	presentation_option.visible = document.kind() == "braid"
	presentation_option.select(0 if braid_presentation == "bottom-to-top" else 1)
	play_button.text = "Play forward"
	source.text = document.to_json()
	selector.clear()
	for step in document.to_dict().steps:
		selector.add_item("%s | %s" % [step.id, step.name])
	timeline.max_value = document.to_dict().steps.size()
	timeline.set_value_no_signal(0.0)
	set_timeline_position(0.0, true)
	publication = WalkthroughPublicationBridge._failure("Browser: exact Python publication export unavailable.") if browser_mode else WalkthroughPublicationBridge.build(document)
	publication_button.disabled = not publication.ok
	status.text = ("Loaded complete supplied endpoints. Deterministic Python publication bundle ready; exploratory 3D data is recorded but excluded from certified geometry exports." if publication.ok
		else "Loaded complete supplied endpoints. Publication unavailable: " + publication.error) + " Verification and provenance are imported metadata, not Studio conclusions."
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
		_update_cover(step)
	before_label.text = "%s: %s" % [step.before, sample.before.data.title]
	after_label.text = "%s: %s" % [step.after, sample.after.data.title]
	if document.kind() == "braid":
		var before_length: int = sample.before.data.braid.word.size()
		before_canvas.set_braid_view(float(before_length), braid_presentation)
		after_canvas.set_braid_view(before_length + sample.local * step.braid.word.size(), braid_presentation)
		before_canvas.modulate.a = 1.0
		after_canvas.modulate.a = 1.0
	else:
		# This is a visual fade between two complete records. No interpolated
		# record exists, is serialized, or is presented as a mathematical state.
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
	if document.kind() == "braid":
		details.text += "\nLiteral block %s. Supplied entry IDs %s; exit IDs %s. Positive means upper-left over upper-right in either presentation direction." % [step.braid.word, step.braid.entry_ids, step.braid.exit_ids]
		timeline_label.text = "Step %d/%d, %.1f%% through the literal supplied braid block. The schematic prefix is view state; the complete before/after words remain unchanged." % [step_index + 1, document.to_dict().steps.size(), sample.local * 100.0]
	else:
		timeline_label.text = "Step %d/%d, %.1f%% visual crossfade. Current supplied reference: %s. No intermediate mathematical record is computed." % [step_index + 1, document.to_dict().steps.size(), sample.local * 100.0, sample.current_reference]
	if step.has("cover"):
		details.text += "\nSurface linkage: %s. Provenance: %s, %s. Recorded verification: %s, %s. No cover lift is computed by Studio." % [step.cover.status, step.cover.provenance.kind, step.cover.provenance.source, step.cover.verification.status, step.cover.verification.authority]

func _update_cover(step: Dictionary) -> void:
	var has_cover: bool = step.has("cover")
	cover_panel.visible = has_cover
	if not has_cover:
		cover_before_view.set_document(null)
		cover_after_view.set_document(null)
		return
	var before_surface := document.surface_view(step.cover.before_surface)
	var after_surface := document.surface_view(step.cover.after_surface)
	cover_before_view.set_document(before_surface)
	cover_after_view.set_document(after_surface)
	cover_before_label.text = "%s: %s" % [step.cover.before_surface, before_surface.to_dict().title]
	cover_after_label.text = "%s: %s" % [step.cover.after_surface, after_surface.to_dict().title]
	cover_status.text = "SUPPLIED EXPLORATORY LINKAGE. These are complete endpoint views. Studio does not compute a branched-cover lift, interpolate surface geometry, or certify equivalence."

func _record_selected(record: Dictionary) -> void:
	if document == null or not record.has("kind") or not record.has("id"): return
	var selected := {"kind": record.kind, "id": record.id}
	if record.has("index"): selected.index = record.index
	_select_record(selected)
	details.text += "\nInspecting stable record %s:%s in both supplied endpoints." % [record.kind, record.id]

func _selected_row(index: int) -> void:
	_select_record(selected_list.get_item_metadata(index))

func _select_record(selected: Dictionary) -> void:
	for canvas in [before_canvas, after_canvas]:
		if selected.kind == "strand":
			canvas.select_record(selected)
			continue
		for record in canvas.document.inspector_records():
			if record.kind == selected.kind and record.id == selected.id and (not selected.has("index") or record.get("index", -1) == selected.index):
				canvas.select_record(record)
				break
	if selected.kind in ["object", "curve"]:
		for view in [cover_before_view, cover_after_view]:
			if view != null and view.document != null: view.select_id(str(selected.id))

func set_play_direction(direction: int) -> void:
	if direction not in [-1, 1]: return
	play_direction = direction
	direction_option.select(0 if direction == 1 else 1)
	_stop_playback()
	play_button.text = "Play forward" if direction == 1 else "Play reverse"

func set_braid_presentation(value: String) -> void:
	if document == null or document.kind() != "braid" or value not in ["bottom-to-top", "top-to-bottom"]: return
	braid_presentation = value
	presentation_option.select(0 if value == "bottom-to-top" else 1)
	set_timeline_position(timeline_position, true)

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

func _choose_publication() -> void:
	if not publication.get("ok", false): return
	publication_dialog.current_file = "walkthrough-publication.zip"
	publication_dialog.popup_centered_ratio(0.85)

func save_publication(path: String) -> bool:
	if not publication.get("ok", false): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not write publication bundle"
		return false
	file.store_buffer(publication.bundle)
	status.text = "Saved deterministic publication bundle with exact Python SVG/TikZ/Python endpoint exports. Exploratory 3D data remains excluded from certified geometry output."
	return true

func _close() -> void:
	closed.emit()
