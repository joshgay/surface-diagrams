class_name PythonGeometryBridge
extends RefCounted

const MAX_RENDER_BYTES := 4 * 1024 * 1024

static func render(document: DiagramDocument) -> Dictionary:
	var cache_dir := ProjectSettings.globalize_path("user://geometry-preview")
	var directory_error := DirAccess.make_dir_recursive_absolute(cache_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create the local geometry cache")
	var input_path := cache_dir.path_join("recipe.json")
	var svg_path := cache_dir.path_join("diagram.svg")
	var tikz_path := cache_dir.path_join("diagram.tikz")
	var save_error := document.save_path(input_path)
	if not save_error.is_empty():
		return _failure(save_error)
	var python := OS.get_environment("SURFACE_DIAGRAMS_PYTHON")
	if python.is_empty():
		python = "python3"
	var script := ProjectSettings.globalize_path("res://bridge/render_document.py")
	var output: Array = []
	# OS.execute invokes this fixed trusted script directly. No shell is used and
	# imported records cannot alter the executable, script, or cache paths.
	var code := OS.execute(python, PackedStringArray([script, input_path, svg_path, tikz_path]), output, true)
	if code != 0:
		var detail := str(output[0]).strip_edges() if not output.is_empty() else "no diagnostic"
		return _failure("Python geometry unavailable (exit %d): %s" % [code, detail.left(600)])
	var manifest = JSON.parse_string(str(output[0]).strip_edges()) if not output.is_empty() else null
	if typeof(manifest) != TYPE_DICTIONARY or not manifest.get("ok", false):
		return _failure("Python geometry returned an invalid manifest")
	var svg_result := _read_bounded(svg_path)
	if not svg_result.ok:
		return svg_result
	var tikz_result := _read_bounded(tikz_path)
	if not tikz_result.ok:
		return tikz_result
	if not svg_result.text.begins_with("<svg") or "tikzpicture" not in tikz_result.text:
		return _failure("Python geometry returned unexpected output")
	return {"ok": true, "error": "", "svg": svg_result.text, "tikz": tikz_result.text,
		"manifest": manifest}

static func _read_bounded(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Geometry output was not created")
	if file.get_length() > MAX_RENDER_BYTES:
		return _failure("Geometry output exceeds 4 MiB")
	return {"ok": true, "text": file.get_as_text()}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "svg": "", "tikz": ""}
