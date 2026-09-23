class_name DiagramCanvas
extends Control

signal record_selected(record: Dictionary)
signal edit_commit_requested(kind: String, id: String, position: Vector2)
signal edit_preview_changed(valid: bool, message: String)
signal edit_rejected(message: String)
signal cut_picked(cut: int)

var document: DiagramDocument
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var pan_start := Vector2.ZERO
var selected_record: Dictionary = {}
var edit_dragging := false
var edit_drag_start := Vector2.ZERO
var edit_drag_moved := false
var preview_record: Dictionary = {}
var preview_position := Vector2.ZERO
var preview_valid := false
var preview_error := ""
var curve_draft_id := ""
var curve_draft_cuts: Array = []
var pick_for_new_curve := false
var braid_step := -1
var braid_playhead := -1.0
var braid_presentation := ""
var touch_move_enabled := false
var read_only := false
var touches: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_moved := false
var multi_touch := false

func set_document(value: DiagramDocument) -> void:
	cancel_touch_gesture()
	document = value
	zoom = 1.0
	pan = Vector2.ZERO
	selected_record = {}
	pick_for_new_curve = false
	braid_step = -1
	braid_playhead = -1.0
	braid_presentation = ""
	set_curve_draft("", [])
	cancel_edit_preview()
	queue_redraw()

func update_document(value: DiagramDocument, selection: Dictionary = {}) -> void:
	document = value
	selected_record = selection.duplicate(true)
	cancel_edit_preview()
	queue_redraw()

func select_record(record: Dictionary) -> void:
	selected_record = record.duplicate(true)
	queue_redraw()

func set_curve_draft(id: String, cuts: Array) -> void:
	curve_draft_id = id
	curve_draft_cuts = cuts.duplicate(true)
	queue_redraw()

func set_braid_view(playhead: float, direction: String) -> void:
	if document == null or document.data.kind != "braid":
		return
	if not is_finite(playhead) or direction not in ["bottom-to-top", "top-to-bottom"]:
		return
	braid_playhead = clampf(playhead, 0.0, document.data.braid.word.size())
	braid_step = floori(braid_playhead)
	braid_presentation = direction
	queue_redraw()

func fit_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		accept_event()
		return
	# Buttons still use Godot's normal emulated mouse taps. The canvas handles
	# real touch events itself, so their emulated duplicate must not edit twice.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(event.position, 1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if document != null and document.data.kind == "braid":
					select_braid_crossing(event.position)
				elif not begin_edit_drag(event.position) and (selected_record.get("kind", "") == "curve" or pick_for_new_curve):
					var cut := _hit_cut(event.position)
					if cut >= 0:
						cut_picked.emit(cut)
			elif edit_dragging:
				finish_edit_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			drag_start = event.position
			pan_start = pan
	elif event is InputEventMouseMotion:
		if edit_dragging:
			update_edit_drag(event.position)
		elif dragging:
			pan = pan_start + event.position - drag_start
			queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and edit_dragging:
		cancel_edit_preview()
		edit_rejected.emit("Edit cancelled; the accepted record was not changed")

func cancel_touch_gesture() -> void:
	touches.clear()
	multi_touch = false
	touch_moved = false
	cancel_edit_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_touch_gesture()

func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			cancel_touch_gesture()
			return
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				touch_start = event.position
				touch_moved = false
				multi_touch = false
				if touch_move_enabled:
					begin_edit_drag(event.position)
			else:
				multi_touch = true
				cancel_edit_preview()
		elif touches.has(event.index):
			if not multi_touch:
				if edit_dragging and touch_moved:
					finish_edit_drag(event.position)
				elif not touch_moved:
					cancel_edit_preview()
					_touch_tap(event.position)
				else:
					cancel_edit_preview()
			else:
				cancel_edit_preview()
			touches.erase(event.index)
			if touches.is_empty():
				multi_touch = false
	elif event is InputEventScreenDrag and touches.has(event.index):
		var previous: Vector2 = touches[event.index]
		if touches.size() == 2:
			var ids := touches.keys()
			var old_center: Vector2 = (touches[ids[0]] + touches[ids[1]]) / 2.0
			var old_distance: float = touches[ids[0]].distance_to(touches[ids[1]])
			touches[event.index] = event.position
			var new_center: Vector2 = (touches[ids[0]] + touches[ids[1]]) / 2.0
			var new_distance: float = touches[ids[0]].distance_to(touches[ids[1]])
			if old_distance >= 8.0 and new_distance >= 8.0:
				zoom_at(old_center, new_distance / old_distance)
			pan += new_center - old_center
			queue_redraw()
		else:
			touches[event.index] = event.position
			if not multi_touch:
				touch_moved = touch_moved or event.position.distance_to(touch_start) >= 6.0
				if edit_dragging:
					if touch_moved:
						update_edit_drag(event.position)
				else:
					pan += event.position - previous
					queue_redraw()

func _touch_tap(point: Vector2) -> void:
	if document == null:
		return
	if document.data.kind == "braid":
		select_braid_crossing(point)
		return
	var record := _hit_planar_record(point)
	if not record.is_empty():
		select_record(record)
		record_selected.emit(record)
	elif selected_record.get("kind", "") == "curve" or pick_for_new_curve:
		var cut := _hit_cut(point)
		if cut >= 0:
			cut_picked.emit(cut)

func begin_edit_drag(screen_position: Vector2) -> bool:
	if document == null or document.data.kind != "planar":
		return false
	var record := _hit_planar_record(screen_position)
	if record.is_empty():
		return false
	select_record(record)
	record_selected.emit(record.duplicate(true))
	# Read-only linked/support views still need mouse selection, but never create
	# a drag preview or edit command. Returning true means the click was handled.
	if read_only: return true
	preview_record = record.duplicate(true)
	preview_position = _record_position(record)
	preview_valid = true
	preview_error = ""
	edit_dragging = true
	edit_drag_start = screen_position
	edit_drag_moved = false
	if is_inside_tree():
		grab_focus()
	queue_redraw()
	return true

func update_edit_drag(screen_position: Vector2) -> Dictionary:
	if not edit_dragging:
		return {"ok": false, "error": "No edit drag is active"}
	edit_drag_moved = edit_drag_moved or screen_position.distance_to(edit_drag_start) >= 2.0
	var frame := _planar_frame(document.data)
	var world := _world(screen_position, frame)
	if preview_record.kind == "object":
		preview_position = Vector2(world.x, 0.0)
		var limits := _object_x_limits(preview_record.id)
		preview_valid = world.x > limits.x and world.x < limits.y
		preview_error = "" if preview_valid else "Object %s must remain strictly between x=%s and x=%s; endpoint/cut numbers were not changed" % [preview_record.id, limits.x, limits.y]
	else:
		preview_position = world
		preview_valid = absf(world.x) <= 10000.0 and absf(world.y) <= 10000.0
		preview_error = "" if preview_valid else "Label coordinates must remain within -10000..10000"
	edit_preview_changed.emit(preview_valid, preview_error)
	queue_redraw()
	return {"ok": preview_valid, "error": preview_error, "position": preview_position}

func finish_edit_drag(screen_position: Vector2) -> void:
	if not edit_dragging:
		return
	var update := update_edit_drag(screen_position)
	var should_commit: bool = edit_drag_moved and bool(update.ok)
	var rejection := preview_error
	var record := preview_record.duplicate(true)
	var position := preview_position
	cancel_edit_preview()
	if should_commit:
		edit_commit_requested.emit(record.kind, record.id, position)
	elif not rejection.is_empty():
		edit_rejected.emit(rejection)

func cancel_edit_preview() -> void:
	edit_dragging = false
	edit_drag_moved = false
	preview_record = {}
	preview_position = Vector2.ZERO
	preview_valid = false
	preview_error = ""
	queue_redraw()

func screen_position_for_record(record: Dictionary) -> Vector2:
	if document == null or document.data.kind != "planar":
		return Vector2.INF
	return _screen(_record_position(record), _planar_frame(document.data))

func screen_position_for_cut(cut: int) -> Vector2:
	if document == null or document.data.kind != "planar":
		return Vector2.INF
	var data := document.data
	if cut < 0 or cut > data.surface.objects.size():
		return Vector2.INF
	var endpoint_x: Array[float] = [-data.surface.width / 2.0]
	for object in data.surface.objects:
		endpoint_x.append(object.x)
	endpoint_x.append(data.surface.width / 2.0)
	var x: float = (endpoint_x[cut] + endpoint_x[cut + 1]) / 2.0
	return _screen(Vector2(x, 0), _planar_frame(data))

func _braid_frame() -> Dictionary:
	var braid: Dictionary = document.data.braid
	return _frame(maxf(160.0, (braid.strands - 1) * braid.spacing), maxi(1, braid.word.size()) * braid.step + 80.0)

func _braid_sample() -> Dictionary:
	var time: float = document.data.braid.word.size() if braid_playhead < 0 else braid_playhead
	return BraidTimeline.sample(document, time, braid_presentation)

func screen_position_for_crossing(index: int) -> Vector2:
	if document == null or document.data.kind != "braid":
		return Vector2.INF
	var sample := _braid_sample()
	for crossing in sample.crossings:
		if crossing.index == index and crossing.fraction >= 0.5:
			return _screen((crossing.a + crossing.b) / 2.0, _braid_frame())
	return Vector2.INF

func select_braid_crossing(screen_position: Vector2) -> bool:
	if document == null or document.data.kind != "braid" or not screen_position.is_finite():
		return false
	var sample := _braid_sample()
	var frame := _braid_frame()
	var nearest := -1
	var distance := 13.0
	for crossing in sample.crossings:
		if crossing.fraction < 0.5:
			continue
		var center := _screen((crossing.a + crossing.b) / 2.0, frame)
		var candidate := center.distance_to(screen_position)
		if candidate < distance:
			distance = candidate
			nearest = crossing.index
	if nearest < 0:
		return false
	var record: Dictionary = document.inspector_records()[nearest + 1]
	select_record(record)
	record_selected.emit(record.duplicate(true))
	return true

func zoom_at(point: Vector2, factor: float) -> void:
	var old := zoom
	zoom = clampf(zoom * factor, 0.25, 4.0)
	pan = point - size / 2.0 - (point - size / 2.0 - pan) * zoom / old
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#ffffff"))
	if document == null:
		return
	if document.data.kind == "planar":
		_draw_planar(document.data)
	else:
		_draw_braid(document.data)

func _frame(width: float, height: float) -> Dictionary:
	var available := size - Vector2(70, 90)
	var base_scale: float = minf(available.x / maxf(width, 1), available.y / maxf(height, 1))
	return {"origin": size / 2.0 + pan, "scale": maxf(0.05, base_scale) * zoom}

func _screen(point: Vector2, frame: Dictionary) -> Vector2:
	return frame.origin + Vector2(point.x, -point.y) * frame.scale

func _world(point: Vector2, frame: Dictionary) -> Vector2:
	var offset: Vector2 = (point - frame.origin) / frame.scale
	return Vector2(offset.x, -offset.y)

func _planar_frame(data: Dictionary) -> Dictionary:
	return _frame(data.surface.width, data.surface.height + 70.0)

func _record_position(record: Dictionary) -> Vector2:
	if document == null or document.data.kind != "planar":
		return Vector2.INF
	if record.kind == "object":
		for object in document.data.surface.objects:
			if object.id == record.id:
				return Vector2(object.x, 0.0)
	elif record.kind == "label":
		for label in document.data.labels:
			if label.id == record.id:
				return Vector2(label.x, label.y)
	return Vector2.INF

func _hit_planar_record(screen_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 20.0
	for record in document.inspector_records():
		if record.kind not in ["object", "label"]:
			continue
		var at := screen_position_for_record(record)
		var distance := at.distance_to(screen_position)
		if record.kind == "label":
			var label: Dictionary = document.data.labels[record.index]
			var text_width := ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(label.size)).x
			if absf(at.x - screen_position.x) <= text_width / 2.0 + 8.0 and absf(at.y - screen_position.y) <= float(label.size) + 8.0:
				distance = 0.0
		if distance < best_distance:
			best = record.duplicate(true)
			best_distance = distance
	return best

func _object_x_limits(id: String) -> Vector2:
	var data := document.data
	var objects: Array = data.surface.objects
	for index in objects.size():
		if objects[index].id == id:
			var left: float = -data.surface.width / 2.0 if index == 0 else objects[index - 1].x
			var right: float = data.surface.width / 2.0 if index == objects.size() - 1 else objects[index + 1].x
			return Vector2(left, right)
	return Vector2.INF

func _hit_cut(screen_position: Vector2) -> int:
	if document == null or document.data.kind != "planar":
		return -1
	var data := document.data
	var closest := -1
	var distance := 16.0
	for cut in data.surface.objects.size() + 1:
		var tick := screen_position_for_cut(cut)
		# The numbered label and its axis tick are both usable targets.
		var candidate := minf(tick.distance_to(screen_position), (tick + Vector2(0, 35)).distance_to(screen_position))
		if is_equal_approx(candidate, distance):
			closest = -1
		elif candidate < distance:
			closest = cut
			distance = candidate
	return closest

func _draw_planar(data: Dictionary) -> void:
	var surface: Dictionary = data.surface
	var frame := _planar_frame(data)
	var origin: Vector2 = frame.origin
	var scale: float = frame.scale
	var style: Dictionary = data.style
	if style.show_outer_ellipse:
		_draw_ellipse(origin, Vector2(surface.width, surface.height) * scale / 2.0, Color(style.outline_color), maxf(1.0, style.outline_width * scale))
	var endpoint_x: Array[float] = [-surface.width / 2.0]
	for object in surface.objects: endpoint_x.append(object.x)
	endpoint_x.append(surface.width / 2.0)
	draw_line(_screen(Vector2(endpoint_x[0], 0), frame), _screen(Vector2(endpoint_x[-1], 0), frame), Color("#d9e2dc"), 1.0)
	for index in data.curves.size():
		var curve: Dictionary = data.curves[index]
		_draw_curve(curve, endpoint_x, frame, style,
			selected_record.get("kind", "") == "curve" and selected_record.get("id", "") == curve.id)
	for index in surface.objects.size():
		var object: Dictionary = surface.objects[index]
		var radius: float = object.radius if object.radius != null else (style.boundary_radius if object.kind == "boundary" else style.marked_point_radius)
		var center := _screen(Vector2(object.x, 0), frame)
		if object.kind == "boundary" and style.boundary_shape == "circle":
			draw_arc(center, radius * scale, 0.0, TAU, 32, Color(style.boundary_color), maxf(1.0, 1.5 * scale), true)
		else:
			draw_circle(center, maxf(3.0, radius * scale), Color(style.boundary_color if object.kind == "boundary" else style.marked_point_color))
		if selected_record.get("kind", "") == "object" and selected_record.get("id", "") == object.id:
			draw_arc(center, maxf(9.0, radius * scale + 6.0), 0.0, TAU, 40, Color("#f2a900"), 3.0, true)
		_draw_centered(object.id, center + Vector2(0, 23), Color("#203634"), 13)
	for index in endpoint_x.size():
		var at := _screen(Vector2(endpoint_x[index], 0), frame)
		_draw_centered(str(index), at + Vector2(0, -20), Color("#167464"), 12)
	for cut in surface.objects.size() + 1:
		var x: float = (endpoint_x[cut] + endpoint_x[cut + 1]) / 2.0
		var at := _screen(Vector2(x, 0), frame)
		draw_line(at + Vector2(0, -4), at + Vector2(0, 4), Color("#9aaba6"), 1.0)
		_draw_centered("c%d" % cut, at + Vector2(0, 35), Color("#6b7b78"), 11)
		if (curve_draft_id == selected_record.get("id", "") or pick_for_new_curve) and cut in curve_draft_cuts:
			draw_arc(at, 10.0, 0.0, TAU, 24, Color("#f2a900"), 2.0, true)
			var visits: Array[String] = []
			for visit in curve_draft_cuts.size():
				if curve_draft_cuts[visit] == cut:
					visits.append(str(visit + 1))
			_draw_centered(",".join(visits), at + Vector2(0, -32), Color("#b26b00"), 10)
	for label in data.labels:
		var label_at := _screen(Vector2(label.x, label.y), frame)
		_draw_centered(label.text, label_at, Color(label.color), int(label.size))
		if selected_record.get("kind", "") == "label" and selected_record.get("id", "") == label.id:
			var text_size := ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(label.size))
			draw_rect(Rect2(label_at - Vector2(text_size.x / 2.0 + 5.0, text_size.y), text_size + Vector2(10, 7)), Color("#f2a900"), false, 2.0)
	_draw_edit_preview(frame, data)
	_draw_centered("Drag a point or label to propose an edit. Release validates before commit.", Vector2(size.x / 2.0, size.y - 18), Color("#6b7b78"), 12)

func _draw_edit_preview(frame: Dictionary, data: Dictionary) -> void:
	if preview_record.is_empty():
		return
	var original := _screen(_record_position(preview_record), frame)
	var proposed := _screen(preview_position, frame)
	var preview_color := Color("#167464") if preview_valid else Color("#a54439")
	draw_dashed_line(original, proposed, preview_color, 2.0, 6.0, true)
	if preview_record.kind == "object":
		var object: Dictionary = data.surface.objects[preview_record.index]
		var fill := Color(data.style.boundary_color if object.kind == "boundary" else data.style.marked_point_color)
		fill.a = 0.45
		draw_circle(proposed, 7.0, fill)
		draw_arc(proposed, 11.0, 0.0, TAU, 32, preview_color, 3.0, true)
	else:
		var label: Dictionary = data.labels[preview_record.index]
		_draw_centered(label.text, proposed, Color(preview_color, 0.7), int(label.size))
	_draw_centered("preview", proposed + Vector2(0, -16), preview_color, 11)

func _draw_curve(curve: Dictionary, endpoint_x: Array[float], frame: Dictionary, style: Dictionary, selected: bool = false) -> void:
	var points := PackedVector2Array()
	var up: bool = (curve.get("direction", "default") != "down") if curve.kind == "arc" else curve.get("start_up", true)
	if curve.kind == "arc":
		points.append(_screen(Vector2(endpoint_x[curve.start], 0), frame))
	for index in curve.cuts.size():
		var cut: int = curve.cuts[index]
		var x := (endpoint_x[cut] + endpoint_x[cut + 1]) / 2.0
		var height: float = 34.0 + index * 8.0
		points.append(_screen(Vector2(x, height if up else -height), frame))
		up = not up
	if curve.kind == "arc":
		if points.size() == 1:
			points.append(_screen(Vector2((endpoint_x[curve.start] + endpoint_x[curve.end]) / 2.0, 40.0 if up else -40.0), frame))
		points.append(_screen(Vector2(endpoint_x[curve.end], 0), frame))
	elif points.size() > 1:
		points.append(points[0])
	if points.size() >= 2:
		if selected:
			draw_polyline(points, Color("#f2a900"), maxf(7.0, style.curve_width * frame.scale + 6.0), true)
		draw_polyline(points, Color(curve.color), maxf(2.0, style.curve_width * frame.scale), true)

func _draw_braid(data: Dictionary) -> void:
	var braid: Dictionary = data.braid
	var frame := _braid_frame()
	var sample := _braid_sample()
	var colors: Array = braid.colors
	var points: Array = []
	var bottom_up: bool = sample.direction == "bottom-to-top"
	for path in sample.paths:
		var screen_points := PackedVector2Array()
		for point in path:
			screen_points.append(_screen(point, frame))
		points.append(screen_points)
	# Selection is drawn behind the strands so highlighting cannot hide a gap.
	for crossing in sample.crossings:
		if crossing.fraction >= 0.5 and selected_record.get("kind", "") == "crossing" and selected_record.get("index", -1) == crossing.index:
			var middle := _screen((crossing.a + crossing.b) / 2.0, frame)
			draw_circle(middle, 17.0, Color("#fff4cf"))
			draw_arc(middle, 17.0, 0.0, TAU, 32, Color("#f2a900"), 3.0, true)
	for identity in braid.strands:
		if points[identity].size() >= 2:
			if selected_record.get("kind", "") == "strand" and selected_record.get("id", -1) == identity + 1:
				draw_polyline(points[identity], Color("#f2a900"), 9.0, true)
			draw_polyline(points[identity], Color(colors[identity % colors.size()]), 4.0, true)
		else:
			if selected_record.get("kind", "") == "strand" and selected_record.get("id", -1) == identity + 1:
				draw_circle(points[identity][0], 8.0, Color("#f2a900"))
			draw_circle(points[identity][0], 3.0, Color(colors[identity % colors.size()]))
	for crossing in sample.crossings:
		var start := _screen(crossing.a, frame)
		var end := _screen(crossing.b, frame)
		var half_gap := minf(0.18, 11.0 / maxf(0.001, start.distance_to(end)))
		var from := 0.5 - half_gap
		var to := minf(0.5 + half_gap, crossing.fraction)
		if to > from:
			var color := Color(colors[(crossing.over_id - 1) % colors.size()])
			draw_line(start.lerp(end, from), start.lerp(end, to), Color("#ffffff"), 9.0, true)
			draw_line(start.lerp(end, from), start.lerp(end, to), color, 4.0, true)
	for identity in braid.strands:
		_draw_centered(str(identity + 1), points[identity][0] + Vector2(0, 18 if bottom_up else -12), Color(colors[identity % colors.size()]), 12)
		if is_equal_approx(sample.time, roundf(sample.time)):
			_draw_centered(str(identity + 1), points[identity][-1] + Vector2(0, -12 if bottom_up else 18), Color(colors[identity % colors.size()]), 12)
	_draw_centered("Step %.2f/%d. Positive = upper-left over upper-right in either direction." % [sample.time, braid.word.size()], Vector2(size.x / 2.0, size.y - 18), Color("#6b7b78"), 12)

func _draw_centered(text: String, at: Vector2, color: Color, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(text_width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 97:
		var angle := TAU * index / 96.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)
