extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	for viewport in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1280, 800)]:
		root.size = viewport
		studio._sync_viewport()
		studio._show_mobile_panel(false)
		for frame in 4: await process_frame
		var bounds: Rect2 = studio.canvas.get_global_rect()
		_check(bounds.position.x >= 0 and bounds.end.x <= viewport.x + 1 and bounds.end.y <= viewport.y + 1 and bounds.size.y >= 80, "diagram fits viewport %s: %s" % [viewport, bounds])
		_check(studio.compact_layout == (viewport.x < 900) and root.content_scale_size == viewport, "layout uses logical viewport pixels at %s" % viewport)
		studio._show_mobile_panel(true)
		for frame in 4: await process_frame
		bounds = studio.inspector_scroll.get_global_rect()
		_check(bounds.end.x <= viewport.x + 1 and bounds.end.y <= viewport.y + 1, "records remain reachable by scrolling at %s" % viewport)
		_check(studio.undo_button.custom_minimum_size.y >= 44 and studio.move_button.custom_minimum_size.y >= 44, "primary controls have touch-sized targets")
	root.size = Vector2i(390, 844)
	studio._sync_viewport()
	studio._show_mobile_panel(false)
	for frame in 4: await process_frame
	var canvas: DiagramCanvas = studio.canvas
	var original: String = studio.document.to_json()
	var point: Vector2 = canvas.screen_position_for_record(studio.document.inspector_records()[0])
	_touch(canvas, 0, point, true)
	_touch(canvas, 0, point, false)
	_check(canvas.selected_record.id == "p1" and not canvas.edit_dragging, "tap selects persistent point ID without starting an edit")
	var pan_before := canvas.pan
	_touch(canvas, 0, Vector2(100, 80), true)
	_drag(canvas, 0, Vector2(120, 90))
	_touch(canvas, 0, Vector2(120, 90), false)
	_check(canvas.pan == pan_before + Vector2(20, 10) and studio.document.to_json() == original, "one-finger navigation pans without changing a point")
	canvas.touch_move_enabled = true
	studio.browser_drafts.button_pressed = true
	point = canvas.screen_position_for_record(studio.document.inspector_records()[0])
	_touch(canvas, 0, point, true)
	_drag(canvas, 0, point + Vector2(7, 0))
	_touch(canvas, 0, point + Vector2(7, 0), false)
	_check(studio.history.undo_stack.size() == 1 and studio.document.to_json() != original, "explicit point move commits once through the existing bounded controller")
	studio._undo()
	_check(studio.document.to_json() == original, "touch move undo restores exact recipe")
	point = canvas.screen_position_for_record(studio.document.inspector_records()[0])
	_touch(canvas, 0, point, true)
	_drag(canvas, 0, point + Vector2(7, 0))
	_touch(canvas, 1, point + Vector2(90, 0), true)
	var zoom_before := canvas.zoom
	_drag(canvas, 1, point + Vector2(120, 0))
	_touch(canvas, 1, point + Vector2(120, 0), false)
	_touch(canvas, 0, point + Vector2(7, 0), false)
	_check(canvas.zoom > zoom_before and studio.document.to_json() == original and not canvas.edit_dragging, "second finger cancels edit preview and pinches without committing")
	point = canvas.screen_position_for_record(studio.document.inspector_records()[0])
	_touch(canvas, 0, point, true)
	_drag(canvas, 0, point + Vector2(7, 0))
	_touch(canvas, 0, point + Vector2(7, 0), false, true)
	_check(studio.document.to_json() == original and canvas.touches.is_empty(), "OS touch cancellation discards in-flight edit")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = point
	canvas._gui_input(mouse)
	_check(not canvas.edit_dragging, "touch-generated mouse duplicate cannot begin another edit")
	studio.curve_creator.start("arc")
	studio._show_mobile_panel(true)
	for frame in 4: await process_frame
	_check(studio.curve_creator.cut_grid.get_combined_minimum_size().x < 366 and studio.curve_creator.cut_grid.get_child(0).custom_minimum_size.y == 44, "new curve cuts fit phone width with touch targets")
	_check(studio.curve_creator.form.get_global_rect().size.x <= 366, "curve creation form fits phone records pane")
	studio.curve_creator.cancel()
	studio._open_resource("res://fixtures/braid-v1.json")
	studio._show_mobile_panel(false)
	for frame in 4: await process_frame
	point = canvas.screen_position_for_crossing(0)
	_touch(canvas, 0, point, true)
	_touch(canvas, 0, point, false)
	_check(canvas.selected_record.kind == "crossing" and studio.braid_editor.index_spin.value == 0, "tap selects exact braid crossing")
	studio.queue_free()
	await process_frame
	print("MOBILE CONTROLLER %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _touch(canvas: DiagramCanvas, index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	canvas._gui_input(event)

func _drag(canvas: DiagramCanvas, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	canvas._gui_input(event)

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
