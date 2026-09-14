class_name CurveInspector
extends VBoxContainer

signal apply_requested(curve_id: String, cuts: Array)
signal draft_changed(curve_id: String, cuts: Array, message: String)

var document: DiagramDocument
var curve_id := ""
var accepted_cuts: Array = []
var draft_cuts: Array = []
var heading: Label
var details: Label
var draft_label: Label
var warning_label: Label
var cut_grid: GridContainer
var apply_button: Button
# Session-only drafts keyed by stable ID, separate from mathematical records.
# Re-selection or movement of another point must not erase rejected input.
var drafts: Dictionary = {}

func _init() -> void:
	visible = false
	add_theme_constant_override("separation", 5)
	heading = Label.new()
	heading.text = "Curve inspector"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#167464"))
	add_child(heading)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	draft_label = Label.new()
	draft_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(draft_label)
	var instruction := Label.new()
	instruction.text = "Pick cuts in visit order. Repeated visits stay repeated. Unapplied drafts stay in this session; Save JSON writes only the accepted record."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color("#6b7b78"))
	add_child(instruction)
	cut_grid = GridContainer.new()
	add_child(cut_grid)
	var actions := HFlowContainer.new()
	add_child(actions)
	for spec in [["Remove last", _remove_last], ["Clear", _clear], ["Reset", _reset]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		actions.add_child(button)
	apply_button = Button.new()
	apply_button.text = "Apply exact cuts"
	apply_button.pressed.connect(_apply)
	actions.add_child(apply_button)
	warning_label = Label.new()
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(warning_label)

func inspect(value: DiagramDocument, record: Dictionary) -> void:
	document = value
	curve_id = ""
	if document == null or document.data.kind != "planar" or record.get("kind", "") != "curve":
		visible = false
		return
	for curve in document.data.curves:
		if curve.id == record.get("id", ""):
			curve_id = curve.id
			accepted_cuts = curve.cuts.duplicate(true)
			draft_cuts = drafts.get(curve_id, accepted_cuts).duplicate(true)
			heading.text = "Curve inspector: " + curve.id
			if curve.kind == "arc":
				details.text = "Arc %d -> %d   direction=%s   accepted cuts=%s" % [curve.start, curve.end, curve.direction, accepted_cuts]
			else:
				details.text = "Loop   start_up=%s   accepted cuts=%s" % [curve.start_up, accepted_cuts]
			_build_cut_buttons(document.data.surface.objects.size() + 1)
			visible = true
			_refresh()
			return
	visible = false

func append_cut(cut: int) -> void:
	if curve_id.is_empty() or cut < 0 or cut > document.data.surface.objects.size():
		return
	if draft_cuts.size() >= DiagramDocument.MAX_CUTS:
		warning_label.text = "Draft limit: 64 visits. Remove a visit before adding another; no input was simplified."
		return
	draft_cuts.append(cut)
	_refresh()

func clear_drafts() -> void:
	drafts.clear()
	curve_id = ""
	accepted_cuts.clear()
	draft_cuts.clear()
	visible = false

func discard_draft(id: String) -> void:
	drafts.erase(id)

func _build_cut_buttons(count: int) -> void:
	for child in cut_grid.get_children():
		cut_grid.remove_child(child)
		child.queue_free()
	cut_grid.columns = mini(7, count)
	for cut in count:
		var button := Button.new()
		button.text = "c%d" % cut
		button.tooltip_text = "Append cut %d to the itinerary" % cut
		button.pressed.connect(append_cut.bind(cut))
		cut_grid.add_child(button)

func _remove_last() -> void:
	if not draft_cuts.is_empty():
		draft_cuts.pop_back()
		_refresh()

func _clear() -> void:
	draft_cuts.clear()
	_refresh()

func _reset() -> void:
	draft_cuts = accepted_cuts.duplicate(true)
	_refresh()

func _apply() -> void:
	if curve_id.is_empty() or draft_cuts == accepted_cuts:
		return
	apply_requested.emit(curve_id, draft_cuts.duplicate(true))

func _refresh() -> void:
	if not curve_id.is_empty():
		if draft_cuts == accepted_cuts:
			drafts.erase(curve_id)
		else:
			drafts[curve_id] = draft_cuts.duplicate(true)
	draft_label.text = "Draft cuts: %s" % [draft_cuts]
	apply_button.disabled = draft_cuts == accepted_cuts
	var warning := _draft_warning()
	warning_label.text = warning
	warning_label.add_theme_color_override("font_color", Color("#a54439") if "reject" in warning else Color("#415b55"))
	draft_changed.emit(curve_id, draft_cuts.duplicate(true), warning)

func _draft_warning() -> String:
	for index in range(1, draft_cuts.size()):
		if draft_cuts[index] == draft_cuts[index - 1]:
			return "Consecutive equal visits are nonminimal; Apply will reject this draft without changing the record."
	return "Draft order is literal. Apply validates it without sorting, cancellation, or rerouting."
