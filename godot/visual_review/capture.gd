extends SceneTree

const PROFILE_FORMAT := "surface-diagrams-studio-visual-profile"
const PROFILE_VERSION := 1

var output_directory := ""
var profile_id := ""
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_arguments()
	if output_directory.is_empty() or profile_id.is_empty():
		_fail("capture requires --output and --profile")
		_finish()
		return
	var profile := VisualReviewPlan.profile(profile_id)
	if profile.is_empty():
		_fail("unknown visual-review profile " + profile_id)
		_finish()
		return
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("visual review requires a real X11 or Wayland display; headless capture is not visual evidence")
		_finish()
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("could not create visual-review output directory")
		_finish()
		return
	root.size = profile.viewport
	root.content_scale_size = profile.viewport
	WorkspaceRecovery.clear_file()
	var frames: Array[Dictionary] = []
	for capture_case in VisualReviewPlan.cases_for_profile(profile_id):
		var frame := await _capture_case(capture_case)
		if frame.is_empty():
			break
		frames.append(frame)
	var receipt := {
		"format": PROFILE_FORMAT,
		"version": PROFILE_VERSION,
		"plan_format": VisualReviewPlan.FORMAT,
		"plan_version": VisualReviewPlan.VERSION,
		"profile": profile_id,
		"viewport": {"width": profile.viewport.x, "height": profile.viewport.y},
		"engine": Engine.get_version_info().string,
		"engine_hash": Engine.get_version_info().hash,
		"display_driver": DisplayServer.get_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"manual_inspection_status": "not-reviewed",
		"visual_acceptance_claimed": false,
		"controller_acceptance": "separate evidence",
		"frames": frames,
		"failures": failures,
	}
	var receipt_path := output_directory.path_join(profile_id + ".json")
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		_fail("could not write " + receipt_path)
	else:
		file.store_string(JSON.stringify(receipt, "  ", false, true) + "\n")
		file.close()
	_finish()

func _parse_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		if arguments[index] == "--output" and index + 1 < arguments.size():
			output_directory = arguments[index + 1]
			index += 2
		elif arguments[index] == "--profile" and index + 1 < arguments.size():
			profile_id = arguments[index + 1]
			index += 2
		else:
			_fail("unknown or incomplete capture argument " + arguments[index])
			index += 1

func _capture_case(capture_case: Dictionary) -> Dictionary:
	var packed := load("res://scenes/studio.tscn") as PackedScene
	if packed == null:
		_fail("studio scene did not load")
		return {}
	var studio = packed.instantiate()
	studio.browser_mode = false
	root.add_child(studio)
	await _settle(5)
	var content_target: Control
	match capture_case.workspace:
		"editor":
			studio._open_result(DiagramDocument.load_path(capture_case.fixture), capture_case.fixture, false)
			await _settle(3)
			_select_editor_id(studio, capture_case.selected_id)
			studio._show_mobile_panel(capture_case.editor_panel == "records")
			if capture_case.focus_target == "canvas":
				studio.canvas.grab_focus()
				content_target = studio.canvas
			else:
				studio.record_list.grab_focus()
				content_target = studio.record_list
		"factor":
			studio._show_factor_workspace()
			await _settle(4)
			studio.factor_view.set_timeline_position(capture_case.timeline_position)
			content_target = _factor_target(studio.factor_view, capture_case.content_target)
		"surface":
			studio._show_surface_workspace()
			await _settle(4)
			studio.surface_view.select_id(capture_case.selected_id)
			content_target = _surface_target(studio.surface_view, capture_case.content_target)
		"walkthrough":
			studio._show_walkthrough()
			await _settle(4)
			if not studio.walkthrough_view.import_source(FileAccess.get_file_as_string(capture_case.fixture)):
				_fail("walkthrough fixture did not load for " + capture_case.id)
				studio.queue_free()
				await process_frame
				return {}
			studio.walkthrough_view.set_timeline_position(capture_case.timeline_position)
			content_target = _walkthrough_target(studio.walkthrough_view, capture_case.content_target)
		_:
			_fail("unknown workspace " + capture_case.workspace)
			studio.queue_free()
			await process_frame
			return {}
	if capture_case.focus_target == "content" and content_target != null:
		content_target.grab_focus()
	await _settle(4)
	var scroll_y := _scroll_to(content_target)
	await _settle(4)
	var focused := root.gui_get_focus_owner()
	if focused == null or focused.get_accessibility_name() != capture_case.expected_focus_name:
		_fail("focus mismatch for %s: expected %s" % [capture_case.id, capture_case.expected_focus_name])
		studio.queue_free()
		await process_frame
		return {}
	var actual_id := _actual_selected_id(studio, capture_case.workspace)
	if actual_id != capture_case.selected_id:
		_fail("selection mismatch for %s: expected %s, got %s" % [capture_case.id, capture_case.selected_id, actual_id])
		studio.queue_free()
		await process_frame
		return {}
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != capture_case.viewport:
		_fail("rendered frame for %s has size %s, expected %s" % [capture_case.id, image.get_size() if image != null else Vector2i.ZERO, capture_case.viewport])
		studio.queue_free()
		await process_frame
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var filename: String = capture_case.id + ".png"
	var path := output_directory.path_join(filename)
	if image.save_png(path) != OK:
		_fail("could not write " + path)
		studio.queue_free()
		await process_frame
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else -1
	var frame := {
		"id": capture_case.id,
		"workspace": capture_case.workspace,
		"fixture": capture_case.fixture,
		"fixture_sha256": FileAccess.get_sha256(capture_case.fixture),
		"viewport": {"width": capture_case.viewport.x, "height": capture_case.viewport.y},
		"compact_layout": studio.compact_layout,
		"editor_panel": capture_case.editor_panel,
		"content_target": capture_case.content_target,
		"scroll_y": scroll_y,
		"selected_id": actual_id,
		"timeline_position": capture_case.timeline_position,
		"focus": {
			"accessibility_name": focused.get_accessibility_name(),
			"class": focused.get_class(),
			"path": str(studio.get_path_to(focused)),
		},
		"image": filename,
		"image_width": image.get_width(),
		"image_height": image.get_height(),
		"image_bytes": byte_count,
		"image_sha256": FileAccess.get_sha256(path),
		"manual_inspection_status": "not-reviewed",
	}
	studio.queue_free()
	await _settle(2)
	return frame

func _select_editor_id(studio, id: String) -> void:
	for index in studio.record_list.item_count:
		var record = studio.record_list.get_item_metadata(index)
		if typeof(record) == TYPE_DICTIONARY and record.get("id", "") == id:
			studio.record_list.select(index)
			studio.record_list.item_selected.emit(index)
			return

func _factor_target(view: FactorWorkspaceView, target: String) -> Control:
	view.show_compact_view(target)
	if target == "braid": return view.braid_canvas
	if target == "states": return view.before_canvas
	return view.support_canvas

func _surface_target(view: SurfaceWorkspaceView, target: String) -> Control:
	view.show_compact_view(target)
	if target == "surface-3d": return view.surface_3d
	if target == "surface-2d": return view.canvas_2d
	return view.grid

func _walkthrough_target(view: WalkthroughView, target: String) -> Control:
	view.show_compact_view(target)
	if target == "after": return view.after_canvas
	if target == "before": return view.before_canvas
	return view.grid

func _scroll_to(target: Control) -> int:
	if target == null:
		return 0
	var parent := target.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if not parent is ScrollContainer:
		return 0
	var scroll := parent as ScrollContainer
	var offset := int(target.get_global_rect().position.y - scroll.get_global_rect().position.y)
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + offset - 8, 0, int(scroll.get_v_scroll_bar().max_value))
	return scroll.scroll_vertical

func _actual_selected_id(studio, workspace: String) -> String:
	match workspace:
		"editor": return studio.canvas.selected_record.get("id", "")
		"factor":
			if studio.factor_view.factor_index < 0: return ""
			return studio.factor_view.workspace.to_dict().factors[studio.factor_view.factor_index].id
		"surface": return studio.surface_view.selected_id
		"walkthrough":
			if studio.walkthrough_view.step_index < 0: return ""
			return studio.walkthrough_view.document.to_dict().steps[studio.walkthrough_view.step_index].id
	return ""

func _settle(count: int) -> void:
	for _frame in count:
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
	printerr("VISUAL REVIEW ERROR: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VISUAL REVIEW CAPTURE PASS: " + profile_id)
		quit(0)
	else:
		quit(1)
