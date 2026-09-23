class_name FactorTimeline
extends RefCounted

const SECONDS_PER_CROSSING := 0.6

# Position is measured in factor stages, not crossings. Thus every factor owns
# [index,index+1], including an explicit empty braid block. This is view state;
# the mathematical workspace remains unchanged.
static func sample(workspace: FactorWorkspace, position: float,
		direction: String = "") -> Dictionary:
	if workspace == null or not is_finite(position):
		return {"ok": false, "error": "A workspace and finite factor position are required"}
	var data := workspace.to_dict()
	if direction.is_empty(): direction = data.direction
	if direction not in ["bottom-to-top", "top-to-bottom"]:
		return {"ok": false, "error": "Unknown braid presentation"}
	var count: int = data.factors.size()
	if count == 0:
		return {"ok": true, "position": 0.0, "factor_index": -1,
			"local": 0.0, "braid_time": 0.0, "direction": direction,
			"braid": BraidTimeline.sample(workspace.braid_document(), 0.0, direction)}
	var value := clampf(position, 0.0, float(count))
	if absf(value - roundf(value)) < 1e-9: value = roundf(value)
	var index := mini(floori(value), count - 1)
	var local := 1.0 if value == count else value - index
	var focus := workspace.focus(index)
	var braid_time: float = focus.start + local * (focus.end - focus.start)
	return {"ok": true, "position": value, "factor_index": index,
		"local": local, "braid_time": braid_time, "direction": direction,
		"focus": focus, "braid": BraidTimeline.sample(workspace.braid_document(), braid_time, direction)}

static func duration(workspace: FactorWorkspace, index: int) -> float:
	var focus := workspace.focus(index) if workspace != null else {}
	if focus.is_empty(): return 0.0
	# Empty blocks receive one crossing-duration hold so they remain observable.
	return maxf(1.0, focus.end - focus.start) * SECONDS_PER_CROSSING

# Advance across arbitrary frame partitions without skipping zero-word factors.
# Long frames may traverse multiple factors; each boundary remains exact.
static func advance(workspace: FactorWorkspace, position: float, seconds: float) -> float:
	if workspace == null or not is_finite(position) or not is_finite(seconds) or seconds <= 0.0:
		return position
	var count: int = workspace.to_dict().factors.size()
	var value := clampf(position, 0.0, float(count))
	var remaining := seconds
	while remaining > 1e-12 and value < count:
		var index := mini(floori(value), count - 1)
		var local := value - index
		var span := duration(workspace, index)
		var to_boundary := (1.0 - local) * span
		if remaining + 1e-12 < to_boundary:
			value += remaining / span
			remaining = 0.0
		else:
			value = float(index + 1)
			remaining -= to_boundary
	if absf(value - roundf(value)) < 1e-9: value = roundf(value)
	return clampf(value, 0.0, float(count))
