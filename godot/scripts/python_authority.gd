class_name PythonAuthority
extends RefCounted

const ALLOWED_SCRIPTS := ["render_document.py", "build_walkthrough_bundle.py"]

static func resolve_script(name: String) -> Dictionary:
	if name not in ALLOWED_SCRIPTS:
		return _failure("Unsupported Python authority adapter: " + name)
	var configured := OS.get_environment("SURFACE_DIAGRAMS_AUTHORITY_ROOT").strip_edges()
	if not configured.is_empty():
		var explicit := configured.path_join(name)
		if FileAccess.file_exists(explicit):
			return {"ok": true, "path": explicit, "source": "configured"}
		return _failure("Configured Python authority is incomplete: missing " + explicit)
	var packaged := OS.get_executable_path().get_base_dir().path_join("authority").path_join(name)
	if FileAccess.file_exists(packaged):
		return {"ok": true, "path": packaged, "source": "packaged"}
	var development := ProjectSettings.globalize_path("res://bridge/" + name)
	if FileAccess.file_exists(development):
		return {"ok": true, "path": development, "source": "source-checkout"}
	return _failure("Packaged Python authority is unavailable. Expected authority/%s next to the Studio executable, or set SURFACE_DIAGRAMS_AUTHORITY_ROOT to a trusted installed authority directory." % name)

static func python_executable() -> String:
	var configured := OS.get_environment("SURFACE_DIAGRAMS_PYTHON").strip_edges()
	return configured if not configured.is_empty() else "python3"

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "path": "", "source": "unavailable", "error": message}
