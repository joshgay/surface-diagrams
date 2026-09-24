extends SceneTree

var assertions := 0
var failures := 0
const FIXTURE := "res://fixtures/surfaces/disk-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var source := FileAccess.get_file_as_string(FIXTURE)
	var parsed := SurfaceViewDocument.parse(source)
	_check(parsed.ok, "generic oriented-disk record parses")
	if not parsed.ok:
		quit(1)
		return
	var document: SurfaceViewDocument = parsed.document
	var normalized := document.to_json()
	_check(SurfaceViewDocument.parse(normalized).document.to_json() == normalized, "surface-view save/reopen is exact")
	var copied := document.to_dict()
	copied.objects[0].id = "changed"
	copied.curves[0].points[0][0] = 99
	_check(document.to_json() == normalized, "surface-view data is defensively copied")
	_check(document.planar_document().data.surface.objects.map(func(object): return object.id) == ["p1", "p2", "p3", "b1"], "linked planar object order and IDs preserved")
	_check(document.records().map(func(record): return record.id) == ["p1", "p2", "p3", "b1", "arc1"], "3D records preserve exact planar stable-ID order")
	_check(document.to_dict().planar.style.marked_point_color == "#006fff" and document.to_dict().planar.style.boundary_color == "#8b8b8b" and document.to_dict().planar.curves[0].color == "#ff00d4", "linked recipe retains thesis colors")
	for invalid in ["{}", "[]", source + "x", source.replace('"version": 1,', '"version": 1, "version": 1,'), " ".repeat(256 * 1024 + 1)]:
		_check(not SurfaceViewDocument.parse(invalid).ok, "malformed, duplicate or oversized view rejected")
	for mutation in ["version", "status", "format", "unknown", "script", "braid", "surface_kind", "orientation", "radius", "color", "missing_object", "object_order", "duplicate_object", "bad_position", "curve_id", "curve_closed", "curve_endpoint", "curve_short", "curve_long", "extra_curve"]:
		var raw: Dictionary = JSON.parse_string(source)
		match mutation:
			"version": raw.version = 2
			"status": raw.status = "certified"
			"format": raw.format = "surface-diagrams"
			"unknown": raw.camera = {"yaw": 1}
			"script": raw.script = "res://scripts/studio.gd"
			"braid": raw.planar.kind = "braid"; raw.planar.erase("surface"); raw.planar.erase("curves"); raw.planar.braid = {"strands": 2, "word": []}
			"surface_kind": raw.surface.kind = "genus-2"
			"orientation": raw.surface.orientation = "unspecified"
			"radius": raw.surface.radius = "infinite"
			"color": raw.surface.color = "magenta"
			"missing_object": raw.objects.pop_back()
			"object_order": raw.objects.reverse()
			"duplicate_object": raw.objects[1].id = "p1"
			"bad_position": raw.objects[0].position = [0, 0]
			"curve_id": raw.curves[0].id = "other"
			"curve_closed": raw.curves[0].closed = true
			"curve_endpoint": raw.curves[0].points[0] = [0, 0, 0]
			"curve_short": raw.curves[0].points = [[0, 0, 0]]
			"curve_long": raw.curves[0].points.resize(257)
			"extra_curve": raw.curves.append(raw.curves[0].duplicate(true))
		_check(not SurfaceViewDocument.parse(JSON.stringify(raw)).ok, "reject invalid " + mutation)
	var view := SurfaceWorkspaceView.new()
	root.add_child(view)
	await process_frame
	await process_frame
	_check(view.import_source(source), "live exploratory surface workspace imports fixture")
	for frame in 4: await process_frame
	_check(view.surface_3d.nodes_by_id.keys().size() == 5 and view.surface_3d.orientation_labels.get_child_count() == 3, "3D scene contains linked records and orientation labels")
	_check(view.surface_3d.nodes_by_id.p1.material_override.albedo_color.to_html(false) == "006fff" and view.surface_3d.nodes_by_id.b1.material_override.albedo_color.to_html(false) == "8b8b8b", "3D marks and boundary retain exact colors")
	var curve_mesh: ImmediateMesh = view.surface_3d.nodes_by_id.arc1.mesh
	_check(curve_mesh.get_surface_count() == 1 and curve_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 5, "supplied curve is drawn from all five literal vertices without rerouting")
	_check(view.select_id("arc1") and view.selected_id == "arc1" and view.canvas_2d.selected_record.id == "arc1" and view.surface_3d.selected_id == "arc1", "record-list selection synchronizes stable curve ID across views")
	var camera_before: Transform3D = view.surface_3d.camera.transform
	view.surface_3d.orbit(Vector2(80, -35))
	view.surface_3d.zoom(0.8)
	_check(view.surface_3d.camera.transform != camera_before and document.to_json() == normalized, "orbit and zoom alter camera but not mathematical record")
	view.surface_3d.fit_view()
	_check(is_equal_approx(view.surface_3d.distance, 8.5), "fit restores bounded camera distance")
	var point_record := document.planar_document().inspector_records()[1]
	var point_screen := view.canvas_2d.screen_position_for_record(point_record)
	_check(view.canvas_2d.begin_edit_drag(point_screen) and not view.canvas_2d.edit_dragging and view.selected_id == "p2", "mouse selection in read-only 2D view links point without editing")
	var projected := view.surface_3d.camera.unproject_position(view.surface_3d.positions_by_id.p3)
	var picked := view.surface_3d.pick_at(projected, 8.0)
	_check(picked.get("id", "") == "p3" and view.selected_id == "p3" and view.canvas_2d.selected_record.id == "p3", "3D picking synchronizes point ID into 2D view")
	view.select_id("p2")
	var accepted := document.to_json()
	view._hide_selected()
	_check(view.surface_3d.hidden_ids.has("p2") and not view.surface_3d.nodes_by_id.p2.visible and document.to_json() == accepted, "hide is visibility state only")
	view.select_id("arc1")
	view._isolate_selected()
	_check(view.surface_3d.nodes_by_id.arc1.visible and view.surface_3d.hidden_ids.size() == 4, "isolate retains only selected stable ID")
	view._show_all()
	_check(view.surface_3d.hidden_ids.is_empty() and view.surface_3d.nodes_by_id.values().all(func(node): return node.visible), "show all restores every supplied record")
	view.surface_3d.set_orientation_labels_visible(false)
	_check(not view.surface_3d.orientation_labels.visible and document.to_json() == accepted, "orientation-label visibility is independent view state")
	view.surface_3d.set_orientation_labels_visible(true)
	var prior_id := view.selected_id
	_check(not view.import_source("{}") and view.document.to_json() == accepted and view.selected_id == prior_id, "failed import preserves record and linked selection")
	for viewport in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport
		root.content_scale_size = viewport
		for frame in 4: await process_frame
		_check(view.grid.columns == (1 if viewport.x < 900 else 2), "surface workspace adapts columns at %s" % viewport)
		_check(view.grid.get_global_rect().end.x <= viewport.x + 1, "surface workspace does not overflow horizontally at %s" % viewport)
		if viewport.x < 900:
			_check(view.view_tabs.visible and view.view_columns.filter(func(column): return column.visible).size() == 1, "compact surface workspace shows one selectable linked view at %s" % viewport)
			_check(view.view_tabs.get_global_rect().end.x <= viewport.x + 1 and view.view_tab_buttons.all(func(button): return button.custom_minimum_size.y >= 44), "compact surface switcher fits and retains touch targets at %s" % viewport)
			var preserved := view.document.to_json()
			_check(view.show_compact_view("surface-3d") and view.surface_3d.is_visible_in_tree() and not view.canvas_2d.is_visible_in_tree(), "compact surface tabs reveal 3D without a stacked 760-pixel view block at %s" % viewport)
			_check(view.document.to_json() == preserved and view.selected_id == prior_id, "compact surface switching preserves the exact record and stable-ID selection")
			view.show_compact_view("surface-2d")
		else:
			_check(not view.view_tabs.visible and view.view_columns.all(func(column): return column.visible), "desktop surface workspace keeps both linked views visible")
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
	studio._show_surface_workspace()
	await process_frame
	_check(studio.surface_view.visible and not studio.workspace_root.visible and studio.surface_view.document != null, "main Studio opens exploratory surface workspace")
	var undo_event := InputEventKey.new()
	undo_event.pressed = true
	undo_event.ctrl_pressed = true
	undo_event.keycode = KEY_Z
	studio._unhandled_key_input(undo_event)
	_check(studio.history.undo_stack.size() == 1 and studio.document.to_json() == editor_source, "surface viewer shortcuts cannot undo hidden editor work")
	studio.surface_view.closed.emit()
	_check(studio.workspace_root.visible and not studio.surface_view.visible and studio.document.to_json() == editor_source, "return to editor preserves accepted unsaved document")
	studio.queue_free()
	await process_frame
	print("SURFACE VIEW: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
