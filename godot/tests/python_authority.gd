extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_root := OS.get_environment("SURFACE_DIAGRAMS_AUTHORITY_ROOT")
	var original_python := OS.get_environment("SURFACE_DIAGRAMS_PYTHON")
	OS.set_environment("SURFACE_DIAGRAMS_AUTHORITY_ROOT", "")
	OS.set_environment("SURFACE_DIAGRAMS_PYTHON", "")
	var render := PythonAuthority.resolve_script("render_document.py")
	var publication := PythonAuthority.resolve_script("build_walkthrough_bundle.py")
	_check(render.ok and render.source == "source-checkout" and render.path.ends_with("bridge/render_document.py"), "source checkout resolves fixed render adapter")
	_check(publication.ok and publication.source == "source-checkout" and publication.path.ends_with("bridge/build_walkthrough_bundle.py"), "source checkout resolves fixed publication adapter")
	_check(not PythonAuthority.resolve_script("other.py").ok, "unlisted adapter name is rejected")
	_check(PythonAuthority.python_executable() == "python3", "default Python executable is explicit")

	var root_path := ProjectSettings.globalize_path("user://authority-test")
	DirAccess.make_dir_recursive_absolute(root_path)
	OS.set_environment("SURFACE_DIAGRAMS_AUTHORITY_ROOT", root_path)
	var missing := PythonAuthority.resolve_script("render_document.py")
	_check(not missing.ok and "Configured Python authority is incomplete" in missing.error, "explicit incomplete authority cannot fall back")
	var render_file := FileAccess.open(root_path.path_join("render_document.py"), FileAccess.WRITE)
	render_file.store_string("# fixed test adapter\n")
	render_file = null
	var configured := PythonAuthority.resolve_script("render_document.py")
	_check(configured.ok and configured.source == "configured" and configured.path == root_path.path_join("render_document.py"), "explicit complete authority wins deterministically")
	var still_missing := PythonAuthority.resolve_script("build_walkthrough_bundle.py")
	_check(not still_missing.ok, "one configured adapter cannot authorize another missing adapter")
	OS.set_environment("SURFACE_DIAGRAMS_PYTHON", "/trusted/python")
	_check(PythonAuthority.python_executable() == "/trusted/python", "explicit Python interpreter is preserved literally")
	DirAccess.remove_absolute(root_path.path_join("render_document.py"))
	DirAccess.remove_absolute(root_path)
	OS.set_environment("SURFACE_DIAGRAMS_AUTHORITY_ROOT", original_root)
	OS.set_environment("SURFACE_DIAGRAMS_PYTHON", original_python)
	_check(PythonAuthority.resolve_script("render_document.py").ok, "authority resolution restores after isolated test")
	_check(PythonAuthority.python_executable() == (original_python if not original_python.strip_edges().is_empty() else "python3"), "Python selection restores after isolated test")
	print("PYTHON AUTHORITY %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
