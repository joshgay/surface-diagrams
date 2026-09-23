class_name WalkthroughPublicationBridge
extends RefCounted

const MAX_BUNDLE_BYTES := 64 * 1024 * 1024

static func build(document: Variant) -> Dictionary:
	if not document is WalkthroughDocument:
		return _failure("Only a validated walkthrough can be published")
	if OS.has_feature("web"):
		return _failure("Browser publication is disabled because the Python geometry authority is unavailable")
	var cache_dir := ProjectSettings.globalize_path("user://walkthrough-publication")
	var directory_error := DirAccess.make_dir_recursive_absolute(cache_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create the local publication cache")
	var input_path := cache_dir.path_join("walkthrough.json")
	var output_path := cache_dir.path_join("walkthrough-publication.zip")
	var save_error: String = document.save_path(input_path)
	if not save_error.is_empty(): return _failure(save_error)
	var authority := PythonAuthority.resolve_script("build_walkthrough_bundle.py")
	if not authority.ok:
		return _failure(authority.error)
	var python := PythonAuthority.python_executable()
	var script: String = authority.path
	var output: Array = []
	# The executable, adapter, and paths are fixed. Imported records are bounded
	# JSON data and cannot select code, modules, commands, or output locations.
	var code := OS.execute(python, PackedStringArray([script, input_path, output_path]), output, true)
	if code != 0:
		var detail := str(output[0]).strip_edges() if not output.is_empty() else "no diagnostic"
		return _failure("Walkthrough publication unavailable (exit %d): %s" % [code, detail.left(600)])
	var receipt = JSON.parse_string(str(output[0]).strip_edges()) if not output.is_empty() else null
	if typeof(receipt) != TYPE_DICTIONARY or not receipt.get("ok", false) or typeof(receipt.get("manifest")) != TYPE_DICTIONARY:
		return _failure("Publication adapter returned an invalid receipt")
	var file := FileAccess.open(output_path, FileAccess.READ)
	if file == null: return _failure("Publication bundle was not created")
	if file.get_length() <= 0 or file.get_length() > MAX_BUNDLE_BYTES:
		return _failure("Publication bundle is empty or exceeds 64 MiB")
	var bundle := file.get_buffer(file.get_length())
	if bundle.size() < 4 or bundle.slice(0, 4) != PackedByteArray([0x50, 0x4b, 0x03, 0x04]):
		return _failure("Publication adapter returned an unexpected archive")
	if int(receipt.get("bundle_bytes", -1)) != bundle.size():
		return _failure("Publication receipt size does not match the bundle")
	return {"ok": true, "error": "", "bundle": bundle,
		"manifest": receipt.manifest.duplicate(true), "authority_source": authority.source}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "bundle": PackedByteArray(), "manifest": {}}
