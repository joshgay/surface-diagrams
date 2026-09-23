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
	var bottom_up: bool = presentation == "bottom-to-top"
	var upper_left_over_upper_right: bool = generator > 0
	var over_slot: int = (left + 1 if bottom_up else left) if upper_left_over_upper_right else (left if bottom_up else left + 1)
	return {"ok": true, "generator": generator, "before": before.duplicate(),
		"after": states[index + 1].duplicate(), "over_id": before[over_slot],
		"left_id": before[left], "right_id": before[left + 1],
		"upper_left_over_upper_right": upper_left_over_upper_right}
