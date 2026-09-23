extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var loaded := DiagramDocument.load_path("res://fixtures/braid-v1.json")
	_check(loaded.ok, "generic braid fixture loads")
	if not loaded.ok:
		_finish()
		return
	var braid: DiagramDocument = loaded.document
	var source := braid.to_json()
	# Independent hand-computed endpoints; never derive expected orders from
	# the sampler or from the timeline's own permutation implementation.
	var expected := [[1, 2, 3, 4, 5, 6], [2, 1, 3, 4, 5, 6], [2, 3, 1, 4, 5, 6],
		[2, 3, 4, 1, 5, 6], [2, 3, 4, 5, 1, 6], [2, 3, 4, 5, 6, 1]]
	for direction in ["bottom-to-top", "top-to-bottom"]:
		for step in 6:
			var sample := BraidTimeline.sample(braid, step, direction)
			var endpoints_match := true
			for identity in 6:
				var x: float = (expected[step].find(identity + 1) - 2.5) * 40.0
				var y := (-120.0 + step * 48.0) * (1.0 if direction == "bottom-to-top" else -1.0)
				endpoints_match = endpoints_match and sample.paths[identity][-1].is_equal_approx(Vector2(x, y))
			_check(endpoints_match, "%s prefix %d has independently expected endpoints" % [direction, step])
		var signs_match := true
		var full := BraidTimeline.sample(braid, 5, direction)
		for crossing in full.crossings:
			# World y increases upward. Positive over-pass must start at upper-left
			# and end at lower-right regardless of the direction of traversal.
			var upper: Vector2 = crossing.a if crossing.a.y > crossing.b.y else crossing.b
			var lower: Vector2 = crossing.b if crossing.a.y > crossing.b.y else crossing.a
			signs_match = signs_match and ((upper.x < lower.x) == (crossing.generator > 0))
		_check(signs_match, direction + " preserves physical sign for both positive and negative crossings")
		var quarter := BraidTimeline.sample(braid, 0.25, direction)
		var y := -108.0 if direction == "bottom-to-top" else 108.0
		_check(quarter.paths[0][-1] == Vector2(-90, y) and quarter.paths[1][-1] == Vector2(-70, y), "quarter crossing preserves fractional strand positions in " + direction)
		var snapshot := BraidTimeline.sample(braid, 2.75, direction)
		BraidTimeline.sample(braid, 4.1, direction)
		BraidTimeline.sample(braid, 0.2, direction)
		_check(snapshot == BraidTimeline.sample(braid, 2.75, direction), "forward and reverse sampling returns identical geometry in " + direction)
	_check(BraidTimeline.sample(braid, -1).time == 0 and BraidTimeline.sample(braid, 99).time == 5, "finite time is clamped to exact word endpoints")
	_check(not BraidTimeline.sample(braid, NAN).ok and not BraidTimeline.sample(braid, INF).ok and not BraidTimeline.sample(braid, 1, "sideways").ok, "invalid time and presentation are rejected")
	_check(braid.to_json() == source, "sampling never changes normalized recipe")
	var editor := BraidEditor.new()
	editor.configure(braid, {}, true)
	editor.set_playhead(1.25)
	_check(editor.step == 1 and editor.playhead == 1.25 and "25.0%" in editor.detail.text, "fractional inspector states complete prefix plus current progress")
	editor.toggle_play()
	editor.advance(0.15)
	_check(is_equal_approx(editor.playhead, 1.5) and editor.playing, "playback advances within one crossing")
	editor.toggle_play()
	editor.advance(0.6)
	_check(is_equal_approx(editor.playhead, 1.5) and not editor.playing, "pause retains exact fractional position")
	editor.set_playhead(1.25)
	editor._back()
	_check(editor.playhead == 1, "back from partial crossing returns its entry")
	editor.set_playhead(1.25)
	editor._forward()
	_check(editor.playhead == 2, "forward from partial crossing returns its exit")
	editor.set_playhead(0)
	editor.toggle_play()
	for delta in [0.13, 0.04, 0.23, 0.1, 0.7]:
		editor.advance(delta)
	_check(editor.step == 2 and editor.playhead == 2, "unequal frame partitions reach exact expected boundary")
	editor.advance(1.8)
	_check(editor.playhead == 5 and not editor.playing, "large advance stops exactly at final endpoint")
	editor.set_playhead(2.75)
	editor.set_playhead(NAN)
	_check(editor.playhead == 2.75, "nonfinite scrub leaves current view intact")
	editor.configure(braid, {}, false)
	_check(editor.playhead == 2 and not editor.playing, "history refresh discards old partial crossing")
	editor.free()
	# Exercise the real scene and mouse handler, without claiming visual QA.
	WorkspaceRecovery.clear_file()
	var packed := load("res://scenes/studio.tscn") as PackedScene
	var studio = packed.instantiate()
	root.add_child(studio)
	await process_frame
	studio._open_resource("res://fixtures/braid-v1.json")
	await process_frame
	studio.braid_editor.set_process(false)
	var svg: String = studio.geometry_result.svg
	for direction in ["bottom-to-top", "top-to-bottom"]:
		studio.braid_editor.set_direction(direction)
		studio.braid_editor.set_step(5)
		studio.canvas.zoom_at(studio.canvas.size / 2.0, 1.1)
		studio.canvas.pan = Vector2(21, -12)
		var all_selected := true
		for index in 5:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = studio.canvas.screen_position_for_crossing(index)
			studio.canvas._gui_input(click)
			all_selected = all_selected and studio.canvas.selected_record.index == index and studio.braid_editor.index_spin.value == index and studio.record_list.get_selected_items()[0] == index + 1
		_check(all_selected, "mouse picks exact crossing in canvas, list and inspector after pan/zoom in " + direction)
		var later: Vector2 = studio.canvas.screen_position_for_crossing(4)
		studio.braid_editor.set_playhead(0.49)
		_check(not studio.canvas.select_braid_crossing(later) and not studio.canvas.screen_position_for_crossing(0).is_finite(), "unrevealed crossings cannot be picked")
		studio.braid_editor.set_playhead(0.5)
		_check(studio.canvas.select_braid_crossing(studio.canvas.screen_position_for_crossing(0)), "a crossing becomes selectable at its actual midpoint")
		studio.braid_editor.set_playhead(3.75)
		studio.braid_editor.toggle_play()
		_check(studio.canvas.select_braid_crossing(studio.canvas.screen_position_for_crossing(2)) and not studio.braid_editor.playing and studio.braid_editor.playhead == 3.75, "selection pauses at current view time without advancing source")
	_check(studio.document.to_json() == source and studio.geometry_result.svg == svg and not studio.history.can_undo(), "all interaction preserves recipe, publication geometry, and history")
	studio.braid_editor.index_spin.value = 1
	_check(studio.canvas.selected_record.index == 1 and studio.record_list.get_selected_items()[0] == 2, "position control synchronizes crossing selection")
	studio.braid_editor.index_spin.value = 5
	_check(studio.canvas.selected_record.kind == "braid", "append position clears obsolete crossing highlight")
	studio.braid_editor.set_playhead(1.4)
	studio._edit_braid_word("replace", 1, 0)
	_check(studio.braid_editor.playhead == 1.4 and studio.document.to_json() == source, "rejected edit retains fractional view and source")
	studio._edit_braid_word("insert", 1, -1)
	_check(studio.braid_editor.playhead == 2 and studio.canvas.braid_playhead == 2 and studio.canvas.selected_record.index == 1, "insert selects new exact index and discards obsolete partial preview")
	studio.braid_editor.set_playhead(1.7)
	studio.braid_editor.toggle_play()
	studio._undo()
	_check(studio.document.to_json() == source and studio.braid_editor.playhead == 1 and not studio.braid_editor.playing, "undo stops partial playback and restores exact original word")
	studio._redo()
	_check(studio.document.data.braid.word == [1, -1, -2, 3, -4, 5] and studio.canvas.selected_record.index == 1 and studio.braid_editor.playhead == 1, "redo restores indexed crossing without reviving old animation")
	studio.braid_editor.set_playhead(1.7)
	studio._edit_braid_word("delete", 1, 0)
	_check(studio.document.to_json() == source and studio.canvas.selected_record.index == 1 and studio.braid_editor.playhead == 2, "delete reselects next literal crossing at exact boundary")
	var empty_data := braid.to_dict()
	empty_data.braid.word = []
	studio._open_result(DiagramDocument.parse(JSON.stringify(empty_data)), "empty braid")
	_check(studio.braid_editor.playhead == 0 and not studio.canvas.select_braid_crossing(Vector2.ZERO), "empty braid has no phantom selectable crossing")
	studio.braid_editor.toggle_play()
	_check(not studio.braid_editor.playing and studio.canvas._braid_sample().paths[0].size() == 2, "identity braid stays stationary with complete straight strands")
	studio.queue_free()
	await process_frame
	WorkspaceRecovery.clear_file()
	_finish()

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _finish() -> void:
	print("BRAID INTERACTION %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)
