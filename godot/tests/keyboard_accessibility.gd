extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	_check(studio.record_list.get_accessibility_name() == "Mathematical records", "editor record list has an explicit accessible name")
	_check(studio.source_view.get_accessibility_name() == "Accepted normalized JSON source", "accepted source has an explicit accessible name")
	_check(studio.canvas.get_accessibility_name() == "Editable diagram canvas" and "Arrow keys" in studio.canvas.get_accessibility_description(), "canvas announces its keyboard controls")
	var accepted: String = studio.document.to_json()
	var pan_before: Vector2 = studio.canvas.pan
	_check(studio.canvas.handle_keyboard(_key(KEY_RIGHT)) and studio.canvas.pan.x < pan_before.x, "Right arrow pans the focused diagram")
	var zoom_before: float = studio.canvas.zoom
	_check(studio.canvas.handle_keyboard(_key(KEY_EQUAL)) and studio.canvas.zoom > zoom_before, "plus key zooms the focused diagram")
	_check(studio.canvas.handle_keyboard(_key(KEY_HOME)) and studio.canvas.pan == Vector2.ZERO and studio.canvas.zoom == 1.0, "Home fits the focused diagram")
	_check(studio.canvas.handle_keyboard(_key(KEY_BRACKETRIGHT)) and not studio.canvas.selected_record.is_empty(), "right bracket selects a stable record without a pointer")
	var first_id: String = studio.canvas.selected_record.get("id", "")
	_check(studio.canvas.handle_keyboard(_key(KEY_BRACKETRIGHT)) and studio.canvas.selected_record.get("id", "") != first_id, "bracket navigation advances in inspector order")
	_check(studio.document.to_json() == accepted, "canvas keyboard navigation leaves mathematical JSON byte-identical")

	studio.canvas.grab_focus()
	studio._unhandled_key_input(_key(KEY_2, true))
	await process_frame
	await process_frame
	_check(studio.surface_view.visible and not studio.workspace_root.visible, "Control-2 opens the exploratory workspace")
	_check(root.gui_get_focus_owner() == studio.surface_view.record_list, "surface workspace receives predictable initial focus")
	studio.surface_view.handle_keyboard(_key(KEY_ESCAPE))
	await process_frame
	_check(studio.workspace_root.visible and root.gui_get_focus_owner() == studio.canvas, "Escape returns to the editor and restores prior focus")

	var factor := FactorWorkspaceView.new()
	factor.browser_mode = true
	root.add_child(factor)
	await process_frame
	_check(factor.import_source(FileAccess.get_file_as_string("res://fixtures/workspaces/grouped-v1.json")), "factor fixture loads for keyboard test")
	var factor_source := factor.workspace.to_json()
	_check(factor.selector.get_accessibility_name() == "Selected factor" and factor.timeline.get_accessibility_name() == "Factor playback position", "factor selector and timeline have explicit accessible names")
	factor.handle_keyboard(_key(KEY_RIGHT))
	_check(factor.factor_index == 1 and factor.timeline_position == 1.0, "Right arrow advances one supplied factor")
	factor.handle_keyboard(_key(KEY_END))
	_check(factor.timeline_position == factor.workspace.to_dict().factors.size(), "End jumps to the sequence end")
	factor.handle_keyboard(_key(KEY_HOME))
	_check(factor.timeline_position == 0.0, "Home returns to the first factor")
	var factor_direction := factor.direction
	factor.handle_keyboard(_key(KEY_D))
	_check(factor.direction != factor_direction, "D changes braid presentation direction")
	factor.handle_keyboard(_key(KEY_SPACE))
	_check(factor.playing, "Space starts factor playback")
	factor.handle_keyboard(_key(KEY_SPACE))
	_check(not factor.playing and factor.workspace.to_json() == factor_source, "Space pauses and all factor keyboard actions preserve source")

	var surface := SurfaceWorkspaceView.new()
	surface.browser_mode = true
	root.add_child(surface)
	await process_frame
	_check(surface.import_source(FileAccess.get_file_as_string(SurfaceWorkspaceView.FIXTURE)), "surface fixture loads for keyboard test")
	var surface_source := surface.document.to_json()
	_check(surface.record_list.get_accessibility_name() == "Linked stable records" and "Arrow keys" in surface.surface_3d.get_accessibility_description(), "surface records and 3D view expose accessible guidance")
	surface.handle_keyboard(_key(KEY_DOWN))
	_check(surface.selected_id == "p1", "Down arrow selects the first stable surface record")
	surface.handle_keyboard(_key(KEY_DOWN))
	_check(surface.selected_id == "p2", "Down arrow advances stable surface selection")
	surface.handle_keyboard(_key(KEY_H))
	_check(surface.surface_3d.hidden_ids.has("p2"), "H hides the selected exploratory record")
	surface.handle_keyboard(_key(KEY_A))
	_check(surface.surface_3d.hidden_ids.is_empty(), "A restores all exploratory records")
	var camera_before := surface.surface_3d.camera.transform
	surface.surface_3d.handle_keyboard(_key(KEY_LEFT))
	_check(surface.surface_3d.camera.transform != camera_before, "3D arrow key orbits the camera")
	surface.surface_3d.handle_keyboard(_key(KEY_HOME))
	_check(is_equal_approx(surface.surface_3d.distance, 8.5) and surface.document.to_json() == surface_source, "3D Home fits without changing supplied geometry")

	var walkthrough := WalkthroughView.new()
	walkthrough.browser_mode = true
	root.add_child(walkthrough)
	await process_frame
	_check(walkthrough.import_source(FileAccess.get_file_as_string(WalkthroughView.PLANAR_FIXTURE)), "planar walkthrough loads for keyboard test")
	var walkthrough_source := walkthrough.document.to_json()
	_check(walkthrough.selector.get_accessibility_name() == "Selected walkthrough step" and walkthrough.timeline.get_accessibility_name() == "Walkthrough playback position", "walkthrough selector and timeline have explicit accessible names")
	walkthrough.handle_keyboard(_key(KEY_END))
	_check(walkthrough.timeline_position == walkthrough.document.to_dict().steps.size(), "walkthrough End reaches the final supplied endpoint")
	walkthrough.handle_keyboard(_key(KEY_HOME))
	_check(walkthrough.timeline_position == 0.0, "walkthrough Home returns to the start")
	walkthrough.handle_keyboard(_key(KEY_R))
	_check(walkthrough.play_direction == -1, "R reverses walkthrough playback direction")
	walkthrough.handle_keyboard(_key(KEY_SPACE))
	_check(walkthrough.playing, "Space starts reverse walkthrough playback")
	walkthrough.handle_keyboard(_key(KEY_SPACE))
	_check(not walkthrough.playing and walkthrough.document.to_json() == walkthrough_source, "walkthrough keyboard playback preserves supplied source")
	_check(walkthrough.import_source(FileAccess.get_file_as_string(WalkthroughView.BRAID_FIXTURE)), "braid walkthrough loads for keyboard presentation test")
	var presentation := walkthrough.braid_presentation
	walkthrough.handle_keyboard(_key(KEY_B))
	_check(walkthrough.braid_presentation != presentation, "B changes only the signed-braid presentation direction")

	for viewport in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = viewport
		root.content_scale_size = viewport
		studio._sync_viewport()
		await process_frame
		studio.canvas.grab_focus()
		_check(root.gui_get_focus_owner() == studio.canvas and studio.canvas.handle_keyboard(_key(KEY_HOME)), "diagram remains pointer-free at %s" % viewport)

	walkthrough.queue_free()
	surface.queue_free()
	factor.queue_free()
	studio.queue_free()
	await process_frame
	print("KEYBOARD ACCESSIBILITY %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _key(code: Key, command: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.ctrl_pressed = command
	return event

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
