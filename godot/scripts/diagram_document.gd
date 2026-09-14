class_name DiagramDocument
extends RefCounted

const MAX_BYTES := 256 * 1024
const MAX_OBJECTS := 32
const MAX_CURVES := 16
const MAX_CUTS := 64
const MAX_WORD := 128
const MAX_LABELS := 32
const ID_PATTERN := "^[A-Za-z][A-Za-z0-9_-]{0,39}$"
const COLORS := ["#d73027", "#e08214", "#b59b00", "#23964f", "#168aad", "#5254c8", "#973aa8"]
const STYLE_DEFAULTS := {
	"boundary_radius": 4.0, "marked_point_radius": 4.0,
	"boundary_color": "#8b8b8b", "marked_point_color": "#006fff",
	"outline_color": "#000000", "outline_width": 1.5,
	"background": null, "padding": 12.0, "show_outer_ellipse": true,
	"curve_color": "#ff00d4", "curve_width": 2.0,
	"curve_height": 0.85, "show_guides": false, "boundary_shape": "dot"
}

var _data: Dictionary
var data: Dictionary:
	get:
		return _data.duplicate(true)

func _init(normalized: Dictionary) -> void:
	_data = normalized.duplicate(true)

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Document exceeds 256 KiB")
	var parser := JSON.new()
	var code := parser.parse(text)
	if code != OK:
		return _failure("Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("Document must be a JSON object")
	var duplicate := _duplicate_field(text)
	if not duplicate.is_empty():
		return _failure("Duplicate JSON field: " + duplicate)
	var normalized := _normalize(parser.data)
	if not normalized.ok:
		return normalized
	return {"ok": true, "document": DiagramDocument.new(normalized.data), "error": ""}

static func load_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not open %s" % path)
	if file.get_length() > MAX_BYTES:
		return _failure("Document exceeds 256 KiB")
	return parse(file.get_as_text())

func to_dict() -> Dictionary:
	return _data.duplicate(true)

func to_json() -> String:
	return JSON.stringify(_data, "\t", false, true) + "\n"

func save_path(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Could not write %s" % path
	file.store_string(to_json())
	return ""

func with_object_x(id: String, x: float) -> Dictionary:
	if _data.kind != "planar":
		return _failure("Only planar documents contain movable objects")
	if not is_finite(x):
		return _failure("Object x must be finite")
	var candidate := to_dict()
	for index in candidate.surface.objects.size():
		if candidate.surface.objects[index].id == id:
			if is_equal_approx(candidate.surface.objects[index].x, x):
				return _failure("Object %s has not moved" % id)
			candidate.surface.objects[index].x = x
			return DiagramDocument.parse(JSON.stringify(candidate))
	return _failure("Unknown object ID: " + id)

func with_label_position(id: String, position: Vector2) -> Dictionary:
	if not is_finite(position.x) or not is_finite(position.y):
		return _failure("Label position must be finite")
	var candidate := to_dict()
	for index in candidate.labels.size():
		if candidate.labels[index].id == id:
			if is_equal_approx(candidate.labels[index].x, position.x) and is_equal_approx(candidate.labels[index].y, position.y):
				return _failure("Label %s has not moved" % id)
			candidate.labels[index].x = position.x
			candidate.labels[index].y = position.y
			return DiagramDocument.parse(JSON.stringify(candidate))
	return _failure("Unknown label ID: " + id)

func with_curve_cuts(id: String, cuts: Array) -> Dictionary:
	if _data.kind != "planar":
		return _failure("Only planar documents contain editable curve itineraries")
	var candidate := to_dict()
	for index in candidate.curves.size():
		if candidate.curves[index].id == id:
			if candidate.curves[index].cuts == cuts:
				return _failure("Curve %s already has that exact cut itinerary" % id)
			candidate.curves[index].cuts = cuts.duplicate(true)
			return DiagramDocument.parse(JSON.stringify(candidate))
	return _failure("Unknown curve ID: " + id)

func summary_rows() -> Array[String]:
	var rows: Array[String] = []
	for record in inspector_records():
		rows.append(record.label)
	return rows

func inspector_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if _data.kind == "planar":
		for index in _data.surface.objects.size():
			var object: Dictionary = _data.surface.objects[index]
			records.append({"kind": "object", "id": object.id, "index": index,
				"label": "Object %d  %s  %s  x=%s" % [index + 1, object.id, object.kind, object.x]})
		for index in _data.curves.size():
			var curve: Dictionary = _data.curves[index]
			if curve.kind == "arc":
				records.append({"kind": "curve", "id": curve.id, "index": index,
					"label": "Arc  %s  %d -> %d  cuts=%s" % [curve.id, curve.start, curve.end, curve.cuts]})
			else:
				records.append({"kind": "curve", "id": curve.id, "index": index,
					"label": "Loop  %s  cuts=%s" % [curve.id, curve.cuts]})
	else:
		records.append({"kind": "braid", "id": "", "index": -1,
			"label": "%d strands  %d crossings" % [_data.braid.strands, _data.braid.word.size()]})
		var order: Array = range(1, _data.braid.strands + 1)
		for index in _data.braid.word.size():
			var generator: int = _data.braid.word[index]
			var before := order.duplicate()
			var left: int = abs(generator) - 1
			var swap = order[left]
			order[left] = order[left + 1]
			order[left + 1] = swap
			records.append({"kind": "crossing", "id": "", "index": index,
				"label": "%d. %s%d  entry %s  exit %s" % [index + 1, "+" if generator > 0 else "", generator, before, order]})
	for index in _data.labels.size():
		var label: Dictionary = _data.labels[index]
		records.append({"kind": "label", "id": label.id, "index": index,
			"label": "Label  %s  %s" % [label.id, label.text]})
	return records

static func _normalize(raw: Dictionary) -> Dictionary:
	var check := _keys(raw, ["format", "version", "kind", "title", "style", "labels", "surface", "curves", "allow_intersections", "braid"], ["format", "version", "kind"], "document")
	if not check.ok: return check
	if raw.format != "surface-diagrams" or not _integer(raw.version) or int(raw.version) != 1:
		return _failure("Expected surface-diagrams document version 1")
	if raw.kind not in ["planar", "braid"]:
		return _failure("kind must be planar or braid")
	if raw.kind == "planar" and not raw.has("surface"):
		return _failure("Planar document is missing surface")
	if raw.kind == "braid" and not raw.has("braid"):
		return _failure("Braid document is missing braid")
	if (raw.kind == "planar" and raw.has("braid")) or (raw.kind == "braid" and (raw.has("surface") or raw.has("curves") or raw.has("allow_intersections"))):
		return _failure("Document contains fields for the other diagram kind")
	var title_result := _text(raw.get("title", "Untitled diagram"), "title", 120)
	if not title_result.ok: return title_result
	var result := {"format": "surface-diagrams", "version": 1, "kind": raw.kind, "title": title_result.value}
	var style_result := _style(raw.get("style", {}))
	if not style_result.ok: return style_result
	result.style = style_result.value
	var labels_result := _labels(raw.get("labels", []))
	if not labels_result.ok: return labels_result
	result.labels = labels_result.value
	if raw.kind == "planar":
		var planar := _planar(raw, result.style)
		if not planar.ok: return planar
		result.merge(planar.value)
	else:
		var braid := _braid(raw.braid)
		if not braid.ok: return braid
		result.braid = braid.value
	return {"ok": true, "data": result}

static func _style(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY: return _failure("style must be an object")
	var check := _keys(raw, STYLE_DEFAULTS.keys(), [], "style")
	if not check.ok: return check
	var result := STYLE_DEFAULTS.duplicate(true)
	result.merge(raw, true)
	if not raw.has("boundary_radius") or result.boundary_radius == null:
		result.boundary_radius = 12.0 if result.boundary_shape == "circle" else 4.0
	if result.boundary_shape not in ["dot", "circle"]:
		return _failure("style.boundary_shape must be dot or circle")
	for key in ["boundary_radius", "marked_point_radius", "outline_width", "curve_width"]:
		if not _number_between(result[key], 0.000001, 200.0): return _failure("style.%s must be a positive bounded number" % key)
	for key in ["padding", "curve_height"]:
		if not _number_between(result[key], 0.0, 200.0): return _failure("style.%s must be a bounded nonnegative number" % key)
	if result.curve_height > 1.0: return _failure("style.curve_height must be at most 1")
	if typeof(result.show_outer_ellipse) != TYPE_BOOL or typeof(result.show_guides) != TYPE_BOOL:
		return _failure("style visibility flags must be boolean")
	for key in ["boundary_color", "marked_point_color", "outline_color", "curve_color"]:
		if not _color(result[key]): return _failure("style.%s must be a #RGB or #RRGGBB color" % key)
	if result.background != null and not _color(result.background): return _failure("style.background must be null or a literal color")
	return {"ok": true, "value": result}

static func _labels(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_ARRAY or raw.size() > MAX_LABELS: return _failure("labels must contain at most 32 records")
	var result: Array = []
	var ids := {}
	for index in raw.size():
		var label = raw[index]
		var check := _keys(label, ["id", "text", "x", "y", "color", "size"], ["id", "text", "x", "y"], "labels[%d]" % index)
		if not check.ok: return check
		var id_result := _record_id(label.id, "label ID")
		if not id_result.ok: return id_result
		if ids.has(label.id): return _failure("Label IDs must be distinct")
		ids[label.id] = true
		var text_result := _text(label.text, "label text", 120)
		if not text_result.ok: return text_result
		if not _number_between(label.x, -10000.0, 10000.0) or not _number_between(label.y, -10000.0, 10000.0): return _failure("Label coordinates must be finite and bounded")
		var color = label.get("color", "#000000")
		if not _color(color): return _failure("Label color must be literal")
		var size = label.get("size", 12.0)
		if not _number_between(size, 1.0, 48.0): return _failure("Label size must be 1..48")
		result.append({"id": label.id, "text": label.text, "x": float(label.x), "y": float(label.y), "color": color, "size": float(size)})
	return {"ok": true, "value": result}

static func _planar(raw: Dictionary, style: Dictionary) -> Dictionary:
	var surface = raw.surface
	var check := _keys(surface, ["width", "height", "objects"], ["width", "height", "objects"], "surface")
	if not check.ok: return check
	if not _number_between(surface.width, 20.0, 5000.0) or not _number_between(surface.height, 20.0, 5000.0): return _failure("Surface dimensions must be 20..5000")
	if typeof(surface.objects) != TYPE_ARRAY or surface.objects.size() > MAX_OBJECTS: return _failure("surface.objects must contain at most 32 records")
	var objects: Array = []
	var ids := {}
	var previous_x := -INF
	for index in surface.objects.size():
		var object = surface.objects[index]
		check = _keys(object, ["id", "kind", "x", "y", "radius"], ["id", "kind", "x"], "surface.objects[%d]" % index)
		if not check.ok: return check
		var id_result := _record_id(object.id, "object ID")
		if not id_result.ok: return id_result
		if ids.has(object.id): return _failure("Object IDs must be distinct")
		ids[object.id] = true
		if object.kind not in ["point", "boundary"]: return _failure("Object kind must be point or boundary")
		if not _number_between(object.x, -10000.0, 10000.0) or not _number_between(object.get("y", 0), 0.0, 0.0): return _failure("Planar objects must be bounded and on y=0")
		if absf(float(object.x)) >= float(surface.width) / 2.0: return _failure("Every planar object must remain strictly inside the outer ellipse")
		if float(object.x) <= previous_x: return _failure("Objects must remain strictly left-to-right; reordering would renumber endpoints and cuts")
		previous_x = float(object.x)
		var radius = object.get("radius", null)
		if radius != null and not _number_between(radius, 0.1, 200.0): return _failure("Object radius must be null or 0.1..200")
		objects.append({"id": object.id, "kind": object.kind, "x": float(object.x), "y": 0.0, "radius": radius})
	var curves_raw = raw.get("curves", [])
	if typeof(curves_raw) != TYPE_ARRAY or curves_raw.size() > MAX_CURVES: return _failure("curves must contain at most 16 records")
	var curves: Array = []
	ids.clear()
	for index in curves_raw.size():
		var curve = curves_raw[index]
		if typeof(curve) != TYPE_DICTIONARY or curve.get("kind", "") not in ["arc", "loop"]: return _failure("curves[%d].kind must be arc or loop" % index)
		var arc: bool = curve.kind == "arc"
		var allowed := ["id", "kind", "color", "cuts", "start", "end", "direction", "start_side", "end_side"] if arc else ["id", "kind", "color", "cuts", "start_up"]
		var required := ["id", "kind", "start", "end"] if arc else ["id", "kind", "cuts"]
		check = _keys(curve, allowed, required, "curves[%d]" % index)
		if not check.ok: return check
		var id_result := _record_id(curve.id, "curve ID")
		if not id_result.ok: return id_result
		if ids.has(curve.id): return _failure("Curve IDs must be distinct")
		ids[curve.id] = true
		var cuts = curve.get("cuts", [])
		if typeof(cuts) != TYPE_ARRAY or cuts.size() > MAX_CUTS: return _failure("Curve cuts must contain at most 64 integers")
		var normalized_cuts: Array = []
		for cut in cuts:
			if not _integer(cut) or int(cut) < 0 or int(cut) > objects.size(): return _failure("Curve cut is outside 0..n")
			if not normalized_cuts.is_empty() and normalized_cuts.back() == int(cut): return _failure("Consecutive equal cuts are nonminimal")
			normalized_cuts.append(int(cut))
		var color = curve.get("color", style.curve_color)
		if not _color(color): return _failure("Curve color must be literal")
		var normalized := {"id": curve.id, "kind": curve.kind, "cuts": normalized_cuts, "color": color}
		if arc:
			if not _integer(curve.start) or not _integer(curve.end) or int(curve.start) < 0 or int(curve.start) > objects.size() + 1 or int(curve.end) < 0 or int(curve.end) > objects.size() + 1: return _failure("Arc endpoint is outside 0..n+1")
			if int(curve.start) == int(curve.end): return _failure("An arc needs distinct endpoints; use a loop for a closed curve")
			if not normalized_cuts.is_empty() and (normalized_cuts[0] in [int(curve.start) - 1, int(curve.start)] or normalized_cuts[-1] in [int(curve.end) - 1, int(curve.end)]): return _failure("A terminal cut adjacent to its endpoint is nonminimal")
			var direction = curve.get("direction", "default")
			if direction not in ["default", "up", "down"]: return _failure("Arc direction must be default, up, or down")
			for side in [curve.get("start_side", null), curve.get("end_side", null)]:
				if side != null and side not in ["left", "right"]: return _failure("Arc rim side must be left, right, or null")
			normalized.merge({"start": int(curve.start), "end": int(curve.end), "direction": direction, "start_side": curve.get("start_side", null), "end_side": curve.get("end_side", null)})
		else:
			if typeof(curve.get("start_up", true)) != TYPE_BOOL: return _failure("Loop start_up must be boolean")
			if normalized_cuts.size() < 2 or normalized_cuts.size() % 2 != 0: return _failure("A loop needs a positive even number of cut visits")
			if normalized_cuts[0] == normalized_cuts[-1]: return _failure("Equal first and last loop cuts form a cyclic cancellation")
			normalized.start_up = curve.get("start_up", true)
		curves.append(normalized)
	var intersections = raw.get("allow_intersections", false)
	if typeof(intersections) != TYPE_BOOL: return _failure("allow_intersections must be boolean")
	return {"ok": true, "value": {"surface": {"width": float(surface.width), "height": float(surface.height), "objects": objects}, "curves": curves, "allow_intersections": intersections}}

static func _braid(raw: Variant) -> Dictionary:
	var check := _keys(raw, ["strands", "word", "spacing", "step", "colors", "direction"], ["strands", "word"], "braid")
	if not check.ok: return check
	if not _integer(raw.strands) or int(raw.strands) < 1 or int(raw.strands) > MAX_OBJECTS: return _failure("braid.strands must be an integer from 1 to 32")
	if typeof(raw.word) != TYPE_ARRAY or raw.word.size() > MAX_WORD: return _failure("braid.word must contain at most 128 generators")
	var word: Array = []
	for generator in raw.word:
		if not _integer(generator) or int(generator) == 0 or abs(int(generator)) >= int(raw.strands): return _failure("Each braid generator must be a nonzero signed index smaller than strands")
		word.append(int(generator))
	var colors = raw.get("colors", COLORS)
	if typeof(colors) != TYPE_ARRAY or colors.is_empty() or colors.size() > MAX_OBJECTS: return _failure("braid.colors must contain 1..32 colors")
	for color in colors:
		if not _color(color): return _failure("Braid colors must be literals")
	for key in ["spacing", "step"]:
		if not _number_between(raw.get(key, 40.0 if key == "spacing" else 48.0), 5.0, 300.0): return _failure("braid.%s must be 5..300" % key)
	var direction = raw.get("direction", "bottom-to-top")
	if direction not in ["top-to-bottom", "bottom-to-top"]: return _failure("braid.direction is invalid")
	return {"ok": true, "value": {"strands": int(raw.strands), "word": word, "spacing": float(raw.get("spacing", 40.0)), "step": float(raw.get("step", 48.0)), "colors": colors.duplicate(), "direction": direction}}

static func _keys(value: Variant, allowed: Array, required: Array, where: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _failure("%s must be an object" % where)
	for key in value.keys():
		if key not in allowed: return _failure("%s has unknown field %s" % [where, key])
	for key in required:
		if not value.has(key): return _failure("%s is missing %s" % [where, key])
	return {"ok": true}

static func _record_id(value: Variant, where: String) -> Dictionary:
	if typeof(value) != TYPE_STRING: return _failure("%s is invalid" % where)
	var regex := RegEx.new()
	regex.compile(ID_PATTERN)
	if regex.search(value) == null: return _failure("%s must start with a letter and contain at most 40 safe characters" % where)
	return {"ok": true}

static func _text(value: Variant, where: String, maximum: int) -> Dictionary:
	if typeof(value) != TYPE_STRING or value.length() > maximum or "\n" in value or "\r" in value or "\t" in value:
		return _failure("%s must be single-line text of at most %d characters" % [where, maximum])
	for index in value.length():
		if value.unicode_at(index) < 32: return _failure("%s contains a control character" % where)
	return {"ok": true, "value": value}

static func _integer(value: Variant) -> bool:
	# Godot's JSON parser represents JSON numbers as floats. Accept only finite,
	# integral values here; booleans and numeric strings remain invalid.
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))

static func _number_between(value: Variant, low: float, high: float) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _color(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING: return false
	var regex := RegEx.new()
	regex.compile("^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$")
	return regex.search(value) != null

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _duplicate_field(text: String) -> String:
	# Godot's JSON parser keeps only one value for duplicate keys. Scan valid
	# JSON separately so ambiguous documents are rejected instead of normalized.
	var stack: Array = []
	var index := 0
	while index < text.length():
		var character := text[index]
		if character == "{":
			stack.append({"kind": "object", "keys": {}, "expecting_key": true})
			index += 1
		elif character == "[":
			stack.append({"kind": "array"})
			index += 1
		elif character == "}" or character == "]":
			if not stack.is_empty(): stack.pop_back()
			index += 1
		elif character == ",":
			if not stack.is_empty() and stack[-1].kind == "object": stack[-1].expecting_key = true
			index += 1
		elif character == ":":
			if not stack.is_empty() and stack[-1].kind == "object": stack[-1].expecting_key = false
			index += 1
		elif character == "\"":
			var start := index
			index += 1
			var escaped := false
			while index < text.length():
				var current := text[index]
				if not escaped and current == "\"":
					index += 1
					break
				if not escaped and current == "\\": escaped = true
				else: escaped = false
				index += 1
			if not stack.is_empty() and stack[-1].kind == "object" and stack[-1].expecting_key:
				var key = JSON.parse_string(text.substr(start, index - start))
				if stack[-1].keys.has(key): return str(key)
				stack[-1].keys[key] = true
		else:
			index += 1
	return ""
