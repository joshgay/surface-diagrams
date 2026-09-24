extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var planar: DiagramDocument = DiagramDocument.load_path("res://fixtures/planar-v1.json").document
	var planar_records: Array[Dictionary] = planar.inspector_records()
	var all := RecordLocator.find(planar_records, "")
	_check(all.ok and all.results.size() == 6 and all.results.map(func(result): return result.row) == [0, 1, 2, 3, 4, 5], "empty query returns every bounded record in exact inspector order")
	var objects := RecordLocator.find(planar_records, "object p")
	_check(objects.ok and objects.results.size() == 4 and objects.results.map(func(result): return result.record.id) == ["p1", "p2", "p3", "p4"], "space-separated kind and ID terms filter without reordering")
	var exact := RecordLocator.find(planar_records, "ARC1")
	_check(exact.ok and exact.results.size() == 1 and exact.results[0].row == 4 and exact.results[0].exact_id, "persistent-ID lookup is case-insensitive and marks an exact ID")
	var label := RecordLocator.find(planar_records, "generic fixture")
	_check(label.ok and label.results.size() == 1 and label.results[0].record.id == "label1", "visible label text is searchable without replacing the stable ID")
	_check(RecordLocator.find(planar_records, "missing").results.is_empty(), "unmatched query returns an explicit empty result")
	var too_long := RecordLocator.find(planar_records, "x".repeat(RecordLocator.MAX_QUERY_LENGTH + 1))
	_check(not too_long.ok and "80 characters" in too_long.error, "overlong query is rejected at the fixed bound")
	var too_many: Array[Dictionary] = []
	for index in RecordLocator.MAX_RECORDS + 1:
		too_many.append({"kind": "record", "id": "r%d" % index, "index": index, "label": "Record %d" % index})
	_check(not RecordLocator.find(too_many, "").ok, "record source above the conservative row bound is rejected")
	var braid: DiagramDocument = DiagramDocument.load_path("res://fixtures/braid-v1.json").document
	var crossing := RecordLocator.find(braid.inspector_records(), "-2")
	_check(crossing.ok and crossing.results.size() == 1 and crossing.results[0].row == 2 and crossing.results[0].record.index == 1, "records without IDs remain findable by literal visible crossing position and sign")

	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	var accepted: String = studio.document.to_json()
	_check(studio.find_button.get_accessibility_name() == "Find mathematical record" and "view-only" in studio.find_button.get_accessibility_description(), "find entry point states its view-only effect")
	studio.canvas.grab_focus()
	studio._show_record_find()
	await process_frame
	await process_frame
	_check(studio.find_dialog.visible and studio.find_dialog.gui_get_focus_owner() == studio.find_input, "find dialog opens with predictable query focus")
	_check(studio.find_results.item_count == 6 and studio.find_results.get_item_metadata(5).row == 5, "initial dialog result list mirrors exact inspector order")
	_check(studio.find_status.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and studio.find_results.get_accessibility_name() == "Matching mathematical records", "search feedback and results expose accessibility semantics")
	studio.find_input.text = "arc1"
	studio._refresh_record_find(studio.find_input.text)
	_check(studio.find_results.item_count == 1 and studio.find_results.get_item_metadata(0).row == 4 and not studio.find_dialog.get_ok_button().disabled and "Exact persistent ID match" in studio.find_status.text, "exact ID narrows the dialog to its inspector row and identifies the match type")
	studio._accept_record_find()
	await process_frame
	_check(studio.record_list.get_selected_items() == PackedInt32Array([4]) and studio.canvas.selected_record.id == "arc1", "accepting a result synchronizes list and canvas selection")
	_check(root.gui_get_focus_owner() == studio.record_list and studio.active_modal == null, "accepted search moves focus to the selected record and clears modal state")
	_check(studio.document.to_json() == accepted and not studio.history.can_undo(), "search selection leaves mathematical JSON and history exact")

	studio.curve_creator.start("arc")
	studio.canvas.grab_focus()
	studio._unhandled_key_input(_key(KEY_F, true))
	await process_frame
	await process_frame
	_check(studio.find_dialog.visible and studio.find_dialog.gui_get_focus_owner() == studio.find_input, "Control-F opens search while a session-only draft exists")
	studio.find_input.text = "x".repeat(RecordLocator.MAX_QUERY_LENGTH + 1)
	studio._refresh_record_find(studio.find_input.text)
	_check(studio.find_dialog.get_ok_button().disabled and "80 characters" in studio.find_status.text, "invalid query disables selection with an actionable bounded error")
	studio._cancel_record_find()
	await process_frame
	_check(root.gui_get_focus_owner() == studio.canvas and studio.curve_creator.active, "cancel restores exact invoking focus and preserves the unapplied draft")
	_check(studio.document.to_json() == accepted and not studio.history.can_undo(), "invalid and canceled searches remain non-mutating")
	studio.curve_creator.cancel()

	root.size = Vector2i(390, 640)
	root.content_scale_size = root.size
	studio._sync_viewport()
	studio.canvas.grab_focus()
	studio._show_record_find()
	await process_frame
	_check(studio.find_body.custom_minimum_size == Vector2(318, 360) and studio.find_results.custom_minimum_size.y == 260, "portrait search body is capped inside the usable viewport")
	root.size = Vector2i(844, 390)
	root.content_scale_size = root.size
	studio._sync_viewport()
	await process_frame
	_check(studio.find_dialog.size == Vector2i(620, 366) and studio.find_body.custom_minimum_size == Vector2(572, 226) and studio.find_results.custom_minimum_size.y == 126, "open search refits deterministically after compact orientation change")
	studio.find_input.text = "p3"
	studio._refresh_record_find(studio.find_input.text)
	studio._accept_record_find()
	await process_frame
	_check(studio.compact_layout and studio.showing_records and studio.inspector_scroll.visible and not studio.canvas_box.visible, "compact acceptance reveals the selected record pane")
	_check(studio.record_list.get_selected_items() == PackedInt32Array([2]) and root.gui_get_focus_owner() == studio.record_list, "compact ID search lands on the exact stable object row")
	_check(studio.document.to_json() == accepted, "compact search changes presentation only")

	studio._open_resource_after_guard("res://fixtures/braid-v1.json")
	var braid_source: String = studio.document.to_json()
	studio._show_record_find()
	await process_frame
	studio.find_input.text = "-2"
	studio._refresh_record_find(studio.find_input.text)
	studio._accept_record_find()
	await process_frame
	_check(studio.canvas.selected_record.kind == "crossing" and studio.canvas.selected_record.index == 1 and studio.record_list.get_selected_items() == PackedInt32Array([2]), "literal braid lookup selects the exact supplied crossing position")
	_check(studio.document.to_json() == braid_source and not studio.history.can_undo(), "braid lookup preserves signed word, presentation, and history")

	studio.queue_free()
	await process_frame
	print("RECORD FIND %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
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
