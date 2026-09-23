class_name BraidTimeline
extends RefCounted

# Step k is the configuration after the first k literal generators. These
# permutations are computed from the word, without using scene geometry.
static func orders(document: DiagramDocument) -> Array:
	if document == null or document.data.kind != "braid":
		return []
	var braid: Dictionary = document.data.braid
	var current: Array = range(1, int(braid.strands) + 1)
	var states: Array = [current.duplicate()]
	for generator in braid.word:
		var left: int = absi(int(generator)) - 1
		var next: Array = current.duplicate()
		next[left] = current[left + 1]
		next[left + 1] = current[left]
		states.append(next)
		current = next
	return states

static func crossing(document: DiagramDocument, index: int, direction: String = "") -> Dictionary:
	var states := orders(document)
	if states.is_empty() or index < 0 or index >= states.size() - 1:
		return {"ok": false, "error": "No crossing at that index"}
	var generator: int = document.data.braid.word[index]
	var left: int = absi(generator) - 1
	var before: Array = states[index]
	# The upper physical slot depends on presentation direction. The algebraic
	# word, step order, and transported identities stay fixed.
	var presentation: String = document.data.braid.direction if direction.is_empty() else direction
	if presentation not in ["bottom-to-top", "top-to-bottom"]:
		return {"ok": false, "error": "Unknown braid presentation"}
	var upper_left_over_upper_right: bool = generator > 0
	var over_slot := _over_slot(generator, presentation)
	return {"ok": true, "generator": generator, "before": before.duplicate(),
		"after": states[index + 1].duplicate(), "over_id": before[over_slot],
		"left_id": before[left], "right_id": before[left + 1],
		"upper_left_over_upper_right": upper_left_over_upper_right}

static func _over_slot(generator: int, direction: String) -> int:
	var left := absi(generator) - 1
	var bottom_up := direction == "bottom-to-top"
	return (left + 1 if bottom_up else left) if generator > 0 else (left if bottom_up else left + 1)

# Pure schematic sampling: time k is the exact kth prefix, and k+f reveals
# fraction f of the next crossing. Paths are indexed by transported strand ID
# minus one. This never changes the word or asserts a geometric equivalence.
static func sample(document: DiagramDocument, time: float, direction: String = "") -> Dictionary:
	if document == null or document.data.kind != "braid" or not is_finite(time):
		return {"ok": false, "error": "A braid and finite view time are required"}
	var braid: Dictionary = document.data.braid
	var presentation: String = braid.direction if direction.is_empty() else direction
	if presentation not in ["bottom-to-top", "top-to-bottom"]:
		return {"ok": false, "error": "Unknown braid presentation"}
	var playhead := clampf(time, 0.0, braid.word.size())
	if absf(playhead - roundf(playhead)) < 1e-9:
		playhead = roundf(playhead)
	var bottom_up := presentation == "bottom-to-top"
	var height: float = maxi(1, braid.word.size()) * braid.step
	var origin_y := -height / 2.0 if bottom_up else height / 2.0
	var dy: float = braid.step if bottom_up else -braid.step
	var center: float = (braid.strands - 1) / 2.0
	var paths: Array = []
	var order: Array = range(braid.strands)
	for identity in braid.strands:
		paths.append(PackedVector2Array([Vector2((identity - center) * braid.spacing, origin_y)]))
	var crossings: Array = []
	for index in ceili(playhead):
		var generator: int = braid.word[index]
		var left := absi(generator) - 1
		var fraction := minf(1.0, playhead - index)
		var over_id: int = order[_over_slot(generator, presentation)]
		var over_start: Vector2 = paths[over_id][-1]
		var over_end := Vector2.ZERO
		var next_order := order.duplicate()
		for slot in braid.strands:
			var identity: int = order[slot]
			var target: int = left + 1 if slot == left else (left if slot == left + 1 else slot)
			var endpoint := Vector2((target - center) * braid.spacing, origin_y + (index + 1) * dy)
			paths[identity].append(paths[identity][-1].lerp(endpoint, fraction))
			next_order[target] = identity
			if identity == over_id:
				over_end = endpoint
		crossings.append({"index": index, "generator": generator, "over_id": over_id + 1,
			"a": over_start, "b": over_end, "fraction": fraction})
		order = next_order
	if braid.word.is_empty():
		for identity in braid.strands:
			paths[identity].append(Vector2((identity - center) * braid.spacing, origin_y + dy))
	return {"ok": true, "time": playhead, "step": floori(playhead), "paths": paths,
		"crossings": crossings, "direction": presentation}
