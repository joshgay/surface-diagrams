extends SceneTree

const FORMAT := "surface-diagrams-studio-demo-receipt"
const VERSION := 1
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	WorkspaceRecovery.clear_file()
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = false
	root.add_child(studio)
	await process_frame

	var receipt := {
		"format": FORMAT,
		"version": VERSION,
		"workflow": "generic-review-v1",
		"runtime": "4.7.2.stable.official.ed1daf0bf",
		"geometry_authority": "surface-diagrams Python library",
		"checks": []
	}

	var original: String = studio.document.to_json()
	var original_ids: Array = studio.document.data.surface.objects.map(func(item): return item.id)
	studio._canvas_edit_commit("object", "p1", Vector2(-118.0, 0.0))
	var edited: String = studio.document.to_json()
	_check(edited != original and studio.geometry_result.get("ok", false), "validated point edit changes the accepted recipe")
	_check(studio.document.data.surface.objects.map(func(item): return item.id) == original_ids, "point edit preserves stable object order")
	_check(studio.canvas.selected_record.get("id", "") == "p1", "point edit retains stable-ID selection")
	receipt.checks.append({
		"id": "validated-edit",
		"record": "p1",
		"before_sha256": _sha_text(original),
		"after_sha256": _sha_text(edited),
		"object_ids": original_ids,
		"geometry_validated": true
	})

	studio._undo()
	_check(studio.document.to_json() == original, "undo restores the exact original recipe")
	studio._redo()
	_check(studio.document.to_json() == edited, "redo restores the exact validated edit")
	receipt.checks.append({
		"id": "exact-history",
		"undo_sha256": _sha_text(original),
		"redo_sha256": _sha_text(edited),
		"undo_depth": studio.history.undo_stack.size(),
		"redo_depth": studio.history.redo_stack.size()
	})

	studio._show_factor_workspace()
	var factor: FactorWorkspaceView = studio.factor_view
	factor.set_timeline_position(2.5)
	factor.set_direction("top-to-bottom")
	var factor_focus: Dictionary = factor.workspace.focus(factor.factor_index)
	_check(factor.factor_index == 2 and is_equal_approx(factor.timeline_position, 2.5), "factor review reaches the supplied third block")
	_check(factor.direction == "top-to-bottom" and factor.braid_canvas.braid_presentation == "top-to-bottom", "factor review changes presentation without reversing time")
	_check(factor_focus.entry_ids == [2, 1, 3] and factor_focus.exit_ids == [2, 3, 1], "factor review preserves transported strand IDs")
	var factor_source := factor.workspace.to_json()
	receipt.checks.append({
		"id": "linked-factor-review",
		"factor_id": factor_focus.factor.id,
		"literal_word": factor_focus.factor.braid_word,
		"entry_ids": factor_focus.entry_ids,
		"exit_ids": factor_focus.exit_ids,
		"presentation": factor.direction,
		"source_sha256": _sha_text(factor_source)
	})
	factor.closed.emit()
	_check(studio.document.to_json() == edited, "factor review leaves the editor recipe unchanged")

	studio._show_walkthrough()
	var walkthrough: WalkthroughView = studio.walkthrough_view
	_check(walkthrough.import_source(FileAccess.get_file_as_string(WalkthroughView.BRAID_FIXTURE)), "signed-braid walkthrough imports")
	var braid_source := walkthrough.document.to_json()
	walkthrough.set_timeline_position(1.5)
	walkthrough.set_play_direction(-1)
	walkthrough.set_braid_presentation("top-to-bottom")
	var braid_sample := WalkthroughTimeline.sample(walkthrough.document, walkthrough.timeline_position)
	_check(braid_sample.ok and braid_sample.step_index == 1 and is_equal_approx(braid_sample.local, 0.5), "walkthrough review reaches a deterministic fractional block")
	_check(braid_sample.step.braid.word == [-2], "walkthrough review preserves the literal negative generator")
	_check(braid_sample.step.braid.entry_ids == [2, 1, 3] and braid_sample.step.braid.exit_ids == [2, 3, 1], "walkthrough review preserves supplied strand transport")
	_check(walkthrough.play_direction == -1 and walkthrough.braid_presentation == "top-to-bottom", "playback and braid presentation directions remain independent")
	_check(walkthrough.document.to_json() == braid_source, "walkthrough view state leaves the supplied record unchanged")
	receipt.checks.append({
		"id": "signed-braid-walkthrough",
		"step_id": braid_sample.step.id,
		"literal_block": braid_sample.step.braid.word,
		"entry_ids": braid_sample.step.braid.entry_ids,
		"exit_ids": braid_sample.step.braid.exit_ids,
		"play_direction": "reverse",
		"presentation": walkthrough.braid_presentation,
		"source_sha256": _sha_text(braid_source)
	})

	_check(walkthrough.import_source(FileAccess.get_file_as_string(WalkthroughView.COVER_FIXTURE)), "linked planar and exploratory-surface walkthrough imports")
	var cover_source := walkthrough.document.to_json()
	var publication: Dictionary = walkthrough.publication
	_check(publication.get("ok", false) and publication.bundle.size() > 0, "exact publication bundle is available")
	var excluded: Array = publication.manifest.excluded_exploratory_surface_views.map(func(item): return item.id)
	_check(excluded == ["surface_before", "surface_after"], "publication explicitly excludes both exploratory 3D views")
	_check(publication.manifest.source.sha256 == _sha_text(cover_source), "publication manifest binds exact normalized walkthrough source")
	_check(publication.manifest.documents.map(func(item): return item.id) == ["disk_before", "disk_after"], "publication preserves supplied endpoint order")
	receipt.checks.append({
		"id": "deterministic-publication",
		"source_sha256": _sha_text(cover_source),
		"bundle_sha256": _sha(publication.bundle),
		"bundle_bytes": publication.bundle.size(),
		"documents": publication.manifest.documents.map(func(item): return item.id),
		"excluded_exploratory_surface_views": excluded
	})

	var receipt_text := JSON.stringify(receipt, "  ") + "\n"
	var args := _arguments()
	if not args.receipt.is_empty():
		_check(_write_text(args.receipt, receipt_text), "demo receipt writes to the requested path")
	if not args.bundle.is_empty():
		_check(_write_bytes(args.bundle, publication.bundle), "publication bundle writes to the requested path")
	_check(studio.document.to_json() == edited, "complete review leaves the accepted editor state unchanged")
	_check(_receipt_is_bounded(receipt), "receipt contains only the fixed version-1 review fields")

	walkthrough.closed.emit()
	studio.queue_free()
	WorkspaceRecovery.clear_file()
	await process_frame
	print("DEMO WORKFLOW %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	print(receipt_text.strip_edges())
	quit(0 if failures == 0 else 1)

func _arguments() -> Dictionary:
	var result := {"receipt": "", "bundle": ""}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="):
			result.receipt = argument.trim_prefix("--receipt=")
		elif argument.begins_with("--bundle="):
			result.bundle = argument.trim_prefix("--bundle=")
	return result

func _receipt_is_bounded(receipt: Dictionary) -> bool:
	return receipt.keys() == ["format", "version", "workflow", "runtime", "geometry_authority", "checks"] and receipt.checks.size() == 5 and receipt.checks.map(func(item): return item.id) == ["validated-edit", "exact-history", "linked-factor-review", "signed-braid-walkthrough", "deterministic-publication"]

func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(content)
	return true

func _write_bytes(path: String, content: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(content)
	return true

func _sha_text(value: String) -> String:
	return _sha(value.to_utf8_buffer())

func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
