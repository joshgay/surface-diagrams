class_name RowReindex
extends RefCounted

static func adjacent(document: DiagramDocument, id: String, offset: int) -> Dictionary:
	if document == null or document.data.kind != "planar":
		return _failure("Row reindexing requires a planar document")
	if offset not in [-1, 1]:
		return _failure("Row reindex offset must be one adjacent slot")
	var data := document.data
	var old_order: Array = []
	var object_kinds := {}
	var source_index := -1
	for index in data.surface.objects.size():
		var object: Dictionary = data.surface.objects[index]
		old_order.append(object.id)
		object_kinds[object.id] = object.kind
		if object.id == id:
			source_index = index
	if source_index < 0:
		return _failure("Unknown object ID: " + id)
	var target_index := source_index + offset
	if target_index < 0 or target_index >= old_order.size():
		return _failure("Object %s is already at that row edge" % id)
	var new_order := old_order.duplicate()
	var neighbor = new_order[target_index]
	new_order[target_index] = id
	new_order[source_index] = neighbor
	var proposal := document.with_object_order(new_order)
	if not proposal.ok:
		return proposal
	var impacts: Array[String] = []
	for index in old_order.size():
		if old_order[index] != new_order[index]:
			impacts.append("slot %d: %s (%s) -> %s (%s)" % [index + 1,
				old_order[index], object_kinds[old_order[index]],
				new_order[index], object_kinds[new_order[index]]])
	for curve in data.curves:
		if curve.kind == "arc":
			for endpoint_name in ["start", "end"]:
				var number: int = curve[endpoint_name]
				var old_identity := _endpoint_identity(old_order, number)
				var new_identity := _endpoint_identity(new_order, number)
				if old_identity != new_identity:
					impacts.append("curve %s %s endpoint %d: %s -> %s" % [curve.id,
						endpoint_name, number, old_identity, new_identity])
		for visit_index in curve.cuts.size():
			var cut: int = curve.cuts[visit_index]
			var old_corridor := _cut_corridor(old_order, cut)
			var new_corridor := _cut_corridor(new_order, cut)
			if old_corridor != new_corridor:
				impacts.append("curve %s cut visit %d at cut %d: %s -> %s" % [curve.id,
					visit_index + 1, cut, old_corridor, new_corridor])
	return {
		"ok": true,
		"error": "",
		"document": proposal.document,
		"old_order": old_order,
		"new_order": new_order,
		"selected_id": id,
		"source_index": source_index,
		"target_index": target_index,
		"impacts": impacts,
		"selection": {"kind": "object", "id": id, "index": target_index},
	}

static func preview_text(proposal: Dictionary) -> String:
	if not proposal.get("ok", false):
		return proposal.get("error", "Invalid row reindex proposal")
	var lines: Array[String] = [
		"Old order: " + str(proposal.old_order),
		"New order: " + str(proposal.new_order),
		"",
		"Endpoint and cut numbers remain literal. The complete changed identity/corridor list is:",
	]
	lines.append_array(proposal.impacts)
	if proposal.impacts.is_empty():
		lines.append("No curve endpoint attachment or cut corridor changes.")
	return "\n".join(lines)

static func _endpoint_identity(order: Array, endpoint: int) -> String:
	if endpoint == 0:
		return "outer-left"
	if endpoint == order.size() + 1:
		return "outer-right"
	return str(order[endpoint - 1])

static func _cut_corridor(order: Array, cut: int) -> String:
	var left := "outer-left" if cut == 0 else str(order[cut - 1])
	var right := "outer-right" if cut == order.size() else str(order[cut])
	return left + " | " + right

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
