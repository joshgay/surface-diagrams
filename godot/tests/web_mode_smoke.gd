extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var studio = load("res://scenes/studio.tscn").instantiate()
	# Exercises browser-specific controller paths in the native headless runtime.
	# This does not claim to execute WebAssembly, DOM dialogs, or WebGL rendering.
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	_check(studio.document != null, "web-mode fixture loads without Python")
	_check(not studio.geometry_result.ok, "web mode never claims certified geometry")
	_check(studio.svg_button.disabled and studio.tikz_button.disabled, "exact exports disabled")
	_check(not studio.browser_drafts.button_pressed, "unvalidated edits require opt in")
	var before: String = studio.document.to_json()
	var x: float = studio.document.data.surface.objects[1].x + 0.1
	studio._canvas_edit_commit("object", "p2", Vector2(x, 0))
	_check(studio.document.to_json() == before and not studio.history.can_undo(), "default rejects unvalidated edit without history")
	studio.browser_drafts.button_pressed = true
	studio._canvas_edit_commit("object", "p2", Vector2(x, 0))
	var after: String = studio.document.to_json()
	_check(after != before and "UNVALIDATED" in studio.status_label.text, "opted-in draft is visibly unvalidated")
	_check(not studio.geometry_result.ok and studio.svg_button.disabled, "edit does not fabricate geometry")
	_check(studio.document.data.curves[0].start == 1 and studio.document.data.curves[0].cuts == [], "draft preserves itinerary and endpoints")
	studio._undo()
	_check(studio.document.to_json() == before, "browser-mode undo restores exact source")
	studio._redo()
	_check(studio.document.to_json() == after, "browser-mode redo restores draft")
	studio._canvas_edit_commit("object", "p2", Vector2(99999, 0))
	_check(studio.document.to_json() == after, "draft mode still rejects order/ellipse violation")
	studio._browser_file_received(["{\"version\":999}", ""])
	_check(studio.document.to_json() == after, "invalid upload retains current draft")
	studio._browser_file_received(["", "file read failed"])
	_check(studio.document.to_json() == after and "file read failed" in studio.status_label.text, "read failure preserves data and reports error")
	studio._browser_file_received(["", ""])
	_check(studio.document.to_json() == after, "cancel preserves data")
	studio._browser_file_received([before, ""])
	_check(studio.document.to_json() == before and not studio.history.can_undo(), "bounded upload opens exact recipe with fresh history")
	_check(not studio.browser_drafts.button_pressed, "opening a file resets experimental consent")
	studio._show_open()
	_check("unavailable" in studio.status_label.text, "missing DOM adapter is explicit")
	studio._show_save()
	_check("unavailable" in studio.status_label.text, "missing download adapter is explicit")
	studio._open_resource("res://fixtures/multi-curve-v1.json")
	var multi_initial: String = studio.document.to_json()
	studio.record_list.item_selected.emit(0)
	studio._request_reindex(1)
	_check(studio.pending_reindex.is_empty() and studio.document.to_json() == multi_initial, "browser reindex requires explicit unvalidated-edit opt in")
	studio.browser_drafts.button_pressed = true
	studio._request_reindex(1)
	_check(not studio.pending_reindex.is_empty() and studio.document.to_json() == multi_initial, "browser reindex is still a non-mutating confirmation proposal")
	studio._confirm_reindex()
	_check(studio.document.data.surface.objects[0].id == "p2" and "UNVALIDATED" in studio.status_label.text and not studio.geometry_result.ok, "browser reindex remains explicitly unvalidated")
	studio._undo()
	_check(studio.document.to_json() == multi_initial, "browser reindex undo restores exact original order")
	studio.browser_drafts.button_pressed = false
	studio.record_list.item_selected.emit(7)
	var multi_source: String = studio.document.to_json()
	studio.curve_inspector.append_cut(5)
	studio.curve_inspector._apply()
	_check(studio.document.to_json() == multi_source and not studio.history.can_undo(), "browser itinerary edit requires opt in")
	_check(studio.curve_inspector.draft_cuts == [0, 5], "browser rejection retains draft")
	studio.browser_drafts.button_pressed = true
	studio.curve_inspector._apply()
	_check(studio.document.data.curves[1].cuts == [0, 5] and "UNVALIDATED" in studio.status_label.text, "browser record acceptance never claims routing success")
	_check(not studio.geometry_result.ok and studio.svg_button.disabled and studio.tikz_button.disabled, "browser itinerary edit leaves exact exports disabled")
	studio._undo()
	_check(studio.document.to_json() == multi_source, "browser itinerary undo restores exact record")
	studio.curve_inspector.append_cut(0)
	studio.curve_inspector._apply()
	_check(studio.document.to_json() == multi_source and studio.curve_inspector.draft_cuts == [0, 0], "browser opt in does not permit nonminimal record")
	studio._open_resource("res://fixtures/braid-v1.json")
	_check(studio.document.to_json() == multi_source and studio.pending_action.is_valid(), "web mode also guards unapplied drafts before fixture replacement")
	studio._discard_and_continue()
	_check(studio.document.data.kind == "braid" and studio.record_list.item_count == 6, "braid view remains available without Python")
	studio.queue_free()
	await process_frame
	print("WEB MODE CONTROLLER: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
