class_name BraidEditor
extends VBoxContainer

signal edit_requested(action: String, index: int, generator: int)
signal view_changed(step: int, direction: String)

var document: DiagramDocument
var step := 0
var direction := ""
var playing := false
var elapsed := 0.0
var index_spin: SpinBox
var generator_spin: SpinBox
var direction_option: OptionButton
var scrub: HSlider
var play_button: Button
var detail: Label
var edit_note: Label

func _init() -> void:
	visible = false
	var heading := Label.new()
	heading.text = "Signed braid word and steps"
	heading.add_theme_font_size_override("font_size", 16)
	add_child(heading)
	var edit_row := HFlowContainer.new()
	add_child(edit_row)
	var index_label := Label.new()
	index_label.text = "Position"
	edit_row.add_child(index_label)
	index_spin = SpinBox.new()
	index_spin.min_value = 0
	index_spin.step = 1
	index_spin.tooltip_text = "Zero-based word position. Insert occurs before this position."
	index_spin.value_changed.connect(_index_changed)
	edit_row.add_child(index_spin)
	var generator_label := Label.new()
	generator_label.text = "Signed σ"
	edit_row.add_child(generator_label)
	generator_spin = SpinBox.new()
	generator_spin.step = 1
	generator_spin.value = 1
	generator_spin.tooltip_text = "Signed generator. Zero and indices at or above strand count are rejected."
	edit_row.add_child(generator_spin)
	for action in ["insert", "replace", "delete"]:
		var button := Button.new()
		button.text = action.capitalize()
		button.pressed.connect(_request_edit.bind(action))
		edit_row.add_child(button)
	edit_note = Label.new()
	edit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit_note.text = "Position is zero-based. Literal signed generators are never reduced or reordered."
	add_child(edit_note)
	var view_row := HFlowContainer.new()
	add_child(view_row)
	direction_option = OptionButton.new()
	direction_option.add_item("Bottom to top")
	direction_option.add_item("Top to bottom")
	direction_option.item_selected.connect(_direction_selected)
	view_row.add_child(direction_option)
	for spec in [["|<", _start], ["<", _back], [">", _forward], [">|", _end]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		view_row.add_child(button)
	play_button = Button.new()
	play_button.text = "Play"
	play_button.pressed.connect(toggle_play)
	view_row.add_child(play_button)
	scrub = HSlider.new()
	scrub.step = 1
	scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub.value_changed.connect(_scrub_changed)
	add_child(scrub)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)

func configure(value: DiagramDocument, selection: Dictionary = {}, reset_view: bool = false) -> void:
	document = value
	visible = document != null and document.data.kind == "braid"
	if not visible:
		playing = false
		return
	var length: int = document.data.braid.word.size()
	playing = false
	play_button.text = "Play"
	if reset_view or direction.is_empty():
		direction = document.data.braid.direction
		step = length
	else:
		step = clampi(step, 0, length)
	direction_option.select(0 if direction == "bottom-to-top" else 1)
	index_spin.max_value = length
	generator_spin.min_value = -int(document.data.braid.strands) + 1
	generator_spin.max_value = int(document.data.braid.strands) - 1
	scrub.max_value = length
	scrub.set_value_no_signal(step)
	inspect(selection)
	view_changed.emit(step, direction)

func inspect(selection: Dictionary) -> void:
	if not visible:
		return
	if selection.get("kind", "") == "crossing":
		var index: int = int(selection.get("index", -1))
		if index >= 0 and index < document.data.braid.word.size():
			index_spin.set_value_no_signal(index)
			generator_spin.set_value_no_signal(document.data.braid.word[index])
	_update_details()

func set_step(value: int, from_playback: bool = false) -> void:
	if not visible:
		return
	if not from_playback:
		playing = false
		play_button.text = "Play"
	step = clampi(value, 0, document.data.braid.word.size())
	scrub.set_value_no_signal(step)
	_update_details()
	view_changed.emit(step, direction)

func set_direction(value: String) -> void:
	if not visible or value not in ["bottom-to-top", "top-to-bottom"]:
		return
	direction = value
	direction_option.select(0 if direction == "bottom-to-top" else 1)
	_update_details()
	view_changed.emit(step, direction)

func toggle_play() -> void:
	if not visible:
		return
	if playing:
		playing = false
	else:
		if step == document.data.braid.word.size():
			set_step(0)
		playing = document.data.braid.word.size() > 0
		elapsed = 0.0
	play_button.text = "Pause" if playing else "Play"

func advance(delta: float) -> void:
	if not playing or not is_finite(delta) or delta <= 0:
		return
	elapsed += minf(delta, 5.0)
	while elapsed >= 0.6 and playing:
		elapsed -= 0.6
		set_step(step + 1, true)
		if step == document.data.braid.word.size():
			playing = false
			play_button.text = "Play"

func _process(delta: float) -> void:
	advance(delta)

func _request_edit(action: String) -> void:
	if not visible:
		return
	playing = false
	play_button.text = "Play"
	edit_requested.emit(action, int(index_spin.value), int(generator_spin.value))

func _direction_selected(index: int) -> void:
	set_direction("bottom-to-top" if index == 0 else "top-to-bottom")

func _index_changed(value: float) -> void:
	if not visible:
		return
	var index := int(value)
	if index < document.data.braid.word.size():
		generator_spin.set_value_no_signal(document.data.braid.word[index])
	_update_details()

func _scrub_changed(value: float) -> void:
	playing = false
	play_button.text = "Play"
	set_step(int(value))

func _start() -> void: set_step(0)
func _back() -> void: set_step(step - 1)
func _forward() -> void: set_step(step + 1)
func _end() -> void: set_step(document.data.braid.word.size())

func _update_details() -> void:
	var states := BraidTimeline.orders(document)
	if states.is_empty():
		return
	var lines := ["After %d/%d literal crossings: IDs left to right %s." % [step, states.size() - 1, states[step]]]
	var index: int = int(index_spin.value)
	if index >= 0 and index < states.size() - 1:
		var crossing := BraidTimeline.crossing(document, index, direction)
		lines.append("Selected σ%d%s: entry %s, exit %s; over strand ID %d. Positive means upper-left over upper-right." % [absi(crossing.generator), "" if crossing.generator > 0 else " inverse", crossing.before, crossing.after, crossing.over_id])
	lines.append("Presentation: %s. Timeline and camera are view state; the source word is unchanged." % direction)
	detail.text = "\n".join(lines)
