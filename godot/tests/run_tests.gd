extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_expect(false, "intentional harness failure")
	else:
		_run_tests()
	if failures:
		printerr("FAILED: %d of %d assertions" % [failures, assertions])
		quit(1)
	else:
		print("PASS: %d assertions" % assertions)
		quit(0)

func _run_tests() -> void:
	var planar := _fixture("res://fixtures/planar-v1.json")
	var multi := _fixture("res://fixtures/multi-curve-v1.json")
	var braid := _fixture("res://fixtures/braid-v1.json")
	if planar == null or multi == null or braid == null: return
	_expect(planar.data.kind == "planar", "planar kind")
	_expect(planar.data.surface.objects.size() == 4, "four planar objects")
	_expect(planar.data.surface.objects[0].id == "p1", "stable object ID")
	_expect(planar.data.curves[0].cuts == [], "exact empty itinerary")
	var leaked := planar.data; leaked.title = "Mutated copy"
	_expect(planar.data.title == "Generic planar import fixture", "external dictionary mutation cannot change record")
	_expect(planar.data.style.marked_point_color == "#006fff", "blue marks")
	_expect(planar.data.style.boundary_color == "#8b8b8b", "gray boundaries")
	_expect(planar.data.curves[0].color == "#ff00d4", "magenta curve default")
	_expect(not planar.data.allow_intersections, "intersections remain explicit")
	_expect(multi.data.surface.objects.size() == 6 and multi.data.curves.size() == 3, "multi-curve fixture has six stable points and three curves")
	_expect(multi.data.curves[1].id == "editable" and multi.data.curves[1].cuts == [0], "multi-curve fixture keeps initial exact itinerary")
	_expect(braid.data.braid.word == [1, -2, 3, -4, 5], "braid word order and signs preserved")
	_expect(braid.data.braid.direction == "bottom-to-top", "braid direction preserved")
	var braid_rows := braid.summary_rows()
	_expect("entry [1, 2, 3, 4, 5, 6]  exit [2, 1, 3, 4, 5, 6]" in braid_rows[1], "first strand transport")
	var planar_records := planar.inspector_records()
	_expect(planar_records[0].kind == "object" and planar_records[0].id == "p1", "inspector maps row to stable object ID")
	_expect(planar_records[4].kind == "curve" and planar_records[4].id == "arc1", "inspector maps row to stable curve ID")
	var braid_records := braid.inspector_records()
	_expect(braid_records[1].kind == "crossing" and braid_records[1].index == 0, "inspector maps row to exact crossing index")
	var round_trip := DiagramDocument.parse(planar.to_json())
	_expect(round_trip.ok, "normalized JSON reopens")
	if round_trip.ok:
		_expect(round_trip.document.data == planar.data, "round trip is lossless")
		var camera_state := {"zoom": 2.0, "pan": Vector2(30, -10)}
		_expect(round_trip.document.data == planar.data and camera_state.zoom == 2.0, "camera state is separate")
	var save_path := "user://round-trip.json"
	_expect(planar.save_path(save_path).is_empty(), "save succeeds")
	var reopened := DiagramDocument.load_path(save_path)
	_expect(reopened.ok and reopened.document.data == planar.data, "saved recipe reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_reject("{", "malformed JSON")
	_reject("[]", "non-object document")
	_reject('{"format":"surface-diagrams","version":1,"version":1,"kind":"planar","surface":{"width":20,"height":20,"objects":[]}}', "duplicate JSON field")
	_reject('{"format":"surface-diagrams","version":1,"\\u0076ersion":1,"kind":"planar","surface":{"width":20,"height":20,"objects":[]}}', "escaped duplicate JSON field")
	var future := planar.to_dict(); future.version = 2
	_reject(JSON.stringify(future), "future version")
	var unknown := planar.to_dict(); unknown.future_field = 3
	_reject(JSON.stringify(unknown), "unknown field")
	var duplicate_id := planar.to_dict(); duplicate_id.surface.objects[1].id = "p1"
	_reject(JSON.stringify(duplicate_id), "duplicate object ID")
	var reordered := planar.to_dict(); reordered.surface.objects[1].x = -130
	_reject(JSON.stringify(reordered), "object reordering")
	var outside := planar.to_dict(); outside.surface.objects[0].x = -200
	_reject(JSON.stringify(outside), "object on outer ellipse")
	var nonminimal := planar.to_dict(); nonminimal.curves[0].cuts = [2, 2]
	_reject(JSON.stringify(nonminimal), "nonminimal itinerary")
	var same_endpoint := planar.to_dict(); same_endpoint.curves[0].end = same_endpoint.curves[0].start
	_reject(JSON.stringify(same_endpoint), "arc with equal endpoints")
	var adjacent_cut := planar.to_dict(); adjacent_cut.curves[0].cuts = [0]
	_reject(JSON.stringify(adjacent_cut), "terminal cut adjacent to endpoint")
	var bad_loop := planar.to_dict(); bad_loop.curves = [{"id": "loop1", "kind": "loop", "cuts": [0]}]
	_reject(JSON.stringify(bad_loop), "odd loop itinerary")
	var bad_generator := braid.to_dict(); bad_generator.braid.word = [6]
	_reject(JSON.stringify(bad_generator), "out-of-range braid generator")
	var identity_braid := braid.to_dict(); identity_braid.braid.word = []
	var identity_result := DiagramDocument.parse(JSON.stringify(identity_braid))
	_expect(identity_result.ok and identity_result.document.data.braid.word.is_empty(), "empty braid word is retained")
	var executable := planar.to_dict(); executable.script = "res://evil.gd"
	_reject(JSON.stringify(executable), "imported script field")
	var huge := " ".repeat(DiagramDocument.MAX_BYTES) + "{}"
	var huge_result := DiagramDocument.parse(huge)
	_expect(not huge_result.ok, "oversized document")
	var canvas := DiagramCanvas.new()
	canvas.document = planar
	var before := planar.to_json()
	canvas.zoom_at(Vector2(100, 100), 1.5)
	canvas.pan = Vector2(20, 30)
	_expect(planar.to_json() == before, "canvas navigation does not mutate records")
	canvas.select_record(planar_records[4])
	_expect(canvas.selected_record.id == "arc1" and planar.to_json() == before, "selection is separate from records")
	canvas.free()
	var planar_geometry := PythonGeometryBridge.render(planar)
	_expect(planar_geometry.ok and planar_geometry.svg.begins_with("<svg"), "Python bridge renders planar SVG")
	_expect(planar_geometry.ok and "tikzpicture" in planar_geometry.tikz, "Python bridge renders planar TikZ")
	var planar_image := Image.new()
	var planar_svg_error := planar_image.load_svg_from_buffer(planar_geometry.svg.to_utf8_buffer()) if planar_geometry.ok else FAILED
	_expect(planar_svg_error == OK and planar_image.get_width() > 0 and planar_image.get_height() > 0, "Godot decodes exact planar SVG")
	var braid_geometry := PythonGeometryBridge.render(braid)
	_expect(braid_geometry.ok and braid_geometry.manifest.kind == "braid", "Python bridge renders braid through fixed adapter")
	var braid_image := Image.new()
	var braid_svg_error := braid_image.load_svg_from_buffer(braid_geometry.svg.to_utf8_buffer()) if braid_geometry.ok else FAILED
	_expect(braid_svg_error == OK and braid_image.get_width() > 0 and braid_image.get_height() > 0, "Godot decodes exact braid SVG")
	_expect(planar.to_json() == before, "geometry bridge does not mutate records")
	var multi_geometry := PythonGeometryBridge.render(multi)
	_expect(multi_geometry.ok and multi_geometry.svg.begins_with("<svg"), "Python bridge accepts multi-curve fixture")
	var original_python := OS.get_environment("SURFACE_DIAGRAMS_PYTHON")
	OS.set_environment("SURFACE_DIAGRAMS_PYTHON", "/definitely-missing-surface-diagrams-python")
	var unavailable_geometry := PythonGeometryBridge.render(planar)
	OS.set_environment("SURFACE_DIAGRAMS_PYTHON", original_python)
	_expect(not unavailable_geometry.ok and unavailable_geometry.svg.is_empty(), "missing Python stays an explicit unavailable state")
	var history := DiagramEditHistory.new()
	history.set_document(planar)
	var original_source := planar.to_json()
	var moved := history.move_object("p2", -20.0)
	_expect(moved.ok and moved.document.data.surface.objects[1].x == -20.0, "history accepts a point move between neighbors")
	_expect(moved.document.data.surface.objects[1].id == "p2" and moved.document.data.curves[0].cuts == planar.data.curves[0].cuts, "point move preserves IDs and exact cut itinerary")
	var moved_source: String = history.current.to_json()
	var rejected_move := history.move_object("p2", 50.0)
	_expect(not rejected_move.ok and history.current.to_json() == moved_source, "point cannot pass its right neighbor")
	var rejected_geometry := history.move_object("p2", -25.0, func(_candidate): return {"ok": false, "error": "test geometry rejection"})
	_expect(not rejected_geometry.ok and history.current.to_json() == moved_source and history.undo_stack.size() == 1, "geometry rejection preserves accepted document and history")
	var undone := history.undo()
	_expect(undone.ok and undone.document.to_json() == original_source and history.can_redo(), "undo restores exact prior recipe")
	var redone := history.redo()
	_expect(redone.ok and redone.document.to_json() == moved_source and history.can_undo(), "redo restores exact accepted recipe")
	var label_move := history.move_label("label1", Vector2(15, -55))
	_expect(label_move.ok and label_move.document.data.labels[0].x == 15.0 and label_move.document.data.labels[0].y == -55.0, "label move is command based")
	var label_source: String = history.current.to_json()
	history.undo()
	var replacement_move := history.move_object("p2", -30.0)
	_expect(replacement_move.ok and not history.can_redo(), "a new edit clears redo history")
	history.undo()
	history.redo()
	var history_path := "user://edited-round-trip.json"
	_expect(history.current.save_path(history_path).is_empty(), "edited recipe saves")
	var edited_reopen := DiagramDocument.load_path(history_path)
	_expect(edited_reopen.ok and edited_reopen.document.to_json() == history.current.to_json(), "edited recipe reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(history_path))
	_expect(label_source != history.current.to_json(), "separate point and label commands retain distinct exact states")
	var edit_canvas := DiagramCanvas.new()
	edit_canvas.size = Vector2(800, 500)
	edit_canvas.set_document(planar)
	var object_record: Dictionary = planar.inspector_records()[1]
	var object_screen := edit_canvas.screen_position_for_record(object_record)
	_expect(edit_canvas.begin_edit_drag(object_screen), "canvas begins point drag from hit-tested record")
	var preview := edit_canvas.update_edit_drag(object_screen + Vector2(20, 0))
	_expect(preview.ok and edit_canvas.preview_record.id == "p2" and planar.to_json() == original_source, "drag preview is separate from accepted record")
	var right_neighbor_screen := edit_canvas.screen_position_for_record(planar.inspector_records()[2])
	preview = edit_canvas.update_edit_drag(right_neighbor_screen + Vector2(5, 0))
	_expect(not preview.ok and "strictly between" in preview.error and planar.to_json() == original_source, "invalid drag preview cannot reorder objects")
	edit_canvas.cancel_edit_preview()
	_expect(not edit_canvas.edit_dragging and edit_canvas.preview_record.is_empty(), "cancel clears draft without changing record")
	edit_canvas.free()
	var multi_source := multi.to_json()
	var itinerary_proposal := multi.with_curve_cuts("editable", [0, 6])
	_expect(itinerary_proposal.ok and itinerary_proposal.document.data.curves[1].cuts == [0, 6], "curve proposal preserves exact ordered cut visits")
	_expect(multi.to_json() == multi_source, "curve proposal does not mutate accepted document")
	var repeated_visit := multi.with_curve_cuts("editable", [0, 0])
	_expect(not repeated_visit.ok and "nonminimal" in repeated_visit.error, "consecutive repeated cut draft is rejected without simplification")
	var invalid_visit := multi.with_curve_cuts("editable", [0, "6"])
	_expect(not invalid_visit.ok, "noninteger cut draft is rejected")
	_expect(not multi.with_curve_cuts("missing", [0, 6]).ok and not braid.with_curve_cuts("editable", [0, 6]).ok, "unknown curve and braid edits are rejected")
	_expect(not multi.with_curve_cuts("editable", [0, 7]).ok, "out-of-range cut is rejected")
	var proposed_data: Dictionary = itinerary_proposal.document.to_dict()
	proposed_data.curves[1].cuts = [0]
	_expect(proposed_data == multi.to_dict(), "changing cuts preserves every other field including sibling curves")
	var loop_data := multi.to_dict()
	loop_data.curves = [{"id": "loopA", "kind": "loop", "cuts": [0, 6], "start_up": false}]
	var loop_document := DiagramDocument.parse(JSON.stringify(loop_data))
	var loop_edit: Dictionary = loop_document.document.with_curve_cuts("loopA", [0, 5])
	_expect(loop_edit.ok and loop_edit.document.data.curves[0].start_up == false, "loop itinerary editor preserves orientation")
	_expect(not loop_document.document.with_curve_cuts("loopA", [0, 5, 1]).ok, "odd loop draft is rejected without dropping a cut")
	_expect(not loop_document.document.with_curve_cuts("loopA", [0, 5, 1, 0]).ok, "cyclic cancellation in loop draft is rejected without simplification")
	var curve_history := DiagramEditHistory.new()
	curve_history.set_document(multi)
	var route_rejection := curve_history.set_curve_cuts("editable", [0, 5], PythonGeometryBridge.render)
	_expect(not route_rejection.ok and curve_history.current.to_json() == multi_source and not curve_history.can_undo(), "Python routing rejection preserves curve record and history")
	var itinerary_edit := curve_history.set_curve_cuts("editable", [0, 6], PythonGeometryBridge.render)
	_expect(itinerary_edit.ok and itinerary_edit.document.data.curves[1].cuts == [0, 6], "geometry-accepted itinerary becomes one command")
	var itinerary_source: String = curve_history.current.to_json()
	_expect(curve_history.undo().document.to_json() == multi_source, "curve undo restores exact initial itinerary")
	_expect(curve_history.redo().document.to_json() == itinerary_source, "curve redo restores exact accepted itinerary")
	var multi_path := "user://multi-curve-edited.json"
	_expect(curve_history.current.save_path(multi_path).is_empty(), "edited multi-curve recipe saves")
	var multi_reopen := DiagramDocument.load_path(multi_path)
	_expect(multi_reopen.ok and multi_reopen.document.to_json() == itinerary_source and PythonGeometryBridge.render(multi_reopen.document).ok, "edited multi-curve recipe reopens with exact publication geometry")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(multi_path))
	var inspector := CurveInspector.new()
	var editable_record: Dictionary = multi.inspector_records()[7]
	inspector.inspect(multi, editable_record)
	_expect(inspector.visible and inspector.curve_id == "editable" and inspector.draft_cuts == [0], "curve inspector exposes selected stable curve and accepted cuts")
	inspector.append_cut(6)
	inspector.append_cut(0)
	_expect(inspector.draft_cuts == [0, 6, 0], "curve inspector preserves ordered and repeated picks")
	inspector.append_cut(0)
	_expect("nonminimal" in inspector.warning_label.text and inspector.draft_cuts == [0, 6, 0, 0], "curve inspector warns without silently altering invalid draft")
	inspector.inspect(multi, multi.inspector_records()[6])
	inspector.inspect(multi, editable_record)
	_expect(inspector.draft_cuts == [0, 6, 0, 0], "draft survives selection changes")
	inspector.inspect(multi, multi.inspector_records()[0])
	_expect(not inspector.visible, "non-curve hides editor without deleting drafts")
	inspector.inspect(multi, editable_record)
	for i in 70:
		inspector.append_cut(i % 2)
	_expect(inspector.draft_cuts.size() == 64 and "limit" in inspector.warning_label.text, "interactive draft is bounded without trimming earlier visits")
	inspector._reset()
	_expect(inspector.draft_cuts == [0] and not inspector.drafts.has("editable"), "reset explicitly discards only selected curve draft")
	inspector.free()
	var cut_canvas := DiagramCanvas.new()
	cut_canvas.size = Vector2(900, 520)
	cut_canvas.set_document(multi)
	cut_canvas.select_record(editable_record)
	var cut_screen := cut_canvas.screen_position_for_cut(6)
	_expect(cut_canvas._hit_cut(cut_screen) == 6, "canvas hit-tests numbered cut exactly")
	_expect(cut_canvas._hit_cut(cut_screen + Vector2(0, 35)) == 6, "numbered cut label is also clickable")
	cut_canvas.zoom = 0.25
	var crowded_left := cut_canvas.screen_position_for_cut(1)
	var crowded_right := cut_canvas.screen_position_for_cut(2)
	_expect(cut_canvas._hit_cut(crowded_right) == 2, "crowded cut picking chooses nearest not first index")
	_expect(cut_canvas._hit_cut((crowded_left + crowded_right) / 2.0) == -1, "equidistant ambiguous cut pick is ignored")
	cut_canvas.zoom = 1.0
	var picked: Array[int] = []
	cut_canvas.cut_picked.connect(func(cut): picked.append(cut))
	var cut_event := InputEventMouseButton.new()
	cut_event.button_index = MOUSE_BUTTON_LEFT
	cut_event.pressed = true
	cut_event.position = cut_screen
	cut_canvas._gui_input(cut_event)
	_expect(picked == [6], "canvas emits cut picks in click order")
	cut_canvas.free()
	var scene := load("res://scenes/studio.tscn")
	_expect(scene is PackedScene, "main scene loads")
	if scene is PackedScene:
		var instance: Node = scene.instantiate()
		_expect(instance != null, "main scene instantiates")
		instance.free()

func _fixture(path: String) -> DiagramDocument:
	var result := DiagramDocument.load_path(path)
	_expect(result.ok, path + " parses: " + result.get("error", ""))
	return result.document if result.ok else null

func _reject(text: String, label: String) -> void:
	var result := DiagramDocument.parse(text)
	_expect(not result.ok, label + " rejected")

func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
