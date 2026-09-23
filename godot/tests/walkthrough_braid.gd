extends SceneTree

var assertions := 0
var failures := 0
const FIXTURE := "res://fixtures/walkthroughs/signed-braid-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var source := FileAccess.get_file_as_string(FIXTURE)
	var parsed := WalkthroughDocument.parse(source)
	_check(parsed.ok, "generic signed-braid walkthrough parses")
	if not parsed.ok:
		printerr("Fixture parse error: " + parsed.error)
		quit(1)
		return
	var document: WalkthroughDocument = parsed.document
	var normalized := document.to_json()
	_check(document.kind() == "braid", "walkthrough reports homogeneous braid kind")
	_check(WalkthroughDocument.parse(normalized).document.to_json() == normalized, "braid walkthrough save/reopen is exact")
	var copied := document.to_dict()
	copied.steps[0].braid.word[0] = -1
	copied.steps[0].braid.entry_ids[0] = 3
	copied.documents.positive.braid.word[0] = -1
	_check(document.to_json() == normalized, "braid walkthrough returns defensive copies")
	_check(document.to_dict().steps.map(func(step): return step.braid.word) == [[1], [-2], [1]], "literal signed step words retain supplied order and signs")
	_check(document.diagram("empty").data.braid.word == [] and document.diagram("positive").data.braid.word == [1] and document.diagram("mixed").data.braid.word == [1, -2] and document.diagram("final").data.braid.word == [1, -2, 1], "complete endpoint words form exact prefixes")
	var expected_orders := [[1, 2, 3], [2, 1, 3], [2, 3, 1], [3, 2, 1]]
	for index in 3:
		var step := document.step(index)
		_check(step.braid.entry_ids == expected_orders[index] and step.braid.exit_ids == expected_orders[index + 1], "step %d preserves independently expected transported IDs" % index)
		_check(BraidTimeline.orders(document.diagram(step.before)).back() == expected_orders[index] and BraidTimeline.orders(document.diagram(step.after)).back() == expected_orders[index + 1], "complete state %d matches supplied endpoint orders" % index)
	_check(document.step(0).selected == [{"kind": "strand", "id": 1}, {"kind": "strand", "id": 2}], "stable numeric strand selections are preserved")
	for mutation in ["mixed_kind", "strands", "spacing", "colors", "direction", "after_short", "after_reordered", "block_zero", "block_wrong", "entry_short", "entry_duplicate", "entry_wrong", "exit_duplicate", "exit_wrong", "strand_string", "strand_range", "missing_braid", "braid_unknown"]:
		var raw: Dictionary = JSON.parse_string(source)
		match mutation:
			"mixed_kind": raw.documents.positive = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/planar-v1.json"))
			"strands": raw.documents.positive.braid.strands = 4
			"spacing": raw.documents.positive.braid.spacing = 60
			"colors": raw.documents.positive.braid.colors = ["#000000"]
			"direction": raw.documents.positive.braid.direction = "top-to-bottom"
			"after_short": raw.documents.positive.braid.word = []
			"after_reordered": raw.documents.mixed.braid.word = [-2, 1]
			"block_zero": raw.steps[0].braid.word = [0]
			"block_wrong": raw.steps[0].braid.word = [-1]
			"entry_short": raw.steps[0].braid.entry_ids = [1, 2]
			"entry_duplicate": raw.steps[0].braid.entry_ids = [1, 1, 3]
			"entry_wrong": raw.steps[1].braid.entry_ids = [1, 2, 3]
			"exit_duplicate": raw.steps[0].braid.exit_ids = [2, 2, 3]
			"exit_wrong": raw.steps[1].braid.exit_ids = [3, 2, 1]
			"strand_string": raw.steps[0].selected[0].id = "1"
			"strand_range": raw.steps[0].selected[0].id = 4
			"missing_braid": raw.steps[0].erase("braid")
			"braid_unknown": raw.steps[0].braid.script = "res://scripts/studio.gd"
		_check(not WalkthroughDocument.parse(JSON.stringify(raw)).ok, "reject invalid braid " + mutation)
	var planar_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WalkthroughView.PLANAR_FIXTURE))
	planar_raw.steps[0].braid = {"word": [1], "entry_ids": [1, 2], "exit_ids": [2, 1]}
	_check(not WalkthroughDocument.parse(JSON.stringify(planar_raw)).ok, "planar steps reject braid-only metadata")
	var multi: Dictionary = JSON.parse_string(source)
	multi.steps = [multi.steps[0]]
	multi.documents = {"empty": multi.documents.empty, "positive": multi.documents.mixed}
	multi.steps[0].after = "positive"
	multi.steps[0].braid.word = [1, -2]
	multi.steps[0].braid.exit_ids = [2, 3, 1]
	var multi_parsed := WalkthroughDocument.parse(JSON.stringify(multi))
	_check(multi_parsed.ok and multi_parsed.document.step(0).braid.word == [1, -2], "multi-generator literal block is accepted without reduction")
	for direction in ["bottom-to-top", "top-to-bottom"]:
		var positive := BraidTimeline.crossing(document.diagram("positive"), 0, direction)
		var negative := BraidTimeline.crossing(document.diagram("mixed"), 1, direction)
		_check(positive.ok and positive.upper_left_over_upper_right and negative.ok and not negative.upper_left_over_upper_right, direction + " retains fixed physical signs")
		_check(positive.before == [1, 2, 3] and positive.after == [2, 1, 3] and negative.before == [2, 1, 3] and negative.after == [2, 3, 1], direction + " does not reverse word or strand transport")
	var view := WalkthroughView.new()
	root.add_child(view)
	await process_frame
	_check(view.import_source(source) and view.document.kind() == "braid" and view.presentation_option.visible, "live viewer imports signed-braid fixture and exposes presentation control")
	_check(view.before_canvas.document.data.braid.word == [] and view.after_canvas.document.data.braid.word == [1], "viewer displays complete supplied braid endpoints")
	_check(view.before_canvas.braid_playhead == 0.0 and view.after_canvas.braid_playhead == 0.0, "first braid step begins at exact entry prefix")
	_check(view.before_canvas.selected_record == {"kind": "strand", "id": 1} and view.after_canvas.selected_record == {"kind": "strand", "id": 1}, "stable strand selection links both endpoint canvases")
	view.set_timeline_position(0.5)
	_check(view.after_canvas.braid_playhead == 0.5 and view.before_canvas.braid_playhead == 0.0 and view.before_canvas.modulate.a == 1.0 and view.after_canvas.modulate.a == 1.0, "fraction reveals literal crossing without fading or synthesizing a record")
	_check("Literal block [1]" in view.details.text and "upper-left over upper-right" in view.details.text, "literal word, endpoint IDs, and fixed sign convention remain visible")
	var at_half := view.after_canvas._braid_sample()
	_check(at_half.crossings.size() == 1 and at_half.crossings[0].fraction == 0.5 and at_half.crossings[0].generator == 1, "schematic playhead follows exact positive generator fraction")
	view.set_braid_presentation("top-to-bottom")
	_check(view.braid_presentation == "top-to-bottom" and view.after_canvas.braid_presentation == "top-to-bottom" and view.timeline_position == 0.5, "presentation switch preserves mathematical and timeline position")
	var top_half := view.after_canvas._braid_sample()
	_check(top_half.crossings[0].generator == 1 and top_half.crossings[0].over_id != at_half.crossings[0].over_id, "presentation changes traversal geometry without changing positive sign")
	view.set_timeline_position(1.5)
	_check(view.step_index == 1 and view.after_canvas.braid_playhead == 1.5 and view.after_canvas._braid_sample().crossings[1].generator == -2, "second step reveals the literal negative generator in supplied order")
	_check(view.before_canvas.selected_record.id == 1 and view.after_canvas.selected_record.id == 1 and view.selected_list.item_count == 2, "negative step preserves its supplied stable strand selection")
	var crossing_point := view.after_canvas.screen_position_for_crossing(1)
	_check(crossing_point.is_finite() and view.after_canvas.select_braid_crossing(crossing_point) and view.after_canvas.selected_record.index == 1, "revealed crossing can be inspected at its exact global index")
	view.set_play_direction(-1)
	view.set_timeline_position(3.0)
	view.toggle_play()
	view.advance(2.25)
	_check(view.playing and view.timeline_position == 1.5 and view.step_index == 1 and view.after_canvas.braid_playhead == 1.5, "reverse playback returns the identical literal negative crossing state")
	var accepted := view.document.to_json()
	var accepted_position := view.timeline_position
	_check(not view.import_source("{}") and view.document.to_json() == accepted and view.timeline_position == accepted_position and view.braid_presentation == "top-to-bottom", "failed braid import preserves record, scrub, and presentation")
	_check(view.save_path("user://walkthrough-braid-test.json") and FileAccess.get_file_as_string("user://walkthrough-braid-test.json") == normalized, "viewer saves exact normalized braid walkthrough")
	_check(WalkthroughDocument.parse(FileAccess.get_file_as_string("user://walkthrough-braid-test.json")).document.to_json() == normalized, "saved braid walkthrough reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough-braid-test.json"))
	_check(view.document.to_json() == normalized, "all braid playback and presentation interaction leaves source byte-identical")
	view.queue_free()
	await process_frame
	print("WALKTHROUGH BRAID: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
