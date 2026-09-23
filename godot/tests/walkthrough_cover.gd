extends SceneTree

var assertions := 0
var failures := 0
const FIXTURE := "res://fixtures/walkthroughs/supplied-cover-disk-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var source := FileAccess.get_file_as_string(FIXTURE)
	var parsed := WalkthroughDocument.parse(source)
	_check(parsed.ok, "generic supplied cover linkage parses")
	if not parsed.ok:
		printerr("Fixture parse error: " + parsed.error)
		quit(1)
		return
	var document: WalkthroughDocument = parsed.document
	var normalized := document.to_json()
	var step := document.step(0)
	_check(document.kind() == "planar" and step.has("cover"), "cover linkage is planar and explicit")
	_check(step.cover.status == WalkthroughDocument.COVER_STATUS, "linkage retains the required supplied status")
	_check(step.cover.before_surface == "surface_before" and step.cover.after_surface == "surface_after", "linkage retains literal surface references")
	_check(step.cover.provenance.kind == "original-generic-example" and step.cover.verification.status == "unverified", "linkage has its own provenance and verification")
	_check(document.surface_view("surface_before") != null and document.surface_view("surface_after") != null and document.surface_view("missing") == null, "named supplied surface views are bounded references")
	_check(document.surface_view("surface_before").planar_document().to_json() == document.diagram(step.before).to_json(), "before surface embeds the exact planar before-state")
	_check(document.surface_view("surface_after").planar_document().to_json() == document.diagram(step.after).to_json(), "after surface embeds the exact planar after-state")
	_check(document.surface_view("surface_before").to_dict().objects.map(func(item): return item.id) == ["p1", "p2", "p3", "b1"], "surface endpoint preserves horizontal stable-ID order")
	_check(document.diagram(step.before).data.style.marked_point_color == "#006fff" and document.diagram(step.before).data.style.boundary_color == "#8b8b8b" and document.diagram(step.before).data.curves[0].color == "#ff00d4", "linked planar states preserve drawing colors")
	_check(document.surface_view("surface_after").to_dict().objects[2].position == [0.85, 0.2, 0.12] and document.surface_view("surface_after").to_dict().curves[0].points.back() == [0.85, 0.2, 0.12], "supplied moved endpoint and curve endpoint agree exactly")
	_check(WalkthroughDocument.parse(normalized).document.to_json() == normalized, "linked walkthrough save/reopen is exact")
	var copied := document.to_dict()
	copied.steps[0].cover.before_surface = "changed"
	copied.surface_views.surface_before.objects[0].position[0] = 99.0
	_check(document.to_json() == normalized, "linked walkthrough returns defensive copies")

	for mutation in ["surface_views_array", "orphan_views", "missing_views", "cover_partial", "cover_unknown", "cover_status", "before_ref", "after_ref", "before_planar", "after_planar", "surface_status", "surface_script", "object_order", "curve_endpoint", "provenance_kind", "provenance_script", "verification_status", "verification_resource"]:
		var raw: Dictionary = JSON.parse_string(source)
		match mutation:
			"surface_views_array": raw.surface_views = []
			"orphan_views": raw.steps[0].erase("cover")
			"missing_views": raw.erase("surface_views")
			"cover_partial": raw.steps[0].cover.erase("after_surface")
			"cover_unknown": raw.steps[0].cover.script = "res://scripts/studio.gd"
			"cover_status": raw.steps[0].cover.status = "computed-cover-lift"
			"before_ref": raw.steps[0].cover.before_surface = "missing"
			"after_ref": raw.steps[0].cover.after_surface = "missing"
			"before_planar": raw.surface_views.surface_before.planar.surface.objects[0].x = -119
			"after_planar": raw.surface_views.surface_after.planar.curves[0].cuts = [0]
			"surface_status": raw.surface_views.surface_before.status = "certified"
			"surface_script": raw.surface_views.surface_before.script = "res://scripts/studio.gd"
			"object_order": raw.surface_views.surface_before.objects.reverse()
			"curve_endpoint": raw.surface_views.surface_after.curves[0].points[-1] = [0.7, 0.2, 0.12]
			"provenance_kind": raw.steps[0].cover.provenance.kind = "computed"
			"provenance_script": raw.steps[0].cover.provenance.script = "res://scripts/studio.gd"
			"verification_status": raw.steps[0].cover.verification.status = "proved"
			"verification_resource": raw.steps[0].cover.verification.resource = "res://scenes/studio.tscn"
		_check(not WalkthroughDocument.parse(JSON.stringify(raw)).ok, "reject invalid cover linkage " + mutation)
	var braid_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WalkthroughView.BRAID_FIXTURE))
	braid_raw.surface_views = {"surface_before": JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/surfaces/disk-v1.json"))}
	_check(not WalkthroughDocument.parse(JSON.stringify(braid_raw)).ok, "braid walkthrough rejects planar surface-view data")
	var plain_source := FileAccess.get_file_as_string(WalkthroughView.PLANAR_FIXTURE)
	var plain_document: WalkthroughDocument = WalkthroughDocument.parse(plain_source).document
	_check(not plain_document.to_dict().has("surface_views") and not plain_document.step(0).has("cover"), "legacy planar walkthrough remains exact without invented links")

	var view := WalkthroughView.new()
	root.add_child(view)
	await process_frame
	_check(view.import_source(source) and view.cover_panel.visible, "viewer imports and exposes supplied cover linkage")
	_check(view.cover_before_view.document.to_json() == document.surface_view("surface_before").to_json() and view.cover_after_view.document.to_json() == document.surface_view("surface_after").to_json(), "viewer shows both complete supplied surface endpoints")
	_check("does not compute a branched-cover lift" in view.cover_status.text and "No cover lift is computed" in view.details.text, "viewer labels surface linkage as supplied and noncomputed")
	_check(view.before_canvas.selected_record.id == "p3" and view.after_canvas.selected_record.id == "p3" and view.cover_before_view.selected_id == "p3" and view.cover_after_view.selected_id == "p3", "declared stable selection links both 2D and 3D endpoints")
	var before_yaw := view.cover_before_view.yaw
	view.cover_before_view.orbit(Vector2(20, -10))
	_check(view.cover_before_view.yaw != before_yaw and view.cover_after_view.yaw != view.cover_before_view.yaw, "each exploratory camera remains independent view state")
	_check(view.document.to_json() == normalized, "3D camera motion leaves linked mathematical records byte-identical")
	view._record_selected({"kind": "curve", "id": "arc1"})
	_check(view.before_canvas.selected_record.id == "arc1" and view.after_canvas.selected_record.id == "arc1" and view.cover_before_view.selected_id == "arc1" and view.cover_after_view.selected_id == "arc1", "3D-compatible curve selection links all complete endpoints")
	view.set_timeline_position(0.5)
	_check(view.cover_before_view.document.to_json() == document.surface_view("surface_before").to_json() and view.cover_after_view.document.to_json() == document.surface_view("surface_after").to_json(), "fractional playback never synthesizes a surface state")
	_check(view.cover_before_view.modulate.a == 1.0 and view.cover_after_view.modulate.a == 1.0, "supplied surface endpoints remain complete rather than crossfaded")
	var accepted_position := view.timeline_position
	_check(not view.import_source("{}") and view.document.to_json() == normalized and view.timeline_position == accepted_position and view.cover_panel.visible, "failed import preserves linked walkthrough and view")
	_check(view.save_path("user://walkthrough-cover-test.json") and FileAccess.get_file_as_string("user://walkthrough-cover-test.json") == normalized, "viewer saves exact linked walkthrough")
	_check(WalkthroughDocument.parse(FileAccess.get_file_as_string("user://walkthrough-cover-test.json")).document.to_json() == normalized, "saved linked walkthrough reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough-cover-test.json"))
	for viewport in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = viewport
		root.content_scale_size = viewport
		for frame in 4: await process_frame
		_check(view.cover_grid.columns == (1 if viewport.x < 900 else 2), "linked surface endpoints adapt columns at %s" % viewport)
		_check(view.cover_grid.get_global_rect().end.x <= viewport.x + 1, "linked surface endpoints do not overflow horizontally at %s" % viewport)
	_check(view.import_source(plain_source) and not view.cover_panel.visible and view.cover_before_view.document == null and view.cover_after_view.document == null, "steps without links hide and clear exploratory views")
	view.queue_free()
	await process_frame
	print("WALKTHROUGH COVER: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
