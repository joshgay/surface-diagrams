extends SceneTree

var assertions := 0
var failures := 0
const FIXTURE := "res://fixtures/walkthroughs/point-and-label-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var source := FileAccess.get_file_as_string(FIXTURE)
	var parsed := WalkthroughDocument.parse(source)
	_check(parsed.ok, "generic supplied walkthrough parses")
	if not parsed.ok:
		quit(1)
		return
	var document: WalkthroughDocument = parsed.document
	var normalized := document.to_json()
	_check(WalkthroughDocument.parse(normalized).document.to_json() == normalized, "normalized walkthrough save/reopen is exact")
	var copied := document.to_dict()
	copied.steps[0].selected[0].id = "changed"
	copied.documents.initial.surface.objects[0].id = "changed"
	_check(document.to_json() == normalized, "walkthrough returns defensive copies")
	_check(document.to_dict().steps.map(func(step): return step.id) == ["place-point", "place-caption"], "supplied step order remains literal")
	_check(document.step(0).before == "initial" and document.step(0).after == "point_moved" and document.step(1).before == "point_moved" and document.final_state() == "label_moved", "complete references form an explicit chain")
	_check(document.step(-1).is_empty() and document.step(2).is_empty() and document.diagram("missing") == null, "out-of-range references do not invent states")
	_check(document.diagram("initial").data.surface.objects.map(func(object): return object.id) == ["p1", "p2", "p3", "p4"], "ordered stable object IDs are preserved")
	_check(document.diagram("initial").data.curves[0].id == "arc1" and document.diagram("label_moved").data.labels[0].id == "caption", "stable curve and label IDs survive every state")
	_check(document.diagram("initial").data.style.marked_point_color == "#006fff" and document.diagram("initial").data.style.boundary_color == "#8b8b8b" and document.diagram("initial").data.curves[0].color == "#ff00d4", "thesis colors remain normalized")
	_check(document.step(0).verification.status == "unverified" and document.step(0).provenance.kind == "original-generic-example", "verification and provenance remain explicit metadata")
	for invalid in ["{}", "[]", source + "x", source.replace('"version": 1,', '"version": 1, "version": 1,'), " ".repeat(256 * 1024 + 1)]:
		_check(not WalkthroughDocument.parse(invalid).ok, "malformed, duplicate or oversized walkthrough rejected")
	for mutation in ["version", "format", "unknown", "script", "braid", "missing_initial", "unknown_initial", "object_order", "object_kind", "curve_id", "label_id", "empty_steps", "too_many_steps", "step_id", "step_name", "operation", "before", "after", "chain", "selection_empty", "selection_kind", "selection_id", "selection_duplicate", "selection_unknown", "provenance_kind", "provenance_field", "verification_status", "verification_field"]:
		var raw: Dictionary = JSON.parse_string(source)
		match mutation:
			"version": raw.version = 2
			"format": raw.format = "surface-diagrams"
			"unknown": raw.camera = {"zoom": 2}
			"script": raw.script = "res://scripts/studio.gd"
			"braid": raw.documents.initial = {"format": "surface-diagrams", "version": 1, "kind": "braid", "braid": {"strands": 2, "word": []}}
			"missing_initial": raw.erase("initial_state")
			"unknown_initial": raw.initial_state = "missing"
			"object_order": raw.documents.point_moved.surface.objects.reverse()
			"object_kind": raw.documents.point_moved.surface.objects[0].kind = "boundary"
			"curve_id": raw.documents.point_moved.curves[0].id = "other"
			"label_id": raw.documents.label_moved.labels[0].id = "other"
			"empty_steps": raw.steps = []
			"too_many_steps":
				var template: Dictionary = raw.steps[0].duplicate(true)
				raw.steps = []
				for index in 65:
					var step := template.duplicate(true)
					step.id = "step%d" % index
					step.before = "initial" if index == 0 else "point_moved"
					step.after = "point_moved"
					raw.steps.append(step)
			"step_id": raw.steps[1].id = raw.steps[0].id
			"step_name": raw.steps[0].name = ["not text"]
			"operation": raw.steps[0].operation = "x".repeat(121)
			"before": raw.steps[0].before = "missing"
			"after": raw.steps[0].after = "missing"
			"chain": raw.steps[1].before = "initial"
			"selection_empty": raw.steps[0].selected = []
			"selection_kind": raw.steps[0].selected[0].kind = "crossing"
			"selection_id": raw.steps[0].selected[0].id = "absent"
			"selection_duplicate": raw.steps[0].selected.append(raw.steps[0].selected[0].duplicate(true))
			"selection_unknown": raw.steps[0].selected[0].index = 0
			"provenance_kind": raw.steps[0].provenance.kind = "invented"
			"provenance_field": raw.steps[0].provenance.script = "res://scripts/studio.gd"
			"verification_status": raw.steps[0].verification.status = "proved"
			"verification_field": raw.steps[0].verification.resource = "res://scenes/studio.tscn"
		_check(not WalkthroughDocument.parse(JSON.stringify(raw)).ok, "reject invalid " + mutation)
	var start := WalkthroughTimeline.sample(document, 0.0)
	_check(start.ok and start.step_index == 0 and start.local == 0.0 and start.current_reference == "initial", "timeline begins at first complete before-state")
	var middle := WalkthroughTimeline.sample(document, 0.5)
	_check(middle.step_index == 0 and middle.local == 0.5 and middle.before.to_json() == document.diagram("initial").to_json() and middle.after.to_json() == document.diagram("point_moved").to_json(), "fraction retains both complete supplied endpoints")
	var boundary := WalkthroughTimeline.sample(document, 1.0)
	_check(boundary.step_index == 1 and boundary.local == 0.0 and boundary.current_reference == "point_moved", "step boundary uses the shared explicit state")
	var end := WalkthroughTimeline.sample(document, 2.0)
	_check(end.step_index == 1 and end.local == 1.0 and end.current_reference == "label_moved", "timeline ends at final complete after-state")
	_check(WalkthroughTimeline.sample(document, -10.0).position == 0.0 and WalkthroughTimeline.sample(document, 99.0).position == 2.0, "scrub position is bounded without changing records")
	_check(not WalkthroughTimeline.sample(document, INF).ok and not WalkthroughTimeline.sample(null, 0.0).ok, "invalid sample inputs fail explicitly")
	_check(WalkthroughTimeline.advance(document, 0.25, 0.5, 1) == 0.75 and WalkthroughTimeline.advance(document, 0.75, 0.5, -1) == 0.25, "forward and reverse advance share one scalar timeline")
	var partitioned := 0.0
	for delta in [0.13, 0.07, 0.2, 0.1]: partitioned = WalkthroughTimeline.advance(document, partitioned, delta, 1)
	_check(is_equal_approx(partitioned, WalkthroughTimeline.advance(document, 0.0, 0.5, 1)), "unequal frame partitions produce deterministic playback")
	_check(WalkthroughTimeline.advance(document, 0.5, -1.0, 1) == 0.5 and WalkthroughTimeline.advance(document, 0.5, NAN, 1) == 0.5 and WalkthroughTimeline.advance(document, 0.5, 1.0, 0) == 0.5, "invalid elapsed time or direction cannot move playback")
	_check(document.save_path("user://walkthrough-test.json").is_empty() and FileAccess.get_file_as_string("user://walkthrough-test.json") == normalized, "save writes the exact normalized walkthrough")
	_check(WalkthroughDocument.parse(FileAccess.get_file_as_string("user://walkthrough-test.json")).document.to_json() == normalized, "saved walkthrough reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough-test.json"))
	var view := WalkthroughView.new()
	root.add_child(view)
	await process_frame
	_check(view.import_source(source) and view.step_index == 0 and view.timeline_position == 0.0, "live walkthrough workspace imports generic fixture")
	_check(view.before_canvas.document.to_json() == document.diagram("initial").to_json() and view.after_canvas.document.to_json() == document.diagram("point_moved").to_json(), "viewer displays both complete supplied endpoints")
	_check(view.before_canvas.selected_record.id == "p2" and view.after_canvas.selected_record.id == "p2" and view.selected_list.item_count == 1, "declared stable selection links both endpoints")
	_check("unverified" in view.verification.text and "does not validate" in view.verification.text, "verification status is visible without promotion")
	view.set_timeline_position(0.5)
	_check(view.step_index == 0 and is_equal_approx(view.before_canvas.modulate.a, 0.675) and is_equal_approx(view.after_canvas.modulate.a, 0.675), "fractional playback is an endpoint crossfade only")
	_check(document.to_json() == normalized and view.document.to_json() == normalized, "scrubbing leaves mathematical records byte-identical")
	view._next()
	_check(view.step_index == 1 and view.timeline_position == 1.0 and view.before_canvas.document.to_json() == document.diagram("point_moved").to_json() and view.before_canvas.selected_record.id == "caption", "next boundary selects the next supplied step and stable label")
	view.set_play_direction(-1)
	view.set_timeline_position(2.0)
	view.toggle_play()
	view.advance(0.75)
	_check(view.playing and is_equal_approx(view.timeline_position, 1.5) and view.play_direction == -1, "reverse playback moves through the same deterministic step")
	view.advance(2.25)
	_check(not view.playing and view.timeline_position == 0.0 and view.step_index == 0, "reverse playback stops exactly at the initial endpoint")
	view.toggle_play()
	_check(view.playing and view.timeline_position == 2.0, "reverse play from start wraps explicitly to the final endpoint")
	view._stop_playback()
	view.set_play_direction(1)
	view.set_timeline_position(2.0)
	view.toggle_play()
	_check(view.playing and view.timeline_position == 0.0, "forward play from end wraps explicitly to the first endpoint")
	view.advance(3.0)
	_check(not view.playing and view.timeline_position == 2.0, "forward playback stops exactly at the final endpoint")
	view._record_selected({"kind": "curve", "id": "arc1"})
	_check(view.before_canvas.selected_record.id == "arc1" and view.after_canvas.selected_record.id == "arc1", "manual inspection links a stable record across both endpoints")
	var accepted_position: float = view.timeline_position
	_check(not view.import_source("{}") and view.document.to_json() == normalized and view.timeline_position == accepted_position, "failed import preserves accepted walkthrough and timeline")
	_check(view.save_path("user://walkthrough-view-test.json") and FileAccess.get_file_as_string("user://walkthrough-view-test.json") == normalized, "viewer save preserves exact record")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough-view-test.json"))
	for viewport in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport
		root.content_scale_size = viewport
		for frame in 4: await process_frame
		_check(view.grid.columns == (1 if viewport.x < 900 else 2), "walkthrough adapts columns at %s" % viewport)
		_check(view.grid.get_global_rect().end.x <= viewport.x + 1, "walkthrough endpoints do not overflow horizontally at %s" % viewport)
		if viewport.x < 900:
			_check(view.view_tabs.visible and view.endpoint_columns.filter(func(column): return column.visible).size() == 1, "compact walkthrough shows one selectable endpoint at %s" % viewport)
			_check(view.view_tabs.get_global_rect().end.x <= viewport.x + 1 and view.view_tab_buttons.slice(0, 2).all(func(button): return button.custom_minimum_size.y >= 44), "compact walkthrough switcher fits and retains touch targets at %s" % viewport)
			var preserved := view.document.to_json()
			_check(view.show_compact_view("after") and view.after_canvas.is_visible_in_tree() and not view.before_canvas.is_visible_in_tree(), "compact walkthrough tabs reveal the complete after-state without stacked endpoints at %s" % viewport)
			_check(view.document.to_json() == preserved and view.step_index == 1 and not view.show_compact_view("cover-before"), "compact endpoint switching preserves records and refuses absent cover views")
			view.show_compact_view("before")
		else:
			_check(not view.view_tabs.visible and view.endpoint_columns.all(func(column): return column.visible), "desktop walkthrough keeps both complete endpoints visible")
	view.queue_free()
	await process_frame
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	studio.browser_drafts.button_pressed = true
	studio._canvas_edit_commit("object", "p1", Vector2(-118, 0))
	var editor_source: String = studio.document.to_json()
	studio._show_walkthrough()
	await process_frame
	_check(studio.walkthrough_view.visible and not studio.workspace_root.visible and studio.walkthrough_view.document != null, "main Studio opens supplied walkthrough workspace")
	var undo_event := InputEventKey.new()
	undo_event.pressed = true
	undo_event.ctrl_pressed = true
	undo_event.keycode = KEY_Z
	studio._unhandled_key_input(undo_event)
	_check(studio.history.undo_stack.size() == 1 and studio.document.to_json() == editor_source, "walkthrough shortcuts cannot undo hidden editor work")
	studio.walkthrough_view.toggle_play()
	studio.walkthrough_view.closed.emit()
	_check(studio.workspace_root.visible and not studio.walkthrough_view.visible and not studio.walkthrough_view.playing and studio.document.to_json() == editor_source, "return stops walkthrough and preserves unsaved editor state")
	_check(studio.walkthrough_view.document.to_json() == normalized, "all walkthrough interaction leaves its supplied record byte-identical")
	studio.queue_free()
	await process_frame
	print("WALKTHROUGH: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
