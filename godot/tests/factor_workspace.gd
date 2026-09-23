extends SceneTree

var failures := 0
var assertions := 0
const FIXTURE := "res://fixtures/workspaces/grouped-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var source := FileAccess.get_file_as_string(FIXTURE)
	var parsed := FactorWorkspace.parse(source)
	_check(parsed.ok, "generic factor fixture parses")
	if not parsed.ok:
		quit(1)
		return
	var workspace: FactorWorkspace = parsed.workspace
	var original := workspace.to_json()
	_check(FactorWorkspace.parse(original).workspace.to_json() == original, "normalized workspace round trip exact")
	var copied := workspace.to_dict()
	copied.factors[0].id = "changed"
	_check(workspace.to_json() == original, "defensive copies preserve literal factor IDs")
	_check(workspace.braid_document().data.braid.word == [1, -2, 1, -1], "no exponent expansion or adjacent inverse cancellation")
	_check(workspace.focus(0).entry_ids == [1, 2, 3] and workspace.focus(0).exit_ids == [2, 1, 3], "first factor transports IDs")
	_check(workspace.focus(1).start == 1 and workspace.focus(1).end == 1 and workspace.focus(1).entry_ids == workspace.focus(1).exit_ids, "empty block retains prefix and transported IDs")
	_check(workspace.focus(2).entry_ids == [2, 1, 3] and workspace.focus(2).exit_ids == [2, 3, 1], "later block continues identities rather than resetting")
	_check(workspace.factor_for_crossing(0) == 0 and workspace.factor_for_crossing(1) == 2 and workspace.factor_for_crossing(3) == 2 and workspace.factor_for_crossing(4) == -1, "crossing maps to literal factor; empty block consumes none")
	_check(workspace.focus(-1).is_empty() and workspace.focus(3).is_empty(), "out-of-range focus rejected")
	_check(workspace.complete_states(), "all generic storyboard states supplied")
	var at_half := FactorTimeline.sample(workspace, 0.5, "bottom-to-top")
	_check(at_half.ok and at_half.factor_index == 0 and is_equal_approx(at_half.braid_time, 0.5) and at_half.braid.crossings[0].fraction == 0.5, "factor timeline fractionally reveals first supplied block")
	var empty_half := FactorTimeline.sample(workspace, 1.5, "bottom-to-top")
	_check(empty_half.factor_index == 1 and empty_half.focus.start == empty_half.focus.end and empty_half.braid_time == 1.0 and empty_half.braid.paths == FactorTimeline.sample(workspace, 1.9).braid.paths, "empty factor owns a timed stage without moving strands")
	var tall_half := FactorTimeline.sample(workspace, 2.5, "bottom-to-top")
	_check(tall_half.factor_index == 2 and is_equal_approx(tall_half.braid_time, 2.5) and tall_half.braid.crossings.size() == 3, "multi-crossing block maps local fraction to its literal crossing interval")
	var reversed := FactorTimeline.sample(workspace, 2.5, "top-to-bottom")
	_check(reversed.factor_index == tall_half.factor_index and reversed.braid_time == tall_half.braid_time and reversed.braid.direction == "top-to-bottom", "presentation direction does not reverse factor or word time")
	_check(FactorTimeline.sample(workspace, INF).ok == false and FactorTimeline.sample(null, 0).ok == false, "nonfinite time and missing workspace rejected")
	_check(FactorTimeline.advance(workspace, 0.0, 0.3) == 0.5 and FactorTimeline.advance(workspace, 0.0, 1.2) == 2.0, "advance accounts for nonempty and explicit empty stage durations")
	var partitioned := 0.0
	for delta in [0.07, 0.13, 0.31, 0.49, 0.2]: partitioned = FactorTimeline.advance(workspace, partitioned, delta)
	_check(is_equal_approx(partitioned, FactorTimeline.advance(workspace, 0.0, 1.2)), "unequal frame partitions reach same factor boundary")
	_check(FactorTimeline.advance(workspace, 0.4, -1.0) == 0.4 and FactorTimeline.advance(workspace, 0.4, NAN) == 0.4, "invalid elapsed time cannot change view state")
	for invalid in ["{}", "[]", source.replace('"version": 1', '"version": 99'), source.replace('"version": 1,', '"version": 1, "version": 1,'), source + "x", " ".repeat(256 * 1024 + 1)]:
		_check(not FactorWorkspace.parse(invalid).ok, "reject invalid syntax/version/duplicate/oversize")
	for mutation in ["id", "exponent", "group", "support", "braid_word", "after", "strands", "documents", "initial_state", "unknown", "too_many", "word_limit", "script"]:
		var raw: Dictionary = JSON.parse_string(source)
		match mutation:
			"id": raw.factors[1].id = "a"
			"exponent": raw.factors[0].exponent = true
			"group": raw.factors[1].group = "other"; raw.factors[2].group = "First block"
			"support": raw.factors[0].support = "missing"
			"braid_word": raw.factors[0].braid_word = [3]
			"after": raw.factors[0].after = 123
			"strands": raw.strands = 33
			"documents": raw.documents.leftArc.surface.objects.reverse()
			"initial_state": raw.initial_state = "absent"
			"unknown": raw.path = "res://scripts/studio.gd"
			"too_many": raw.factors.resize(17)
			"word_limit": raw.factors[0].braid_word = range(129)
			"script": raw.documents.leftArc.script = "res://scripts/studio.gd"
		_check(not FactorWorkspace.parse(JSON.stringify(raw)).ok, "reject invalid " + mutation)
	var partial := workspace.to_dict()
	partial.factors[0].after = null
	var partial_workspace: FactorWorkspace = FactorWorkspace.parse(JSON.stringify(partial)).workspace
	_check(not partial_workspace.complete_states() and partial_workspace.focus(1).before == null, "missing prior state is not carried forward from initial state")
	var missing_export := PythonGeometryBridge.render(partial_workspace)
	_check(not missing_export.ok and "Incomplete supplied states" in missing_export.error, "partial states fail exact export explicitly")
	var first := PythonGeometryBridge.render(workspace)
	var second := PythonGeometryBridge.render(FactorWorkspace.parse(original).workspace)
	_check(first.ok and second.ok and first.svg == second.svg and first.tikz == second.tikz, "workspace save/reopen produces deterministic Python exports")
	_check("Supplied left arc" in first.svg and "Supplied left arc" in first.tikz, "adapter preserves nested document labels")
	var view := FactorWorkspaceView.new()
	root.add_child(view)
	await process_frame
	_check(view.import_source(source) and view.factor_index == 0 and not view.export_svg.disabled, "live desktop viewer imports and enables validated export")
	view.set_timeline_position(0.5)
	_check(view.factor_index == 0 and is_equal_approx(view.timeline_position, 0.5) and is_equal_approx(view.braid_canvas.braid_playhead, 0.5) and "50.0%" in view.timeline_label.text, "scrub synchronizes factor, details and fractional braid")
	view.toggle_play()
	view.advance(0.3)
	_check(view.factor_index == 1 and view.timeline_position == 1.0 and view.playing, "playback reaches empty factor as an explicit selected stage")
	view.advance(0.3)
	_check(view.factor_index == 1 and is_equal_approx(view.timeline_position, 1.5) and view.braid_canvas.braid_playhead == 1.0 and view.braid_canvas.selected_record.is_empty(), "empty factor consumes playback time without crossing selection")
	view.set_direction("top-to-bottom")
	_check(view.direction == "top-to-bottom" and view.factor_index == 1 and view.timeline_position == 1.5 and view.braid_canvas.braid_presentation == "top-to-bottom", "direction change preserves common factor position")
	view._next()
	_check(view.factor_index == 2 and view.timeline_position == 2.0 and not view.playing, "next selects exact next factor boundary and pauses")
	view._previous()
	_check(view.factor_index == 1 and view.timeline_position == 1.0, "previous selects exact prior factor")
	view.select_factor(1)
	_check(view.braid_canvas.selected_record.is_empty() and "empty block" in view.details.text, "empty block visibly selected without synthetic crossing")
	view._crossing_selected({"kind": "crossing", "index": 3})
	_check(view.factor_index == 2 and view.selector.selected == 2 and view.braid_canvas.selected_record.index == 3, "braid picking synchronizes factor selection")
	_check(view.support_canvas.document.to_json() == workspace.diagram("rightArc").to_json() and view.after_canvas.document.to_json() == workspace.diagram("leftArc").to_json(), "support and after-state follow factor selection")
	var point := view.support_canvas.screen_position_for_record(view.support_canvas.document.inspector_records()[0])
	_check(not view.support_canvas.begin_edit_drag(point), "read-only supplied support cannot be dragged into an uncommitted preview")
	var accepted := view.workspace.to_json()
	var accepted_position: float = view.timeline_position
	_check(not view.import_source("{}") and view.workspace.to_json() == accepted and view.factor_index == 2 and view.timeline_position == accepted_position, "failed import preserves workspace, selection and timeline")
	view.export_kind = "svg"
	_check(view.save_export("user://factor-test.svg") and FileAccess.get_file_as_string("user://factor-test.svg") == first.svg, "export save writes exact accepted SVG")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://factor-test.svg"))
	_check(view.import_source(partial_workspace.to_json()) and view.export_svg.disabled, "incomplete supplied states display but publication is unavailable")
	view.select_factor(1)
	_check(view.before_canvas.document == null and "NOT SUPPLIED" in view.before_label.text, "missing state view is absent and honestly labeled")
	view.set_timeline_position(1.75)
	_check(view.before_canvas.document == null and view.after_canvas.document != null and view.braid_canvas.braid_playhead == 1.0, "partial state gap stays absent throughout empty-stage playback")
	view.browser_mode = true
	_check(view.import_source(source) and view.export_svg.disabled and "Browser" in view.message.text, "browser never claims local Python validation")
	for viewport in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = viewport
		# The main Studio sets this to CSS pixels in _sync_viewport(). Reproduce
		# that contract when testing the factor panel without its parent scene.
		root.content_scale_size = viewport
		for frame in 4: await process_frame
		_check(view.grid.columns == (1 if viewport.x < 900 else 3), "factor viewer adapts columns at %s" % viewport)
		_check(view.grid.get_global_rect().end.x <= viewport.x + 1, "factor views do not overflow horizontally at %s" % viewport)
	var empty := workspace.to_dict()
	empty.factors = []
	empty.initial_state = null
	_check(view.import_source(JSON.stringify(empty)) and view.factor_index == -1 and view.support_canvas.document == null, "empty sequence clears prior selection and diagrams")
	empty.initial_state = "leftArc"
	_check(view.import_source(JSON.stringify(empty)) and view.before_canvas.document != null and "no factors" in view.before_label.text, "empty factor sequence still displays a supplied initial state")
	view.queue_free()
	await process_frame
	root.size = Vector2i(1280, 800)
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	studio.browser_drafts.button_pressed = true
	studio._canvas_edit_commit("object", "p1", Vector2(-118, 0))
	var editor_source: String = studio.document.to_json()
	studio._show_factor_workspace()
	_check(studio.factor_view.visible and not studio.workspace_root.visible and studio.factor_view.workspace != null, "main editor exposes factor workspace")
	var undo_event := InputEventKey.new()
	undo_event.pressed = true
	undo_event.ctrl_pressed = true
	undo_event.keycode = KEY_Z
	studio._unhandled_key_input(undo_event)
	_check(studio.history.undo_stack.size() == 1 and studio.document.to_json() == editor_source, "factor viewer shortcuts cannot undo hidden editor work")
	root.size = Vector2i(390, 844)
	studio._sync_viewport()
	for frame in 4: await process_frame
	_check(studio.factor_view.grid.columns == 1 and studio.factor_view.grid.get_global_rect().end.x <= 391, "factor workspace fits actual phone-sized main scene")
	studio.factor_view.closed.emit()
	_check(studio.workspace_root.visible and not studio.factor_view.visible and not studio.factor_view.playing and studio.document.to_json() == editor_source and studio.history.undo_stack.size() == 1, "return to editor stops factor playback and preserves unsaved document plus undo history")
	_check(studio.factor_view.workspace.to_json() == original, "all factor timeline interaction leaves the mathematical envelope byte-identical")
	studio.queue_free()
	await process_frame
	print("Factor workspace: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
