class_name SurfaceViewDocument
extends RefCounted

const FORMAT := "surface-diagrams-surface-view"
const STATUS := "exploratory-supplied-geometry"
const MAX_CURVE_POINTS := 256
var _data: Dictionary

func _init(value: Dictionary) -> void:
	_data = value.duplicate(true)

static func parse(source: String) -> Dictionary:
	if source.to_utf8_buffer().size() > DiagramDocument.MAX_BYTES:
		return DiagramDocument._failure("Surface view exceeds 256 KiB")
	var json := JSON.new()
	if json.parse(source) != OK:
		return DiagramDocument._failure("Invalid surface-view JSON")
	if not DiagramDocument._duplicate_field(source).is_empty():
		return DiagramDocument._failure("Duplicate surface-view JSON field")
	var raw = json.data
	var fields := ["format", "version", "title", "status", "planar", "surface", "objects", "curves"]
	var check := DiagramDocument._keys(raw, fields, fields, "surface view")
	if not check.ok: return check
	if raw.format != FORMAT or not DiagramDocument._integer(raw.version) or raw.version != 1:
		return DiagramDocument._failure("Expected surface-view version 1")
	if raw.status != STATUS:
		return DiagramDocument._failure("Surface view must be labeled exploratory-supplied-geometry")
	check = DiagramDocument._text(raw.title, "surface-view title", 120)
	if not check.ok: return check
	var planar_result := DiagramDocument.parse(JSON.stringify(raw.planar))
	if not planar_result.ok: return planar_result
	var planar: DiagramDocument = planar_result.document
	if planar.data.kind != "planar":
		return DiagramDocument._failure("Linked diagram must be planar")
	check = DiagramDocument._keys(raw.surface, ["kind", "radius", "thickness", "color", "orientation"],
		["kind", "radius", "thickness", "color", "orientation"], "surface")
	if not check.ok: return check
	if raw.surface.kind != "disk":
		return DiagramDocument._failure("Version 1 supports only the generic disk surface")
	if not DiagramDocument._number_between(raw.surface.radius, 0.5, 100.0) or not DiagramDocument._number_between(raw.surface.thickness, 0.02, 5.0):
		return DiagramDocument._failure("Disk radius/thickness are outside supported bounds")
	if not DiagramDocument._color(raw.surface.color):
		return DiagramDocument._failure("Surface color must be literal")
	if raw.surface.orientation != "front-is-positive-z":
		return DiagramDocument._failure("Disk orientation must be front-is-positive-z")
	var planar_data := planar.data
	if typeof(raw.objects) != TYPE_ARRAY or raw.objects.size() != planar_data.surface.objects.size():
		return DiagramDocument._failure("3D objects must match every planar object exactly")
	var normalized_objects: Array = []
	var positions := {}
	for index in raw.objects.size():
		var object = raw.objects[index]
		check = DiagramDocument._keys(object, ["id", "position"], ["id", "position"], "objects[%d]" % index)
		if not check.ok: return check
		if positions.has(object.id): return DiagramDocument._failure("3D object IDs must be distinct")
		var position_result := _point(object.position, "object position")
		if not position_result.ok: return position_result
		positions[object.id] = position_result.value
		normalized_objects.append({"id": object.id, "position": position_result.value})
	var planar_object_ids: Array = planar_data.surface.objects.map(func(object): return object.id)
	if normalized_objects.map(func(object): return object.id) != planar_object_ids:
		return DiagramDocument._failure("3D objects must preserve the planar object ID order")
	if typeof(raw.curves) != TYPE_ARRAY or raw.curves.size() != planar_data.curves.size():
		return DiagramDocument._failure("3D curves must match every planar curve exactly")
	var normalized_curves: Array = []
	for index in raw.curves.size():
		var curve = raw.curves[index]
		check = DiagramDocument._keys(curve, ["id", "closed", "points"], ["id", "closed", "points"], "curves[%d]" % index)
		if not check.ok: return check
		var planar_curve: Dictionary = planar_data.curves[index]
		if curve.id != planar_curve.id:
			return DiagramDocument._failure("3D curves must preserve the planar curve ID order")
		if typeof(curve.closed) != TYPE_BOOL or curve.closed != (planar_curve.kind == "loop"):
			return DiagramDocument._failure("3D curve closure must match arc/loop kind")
		if typeof(curve.points) != TYPE_ARRAY or curve.points.size() < 2 or curve.points.size() > MAX_CURVE_POINTS:
			return DiagramDocument._failure("3D curve needs 2..256 supplied points")
		var points: Array = []
		for raw_point in curve.points:
			var point_result := _point(raw_point, "curve point")
			if not point_result.ok: return point_result
			points.append(point_result.value)
		if curve.closed:
			if not _same_point(points.front(), points.back()):
				return DiagramDocument._failure("A supplied loop polyline must close exactly")
		else:
			# This first slice supports internal endpoints only. Their supplied 3D
			# coordinates must equal the linked stable objects; no endpoint is guessed.
			if planar_curve.start < 1 or planar_curve.start > normalized_objects.size() or planar_curve.end < 1 or planar_curve.end > normalized_objects.size():
				return DiagramDocument._failure("Exploratory arc endpoints must name linked objects")
			if not _same_point(points.front(), positions[planar_object_ids[planar_curve.start - 1]]) or not _same_point(points.back(), positions[planar_object_ids[planar_curve.end - 1]]):
				return DiagramDocument._failure("Supplied 3D arc endpoints must equal linked object positions")
		normalized_curves.append({"id": curve.id, "closed": curve.closed, "points": points})
	var normalized := {"format": FORMAT, "version": 1, "title": raw.title,
		"status": STATUS, "planar": planar.to_dict(),
		"surface": {"kind": "disk", "radius": float(raw.surface.radius),
			"thickness": float(raw.surface.thickness), "color": raw.surface.color,
			"orientation": raw.surface.orientation},
		"objects": normalized_objects, "curves": normalized_curves}
	return {"ok": true, "document": SurfaceViewDocument.new(normalized), "error": ""}

static func _point(value: Variant, where: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return DiagramDocument._failure(where + " must contain exactly three coordinates")
	var normalized: Array = []
	for coordinate in value:
		if not DiagramDocument._number_between(coordinate, -1000.0, 1000.0):
			return DiagramDocument._failure(where + " coordinates must be finite and bounded")
		normalized.append(float(coordinate))
	return {"ok": true, "value": normalized}

static func _same_point(a: Array, b: Array) -> bool:
	return a == b

func to_dict() -> Dictionary:
	return _data.duplicate(true)

func to_json() -> String:
	return JSON.stringify(_data, "\t", false, true) + "\n"

func planar_document() -> DiagramDocument:
	return DiagramDocument.new(_data.planar)

func records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var planar := planar_document().data
	for index in _data.objects.size():
		result.append({"id": _data.objects[index].id, "kind": "object",
			"label": "%s  %s  supplied position %s" % [_data.objects[index].id,
				planar.surface.objects[index].kind, _data.objects[index].position]})
	for index in _data.curves.size():
		result.append({"id": _data.curves[index].id, "kind": "curve",
			"label": "%s  %s  %d supplied 3D points" % [_data.curves[index].id,
				planar.curves[index].kind, _data.curves[index].points.size()]})
	return result
