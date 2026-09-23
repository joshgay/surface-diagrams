extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	WorkspaceRecovery.clear_file()
	var packed := load("res://scenes/studio.tscn") as PackedScene
	_check(packed != null, "studio scene loads")
	if packed == null:
		_finish()
		return
	var studio := packed.instantiate()
	root.add_child(studio)
	await process_frame
	await process_frame
	_check(studio.document != null, "ready opens initial document")
	_check(studio.document.data.kind == "planar", "initial fixture is planar")
	_check(studio.record_list.item_count == 6, "planar inspector shows four objects, curve, and label")
	_check(studio.canvas.document.to_json() == studio.document.to_json(), "canvas receives same immutable record")
	_check(studio.geometry_result.ok, "planar fixture has exact Python geometry")
	_check(not studio.svg_button.disabled and not studio.tikz_button.disabled, "publication exports are enabled after exact render")
	var planar_before: String = studio.document.to_json()
	studio.record_list.select(4)
	studio.record_list.item_selected.emit(4)
	_check(studio.canvas.selected_record.id == "arc1", "planar inspector selects stable curve ID")
	_check(studio.document.to_json() == planar_before, "selection does not change planar record")
	studio.export_kind = "svg"
	var export_path := "user://ui-smoke.svg"
	studio._save_export(export_path)
	var exported := FileAccess.get_file_as_string(export_path)
	_check(exported == studio.geometry_result.svg and exported.begins_with("<svg"), "Godot saves exact bridge SVG without regeneration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(export_path))
	studio.export_kind = "tikz"
	export_path = "user://ui-smoke.tikz"
	studio._save_export(export_path)
	exported = FileAccess.get_file_as_string(export_path)
	_check(exported == studio.geometry_result.tikz and "tikzpicture" in exported, "Godot saves exact bridge TikZ without regeneration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(export_path))
	studio.canvas.zoom_at(studio.canvas.size / 2.0, 1.2)
	studio.canvas.pan = Vector2(14, -6)
	var edit_zoom: float = studio.canvas.zoom
	var edit_pan: Vector2 = studio.canvas.pan
	var object_record: Dictionary = studio.document.inspector_records()[1]
	var point_start: Vector2 = studio.canvas.screen_position_for_record(object_record)
	_check(studio.canvas.begin_edit_drag(point_start), "live canvas hit-tests point for editing")
	var preview: Dictionary = studio.canvas.update_edit_drag(point_start + Vector2(20, 0))
	_check(preview.ok and studio.document.to_json() == planar_before, "live drag is a non-mutating preview")
	studio.canvas.finish_edit_drag(point_start + Vector2(20, 0))
	var planar_edited: String = studio.document.to_json()
	_check(planar_edited != planar_before and studio.document.data.surface.objects[1].id == "p2", "release commits accepted point move with stable ID")
	_check(studio.document.data.curves[0].cuts == [] and studio.document.data.curves[0].start == 1 and studio.document.data.curves[0].end == 3, "point edit preserves endpoint and cut records")
	_check(studio.geometry_result.ok and not studio.undo_button.disabled, "accepted edit has exact geometry and enables undo")
	_check(studio.canvas.zoom == edit_zoom and studio.canvas.pan == edit_pan, "accepted edit preserves separate camera state")
	studio._undo()
	_check(studio.document.to_json() == planar_before and not studio.redo_button.disabled, "UI undo restores exact original recipe")
	studio._redo()
	_check(studio.document.to_json() == planar_edited and not studio.undo_button.disabled, "UI redo restores exact edited recipe")
	object_record = studio.document.inspector_records()[1]
	point_start = studio.canvas.screen_position_for_record(object_record)
	var neighbor_position: Vector2 = studio.canvas.screen_position_for_record(studio.document.inspector_records()[2])
	_check(studio.canvas.begin_edit_drag(point_start), "second point drag begins")
	preview = studio.canvas.update_edit_drag(neighbor_position + Vector2(5, 0))
	_check(not preview.ok and studio.document.to_json() == planar_edited, "cross-neighbor drag remains a rejected preview")
	studio.canvas.finish_edit_drag(neighbor_position + Vector2(5, 0))
	_check(studio.document.to_json() == planar_edited and "strictly between" in studio.status_label.text, "rejected release preserves accepted point state")
	var label_record: Dictionary = studio.document.inspector_records()[-1]
	var label_start: Vector2 = studio.canvas.screen_position_for_record(label_record)
	_check(studio.canvas.begin_edit_drag(label_start), "live canvas hit-tests label for editing")
	studio.canvas.finish_edit_drag(label_start + Vector2(12, -10))
	_check(studio.document.data.labels[0].id == "label1" and studio.document.to_json() != planar_edited, "label drag commits as a separate command with stable ID")
	studio.record_list.item_selected.emit(4)
	studio.curve_inspector.append_cut(0)
	var guarded_source: String = studio.document.to_json()
	var guarded_history_size: int = studio.history.undo_stack.size()
	_check(not studio._request_close() and studio.pending_description == "close Studio", "close waits for explicit discard when recoverable work exists")
	studio._cancel_pending_action()
	_check(studio.document.to_json() == guarded_source and studio.curve_inspector.draft_cuts == [0], "cancelled close leaves accepted record and draft intact")
	studio._open_resource("res://fixtures/multi-curve-v1.json")
	_check(studio.document.to_json() == guarded_source and studio.pending_action.is_valid(), "fixture replacement waits for explicit discard when accepted edits or drafts exist")
	studio._cancel_pending_action()
	_check(studio.document.to_json() == guarded_source and studio.history.undo_stack.size() == guarded_history_size and studio.curve_inspector.draft_cuts == [0], "cancel preserves accepted record, exact history, and rejected draft")
	studio._open_resource("res://fixtures/multi-curve-v1.json")
	studio._discard_and_continue()
	await process_frame
	_check(studio.document.data.curves.size() == 3 and studio.record_list.item_count == 10, "multi-curve fixture opens with every curve in inspector")
	_check(not studio._has_unsaved_work() and not FileAccess.file_exists(WorkspaceRecovery.PATH), "confirmed successful replacement starts a clean workspace and clears old recovery")
	studio.record_list.item_selected.emit(7)
	_check(studio.curve_inspector.visible and studio.curve_inspector.curve_id == "editable", "selected curve opens cut editor by stable ID")
	var multi_before: String = studio.document.to_json()
	var svg_before: String = studio.geometry_result.svg
	var tikz_before: String = studio.geometry_result.tikz
	studio.curve_inspector.append_cut(5)
	studio.curve_inspector._apply()
	_check(studio.document.to_json() == multi_before and not studio.history.can_undo(), "unroutable itinerary preserves accepted recipe and history")
	_check(studio.geometry_result.svg == svg_before and studio.geometry_result.tikz == tikz_before, "rejected route preserves exact publication outputs")
	_check(studio.curve_inspector.draft_cuts == [0, 5] and "rejected" in studio.status_label.text, "rejected cuts remain available with error")
	_check("[draft]" in studio.record_list.get_item_text(7), "inspector marks the stable curve with pending input")
	studio.record_list.item_selected.emit(6)
	studio.curve_inspector.append_cut(1)
	studio.record_list.item_selected.emit(7)
	_check(studio.curve_inspector.draft_cuts == [0, 5], "switching curves recovers rejected draft by stable ID")
	studio._open_result({"ok": false, "error": "malformed file"}, "bad.json")
	_check(studio.curve_inspector.draft_cuts == [0, 5] and studio.document.to_json() == multi_before, "failed open preserves drafts as well as accepted state")
	studio._canvas_edit_commit("label", "caption", Vector2(1, -85))
	_check(studio.curve_inspector.drafts["editable"] == [0, 5] and not studio.curve_inspector.visible, "non-curve command retains hidden curve drafts")
	_check("[draft]" in studio.record_list.get_item_text(7), "draft marker survives non-curve presentation refresh")
	var recovery_on_disk := WorkspaceRecovery.load_file()
	_check(recovery_on_disk.ok and recovery_on_disk.found and recovery_on_disk.drafts.size() == 2, "accepted edit and every curve draft are written to separate bounded recovery")
	var restarted = packed.instantiate()
	root.add_child(restarted)
	await process_frame
	_check(not restarted.startup_recovery.is_empty() and restarted.document.data.title == "Generic planar import fixture", "restart offers recovery without silently replacing the startup fixture")
	_check(restarted._restore_startup_recovery(), "explicit restore accepts the validated recovery envelope")
	_check(restarted.document.to_json() == studio.document.to_json() and restarted.curve_inspector.drafts == studio.curve_inspector.drafts, "restart restores accepted record and all drafts exactly")
	_check(restarted.canvas.selected_record.kind == "label" and restarted.canvas.selected_record.id == "caption", "restart restores stable-ID selection separately from mathematical data")
	_check(restarted.history.undo_stack.size() == studio.history.undo_stack.size() and restarted.history.can_undo(), "restart restores exact command history")
	restarted._undo()
	_check(restarted.document.to_json() == multi_before and restarted.curve_inspector.drafts["editable"] == [0, 5], "recovered undo works without erasing rejected drafts")
	restarted.queue_free()
	await process_frame
	studio._undo()
	studio.record_list.item_selected.emit(7)
	_check(studio.document.to_json() == multi_before and studio.curve_inspector.draft_cuts == [0, 5], "undo of another edit preserves the rejected itinerary")
	studio.canvas.pan = Vector2(11, 17)
	studio.canvas.zoom = 1.1
	studio.curve_inspector._remove_last()
	studio.curve_inspector.append_cut(6)
	studio.curve_inspector._apply()
	var multi_after: String = studio.document.to_json()
	_check(multi_after != multi_before and studio.document.data.curves[1].cuts == [0, 6], "cut apply commits literal ordered itinerary")
	_check(studio.geometry_result.ok and studio.history.undo_stack.size() == 1, "accepted itinerary rendered and stored as one undo command")
	_check(studio.canvas.pan == Vector2(11, 17) and studio.canvas.zoom == 1.1, "itinerary command preserves camera")
	_check(studio.curve_inspector.drafts.has("left") and not studio.curve_inspector.drafts.has("editable"), "apply consumes only its own draft")
	_check("[draft]" in studio.record_list.get_item_text(6) and "[draft]" not in studio.record_list.get_item_text(7), "draft markers refresh after accepted command")
	var svg_after: String = studio.geometry_result.svg
	var tikz_after: String = studio.geometry_result.tikz
	var pick := InputEventMouseButton.new()
	pick.button_index = MOUSE_BUTTON_LEFT
	pick.pressed = true
	pick.position = studio.canvas.screen_position_for_cut(0)
	studio.canvas._gui_input(pick)
	_check(studio.curve_inspector.draft_cuts == [0, 6, 0] and studio.document.to_json() == multi_after, "canvas cut click appends exact visit without changing accepted data")
	studio._save_path("user://ui-multi.json")
	_check("NOT in this file" in studio.status_label.text, "save explains that unapplied drafts are excluded")
	_check(DiagramDocument.load_path("user://ui-multi.json").document.to_json() == multi_after, "saving with a draft writes only exact accepted recipe")
	_check(studio._has_unsaved_work() and WorkspaceRecovery.load_file().found, "saving accepted JSON keeps unapplied drafts recoverable and visibly unsaved")
	studio.curve_inspector._reset()
	studio._undo()
	_check(studio.document.to_json() == multi_before and studio.curve_inspector.draft_cuts == [0], "itinerary UI undo restores accepted recipe and inspector")
	_check(studio.geometry_result.svg == svg_before and studio.geometry_result.tikz == tikz_before, "undo regenerates byte-identical publication outputs")
	studio._redo()
	_check(studio.document.to_json() == multi_after and studio.curve_inspector.draft_cuts == [0, 6], "itinerary UI redo restores accepted recipe and inspector")
	_check(studio.geometry_result.svg == svg_after and studio.geometry_result.tikz == tikz_after, "redo regenerates byte-identical publication outputs")
	studio._open_path("user://ui-multi.json")
	_check(studio.document.to_json() == multi_after and studio.curve_inspector.drafts.is_empty(), "reopen keeps exact recipe with fresh session drafts")
	_check(studio.geometry_result.svg == svg_after and studio.geometry_result.tikz == tikz_after, "save/reopen retains publication output exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui-multi.json"))
	studio._open_resource("res://fixtures/braid-v1.json")
	await process_frame
	_check(studio.document.data.kind == "braid", "braid fixture switches view")
	_check(studio.record_list.item_count == 6, "braid inspector shows summary and five crossings")
	studio.record_list.select(1)
	studio.record_list.item_selected.emit(1)
	_check(studio.canvas.selected_record.kind == "crossing" and studio.canvas.selected_record.index == 0, "braid inspector selects exact crossing index")
	var before: String = studio.document.to_json()
	studio.canvas.zoom_at(Vector2(80, 60), 1.2)
	studio.canvas.pan = Vector2(12, -7)
	_check(studio.document.to_json() == before, "navigation keeps source record exact")
	studio._open_result({"ok": false, "error": "test rejection"}, "bad.json")
	_check(studio.document.to_json() == before, "rejected open retains current document")
	_check("Not opened" in studio.status_label.text, "rejected open is visible")
	studio.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _finish() -> void:
	if failures:
		printerr("UI SMOKE FAILED: %d of %d assertions" % [failures, assertions])
		quit(1)
	else:
		print("UI SMOKE PASS: %d assertions" % assertions)
		quit(0)
