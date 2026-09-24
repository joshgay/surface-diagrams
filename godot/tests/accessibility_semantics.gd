extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	_check(studio.status_label.get_accessibility_live() == AccessibilityServer.LIVE_POLITE, "editor status is a polite live region")
	_check(_controls(studio.mobile_tab_buttons[0], studio.canvas_box) and _controls(studio.mobile_tab_buttons[1], studio.inspector_scroll), "compact editor tabs identify their controlled panes")
	_check(_controls(studio.source_button, studio.source_view), "editor source toggle identifies the exact source field it controls")
	_check("Planar diagram loaded" in studio.canvas.get_accessibility_description() and "No mathematical record selected" in studio.canvas.get_accessibility_description(), "diagram canvas describes its loaded kind and empty selection")
	var first_record: Dictionary = studio.document.inspector_records()[0]
	studio.canvas.select_record(first_record)
	_check(first_record.label in studio.canvas.get_accessibility_description(), "diagram canvas exposes the exact selected inspector record")
	var accepted: String = studio.document.to_json()
	studio.status_label.text = "Selection changed for accessibility test."
	_check(studio.status_label.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and studio.document.to_json() == accepted, "live editor feedback remains view state only")

	var braid_canvas := DiagramCanvas.new()
	braid_canvas.read_only = true
	root.add_child(braid_canvas)
	await process_frame
	var braid: DiagramDocument = DiagramDocument.load_path("res://fixtures/braid-v1.json").document
	braid_canvas.set_document(braid)
	var crossing: Dictionary = braid.inspector_records()[3]
	braid_canvas.select_record(crossing)
	braid_canvas.set_braid_view(2.5, "top-to-bottom")
	var braid_description := braid_canvas.get_accessibility_description()
	_check(crossing.label in braid_description and "top to bottom presentation" in braid_description and "2.500 of 5 literal crossings" in braid_description, "braid canvas describes literal crossing, presentation, and playhead")
	_check("linked view is read only" in braid_description and braid.to_json() == DiagramDocument.load_path("res://fixtures/braid-v1.json").document.to_json(), "read-only context is announced without changing the braid record")
	braid_canvas.set_document(null)
	_check("No diagram is loaded" in braid_canvas.get_accessibility_description() and "Selected" not in braid_canvas.get_accessibility_description(), "clearing a canvas also clears stale accessible selection context")

	var factor := FactorWorkspaceView.new()
	factor.browser_mode = true
	root.add_child(factor)
	await process_frame
	_check(factor.import_source(FileAccess.get_file_as_string("res://fixtures/workspaces/grouped-v1.json")), "factor fixture loads for accessibility semantics")
	_check(factor.message.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and _controls(factor.source_button, factor.source), "factor status and source control expose assistive semantics")
	for index in factor.view_tab_buttons.size():
		_check(_controls(factor.view_tab_buttons[index], factor.view_columns[index]), "factor view tab %d identifies its controlled linked column" % index)
	factor.select_factor(2)
	var support_curve: Dictionary = factor.support_canvas.document.inspector_records().filter(func(record): return record.kind == "curve")[0]
	factor.support_canvas.select_record(support_curve)
	_check(support_curve.label in factor.support_canvas.get_accessibility_description() and factor.workspace.to_json() == FactorWorkspace.parse(FileAccess.get_file_as_string("res://fixtures/workspaces/grouped-v1.json")).workspace.to_json(), "factor support canvas exposes its exact curve selection without changing workspace JSON")

	var surface := SurfaceWorkspaceView.new()
	surface.browser_mode = true
	root.add_child(surface)
	await process_frame
	_check(surface.import_source(FileAccess.get_file_as_string(SurfaceWorkspaceView.FIXTURE)), "surface fixture loads for accessibility semantics")
	_check(surface.status.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and _controls(surface.source_button, surface.source), "surface status and source control expose assistive semantics")
	for index in surface.view_tab_buttons.size():
		_check(_controls(surface.view_tab_buttons[index], surface.view_columns[index]), "surface view tab %d identifies its controlled linked column" % index)
	var surface_source := surface.document.to_json()
	surface.select_id("arc1")
	_check("Selected curve arc1" in surface.surface_3d.get_accessibility_description() and "Selected Arc  arc1" in surface.canvas_2d.get_accessibility_description(), "linked 2D and 3D views expose the same stable curve selection")
	surface._hide_selected()
	_check("1 records hidden" in surface.surface_3d.get_accessibility_description() and surface.document.to_json() == surface_source, "3D visibility status is announced without changing supplied geometry")
	surface.surface_3d.set_orientation_labels_visible(false)
	_check("Orientation labels hidden" in surface.surface_3d.get_accessibility_description(), "3D orientation-label state is available to assistive technology")

	var walkthrough := WalkthroughView.new()
	walkthrough.browser_mode = true
	root.add_child(walkthrough)
	await process_frame
	_check(walkthrough.import_source(FileAccess.get_file_as_string(WalkthroughView.COVER_FIXTURE)), "linked walkthrough loads for accessibility semantics")
	_check(walkthrough.status.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and _controls(walkthrough.source_button, walkthrough.source), "walkthrough status and source control expose assistive semantics")
	for index in walkthrough.endpoint_columns.size():
		_check(_controls(walkthrough.view_tab_buttons[index], walkthrough.endpoint_columns[index]), "walkthrough 2D tab %d identifies its controlled endpoint" % index)
	for index in walkthrough.cover_columns.size():
		_check(_controls(walkthrough.view_tab_buttons[index + 2], walkthrough.cover_columns[index]), "walkthrough 3D tab %d identifies its controlled supplied endpoint" % index)
	var walkthrough_source := walkthrough.document.to_json()
	walkthrough._record_selected({"kind": "curve", "id": "arc1"})
	_check("Selected Arc  arc1" in walkthrough.before_canvas.get_accessibility_description() and "Selected curve arc1" in walkthrough.cover_after_view.get_accessibility_description(), "walkthrough endpoints announce the shared stable selection")
	_check(walkthrough.document.to_json() == walkthrough_source, "accessibility context leaves the supplied walkthrough byte-identical")

	walkthrough.queue_free()
	surface.queue_free()
	factor.queue_free()
	braid_canvas.queue_free()
	studio.queue_free()
	await process_frame
	print("ACCESSIBILITY SEMANTICS %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _controls(controller: Control, target: Control) -> bool:
	var paths := controller.get_accessibility_controls_nodes()
	return paths.size() == 1 and controller.get_node_or_null(paths[0]) == target

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
