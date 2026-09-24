extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profiles := VisualReviewPlan.profiles()
	_check(VisualReviewPlan.FORMAT == "surface-diagrams-studio-visual-review-plan" and VisualReviewPlan.VERSION == 1, "capture plan is explicitly versioned")
	_check(profiles.size() == 3, "capture plan has exactly three fixed viewport profiles")
	_check(profiles.map(func(item): return item.id) == ["desktop", "phone-portrait", "phone-landscape"], "viewport profile order is deterministic")
	_check(profiles.map(func(item): return item.viewport) == [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)], "desktop and phone dimensions are exact")
	_check(VisualReviewPlan.profile("missing").is_empty(), "unknown profile is rejected")
	var cases := VisualReviewPlan.all_cases()
	_check(cases.size() == 12, "three profiles each capture editor and three secondary workspaces")
	var ids: Dictionary = {}
	var workspaces: Dictionary = {}
	for capture_case in cases:
		_check(not ids.has(capture_case.id), "capture ID is unique: " + capture_case.id)
		ids[capture_case.id] = true
		workspaces[capture_case.workspace] = true
		var expected := VisualReviewPlan.profile(capture_case.profile)
		_check(capture_case.viewport == expected.viewport, "capture keeps profile viewport: " + capture_case.id)
		_check(FileAccess.file_exists(capture_case.fixture) and FileAccess.get_sha256(capture_case.fixture).length() == 64, "capture fixture exists and is hashable: " + capture_case.id)
		_check(not capture_case.expected_focus_name.is_empty() and not capture_case.selected_id.is_empty(), "capture records focus and stable selection: " + capture_case.id)
	var workspace_names := workspaces.keys()
	workspace_names.sort()
	_check(workspace_names == ["editor", "factor", "surface", "walkthrough"], "every required workspace is represented")
	_check(VisualReviewPlan.cases_for_profile("missing").is_empty(), "unknown profile has no capture cases")
	var desktop := VisualReviewPlan.cases_for_profile("desktop")
	var portrait := VisualReviewPlan.cases_for_profile("phone-portrait")
	var landscape := VisualReviewPlan.cases_for_profile("phone-landscape")
	_check(desktop[0].editor_panel == "both" and desktop[0].focus_target == "records", "desktop editor captures both panes with record focus")
	_check(portrait[0].editor_panel == "diagram" and portrait[0].focus_target == "canvas", "portrait editor captures the diagram pane with canvas focus")
	_check(landscape[0].editor_panel == "records" and landscape[0].focus_target == "records", "landscape editor captures the records pane with list focus")
	_check(portrait[2].content_target == "surface-3d" and landscape[2].content_target == "surface-2d", "phone surface captures cover both linked views")
	_check(portrait[3].content_target == "after" and landscape[3].content_target == "before", "phone walkthrough captures cover both complete endpoints")
	_check(desktop[1].timeline_position == 2.5 and desktop[1].selected_id == "b", "factor capture fixes a fractional supplied braid position")
	_check(desktop[3].fixture.ends_with("signed-braid-v1.json") and desktop[3].selected_id == "negative-two", "walkthrough capture exercises the negative signed block")
	print("VISUAL REVIEW PLAN %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
