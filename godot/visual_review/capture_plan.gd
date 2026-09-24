class_name VisualReviewPlan
extends RefCounted

const FORMAT := "surface-diagrams-studio-visual-review-plan"
const VERSION := 1

const _PROFILES := [
	{"id": "desktop", "label": "Desktop 1280x800", "viewport": Vector2i(1280, 800)},
	{"id": "phone-portrait", "label": "Phone portrait 390x844", "viewport": Vector2i(390, 844)},
	{"id": "phone-landscape", "label": "Phone landscape 844x390", "viewport": Vector2i(844, 390)},
]

static func profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for selected_profile in _PROFILES:
		result.append(selected_profile.duplicate(true))
	return result

static func profile(id: String) -> Dictionary:
	for candidate in _PROFILES:
		if candidate.id == id:
			return candidate.duplicate(true)
	return {}

static func cases_for_profile(profile_id: String) -> Array[Dictionary]:
	var selected_profile := profile(profile_id)
	if selected_profile.is_empty():
		return []
	var editor_panel := "both"
	var editor_focus := "records"
	var factor_target := "support"
	var surface_target := "surface-3d"
	var walkthrough_target := "after"
	if profile_id == "phone-portrait":
		editor_panel = "diagram"
		editor_focus = "canvas"
		factor_target = "braid"
		surface_target = "surface-3d"
		walkthrough_target = "after"
	elif profile_id == "phone-landscape":
		editor_panel = "records"
		factor_target = "states"
		surface_target = "surface-2d"
		walkthrough_target = "before"
	var viewport: Vector2i = selected_profile.viewport
	var result: Array[Dictionary] = [
		{
			"id": profile_id + "-editor",
			"profile": profile_id,
			"viewport": viewport,
			"workspace": "editor",
			"fixture": "res://fixtures/multi-curve-v1.json",
			"selected_id": "editable",
			"timeline_position": 0.0,
			"editor_panel": editor_panel,
			"content_target": editor_panel,
			"focus_target": editor_focus,
			"expected_focus_name": "Editable diagram canvas" if editor_focus == "canvas" else "Mathematical records",
		},
		{
			"id": profile_id + "-factor",
			"profile": profile_id,
			"viewport": viewport,
			"workspace": "factor",
			"fixture": "res://fixtures/workspaces/grouped-v1.json",
			"selected_id": "b",
			"timeline_position": 2.5,
			"editor_panel": "not-applicable",
			"content_target": factor_target,
			"focus_target": "content",
			"expected_focus_name": "Continuous supplied factor braid" if factor_target == "braid" else ("Supplied factor before-state diagram" if factor_target == "states" else "Selected factor support diagram"),
		},
		{
			"id": profile_id + "-surface",
			"profile": profile_id,
			"viewport": viewport,
			"workspace": "surface",
			"fixture": "res://fixtures/surfaces/disk-v1.json",
			"selected_id": "arc1",
			"timeline_position": 0.0,
			"editor_panel": "not-applicable",
			"content_target": surface_target,
			"focus_target": "content",
			"expected_focus_name": "Linked exploratory three dimensional view" if surface_target == "surface-3d" else "Linked two dimensional recipe",
		},
		{
			"id": profile_id + "-walkthrough",
			"profile": profile_id,
			"viewport": viewport,
			"workspace": "walkthrough",
			"fixture": "res://fixtures/walkthroughs/signed-braid-v1.json",
			"selected_id": "negative-two",
			"timeline_position": 1.5,
			"editor_panel": "not-applicable",
			"content_target": walkthrough_target,
			"focus_target": "content",
			"expected_focus_name": "Complete supplied after-state diagram" if walkthrough_target == "after" else "Complete supplied before-state diagram",
		},
	]
	return result

static func all_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for selected_profile in _PROFILES:
		result.append_array(cases_for_profile(selected_profile.id))
	return result
