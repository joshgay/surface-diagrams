extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
