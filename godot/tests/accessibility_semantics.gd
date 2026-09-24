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
	_check(studio.reindex_preview.get_accessibility_name() == "Exact reindex impact preview" and "endpoint attachment" in studio.reindex_preview.get_accessibility_description(), "explicit reindex confirmation exposes its exact read-only impact preview")

	var creator: CurveCreator = studio.curve_creator
	creator.start("arc")
	_check(creator.get_accessibility_name() == "New curve editor" and creator.id_edit.get_accessibility_name() == "New curve stable ID", "new-curve form and stable-ID field have explicit names")
	_check(_labeled_by_text(creator.id_edit, "Stable ID") and _labeled_by_text(creator.start_spin, "Start endpoint") and _labeled_by_text(creator.end_spin, "End endpoint"), "new-curve identity and endpoints reference their visible labels")
	_check(_labeled_by_text(creator.direction_option, "Direction") and _labeled_by_text(creator.start_side_option, "Start rim") and _labeled_by_text(creator.end_side_option, "End rim"), "new-curve routing options reference their visible labels")
	_check(creator.warning_label.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and _described_by(creator.create_button, creator.warning_label), "new-curve validation is a polite live description of the commit control")
	_check(_buttons_named_and_touch_sized(creator), "every new-curve action and literal cut button has an explicit name and 44-pixel target")
	creator.id_edit.text = "bad id!"
	creator._id_changed("bad id!")
	_check("reject" in creator.warning_label.text.to_lower() and studio.document.to_json() == accepted, "announced new-curve rejection preserves accepted mathematical JSON")
	creator.cancel()

	var inspector := CurveInspector.new()
	root.add_child(inspector)
	var multi: DiagramDocument = DiagramDocument.load_path("res://fixtures/multi-curve-v1.json").document
	var curve_record: Dictionary = multi.inspector_records().filter(func(record): return record.kind == "curve" and record.id == "editable")[0]
	inspector.inspect(multi, curve_record)
	var multi_source := multi.to_json()
	_check(inspector.get_accessibility_name() == "Exact curve itinerary editor" and inspector.apply_button.get_accessibility_name() == "Apply exact literal cut itinerary", "curve inspector and exact commit control have explicit names")
	_check(inspector.warning_label.get_accessibility_live() == AccessibilityServer.LIVE_POLITE and _described_by(inspector.apply_button, inspector.warning_label), "curve validation is a polite live description of the exact commit control")
	_check(_buttons_named_and_touch_sized(inspector), "every itinerary edit and literal cut button has an explicit name and 44-pixel target")
	inspector.append_cut(inspector.draft_cuts[-1])
	_check("reject" in inspector.warning_label.text.to_lower() and multi.to_json() == multi_source, "announced itinerary rejection preserves accepted mathematical JSON")

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
	var braid_editor := BraidEditor.new()
	root.add_child(braid_editor)
	braid_editor.configure(braid, crossing, true)
	_check(braid_editor.get_accessibility_name() == "Signed braid editor" and braid_editor.index_spin.get_accessibility_name() == "Braid word position" and braid_editor.generator_spin.get_accessibility_name() == "Signed braid generator", "signed-braid edit form and numeric fields have explicit names")
	_check(_labeled_by_text(braid_editor.index_spin, "Position") and _labeled_by_text(braid_editor.generator_spin, "Signed σ"), "signed-braid numeric fields reference their visible labels")
	_check(_described_by(braid_editor.index_spin, braid_editor.edit_note) and _described_by(braid_editor.generator_spin, braid_editor.edit_note), "signed-braid numeric fields reference the no-reduction edit policy")
	_check(braid_editor.direction_option.get_accessibility_name() == "Braid presentation direction" and braid_editor.scrub.get_accessibility_name() == "Braid playback position", "braid presentation and fractional playhead have explicit names")
	_check(_buttons_named_and_touch_sized(braid_editor), "every signed-braid edit and timeline button has an explicit name and 44-pixel target")
	braid_editor.index_spin.value = 2
	_check(braid.to_json() == DiagramDocument.load_path("res://fixtures/braid-v1.json").document.to_json(), "accessible braid form inspection leaves the supplied word byte-identical")
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
	braid_editor.queue_free()
	braid_canvas.queue_free()
	inspector.queue_free()
	studio.queue_free()
	await process_frame
	print("ACCESSIBILITY SEMANTICS %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _controls(controller: Control, target: Control) -> bool:
	var paths := controller.get_accessibility_controls_nodes()
	return paths.size() == 1 and controller.get_node_or_null(paths[0]) == target

func _described_by(control: Control, target: Control) -> bool:
	var paths := control.get_accessibility_described_by_nodes()
	return paths.size() == 1 and control.get_node_or_null(paths[0]) == target

func _labeled_by_text(control: Control, expected: String) -> bool:
	var paths := control.get_accessibility_labeled_by_nodes()
	return paths.size() == 1 and control.get_node_or_null(paths[0]) is Label and control.get_node(paths[0]).text == expected

func _buttons_named_and_touch_sized(node: Node) -> bool:
	for child in node.find_children("*", "BaseButton", true, false):
		if child.get_accessibility_name().is_empty() or child.custom_minimum_size.y < 44:
			return false
	return true

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
