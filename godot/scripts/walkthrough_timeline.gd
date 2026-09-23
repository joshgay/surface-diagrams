class_name WalkthroughTimeline
extends RefCounted

static func sample(document: WalkthroughDocument, value: float) -> Dictionary:
	if document == null or not is_finite(value): return {"ok": false, "error": "Invalid walkthrough position"}
	var data := document.to_dict()
	var count: int = data.steps.size()
	if count == 0: return {"ok": false, "error": "Walkthrough has no steps"}
	var position := clampf(value, 0.0, float(count))
	var index := mini(floori(position), count - 1)
	var local := 1.0 if position >= count else position - index
	var step := document.step(index)
	return {"ok": true, "position": position, "step_index": index, "local": local,
		"step": step, "before": document.diagram(step.before), "after": document.diagram(step.after),
		"current_reference": step.after if local >= 1.0 else step.before}

static func advance(document: WalkthroughDocument, position: float, elapsed: float, direction: int) -> float:
	if document == null or not is_finite(position) or not is_finite(elapsed) or elapsed <= 0.0 or direction not in [-1, 1]:
		return position
	return clampf(position + elapsed * direction, 0.0, float(document.to_dict().steps.size()))
