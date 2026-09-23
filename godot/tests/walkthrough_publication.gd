extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var planar: WalkthroughDocument = WalkthroughDocument.parse(FileAccess.get_file_as_string(WalkthroughView.PLANAR_FIXTURE)).document
	var first := WalkthroughPublicationBridge.build(planar)
	var second := WalkthroughPublicationBridge.build(planar)
	_check(first.ok and first.bundle.size() > 0 and first.bundle.slice(0, 4) == PackedByteArray([0x50, 0x4b, 0x03, 0x04]), "validated walkthrough produces a ZIP publication bundle")
	_check(first.bundle == second.bundle and first.manifest == second.manifest, "publication bundle and manifest are byte-deterministic")
	_check(first.manifest.format == "surface-diagrams-walkthrough-publication" and first.manifest.version == 1, "manifest has a bounded versioned publication format")
	_check(first.manifest.geometry_authority == "surface-diagrams Python library" and "2D" in first.manifest.geometry_scope, "manifest names the exact geometry authority and scope")
	_check(first.manifest.documents.size() == 3 and first.manifest.documents.map(func(item): return item.id) == ["initial", "point_moved", "label_moved"], "manifest preserves supplied document order and IDs")
	_check(first.manifest.steps.map(func(item): return item.id) == ["place-point", "place-caption"], "manifest preserves literal step references")
	_check(first.manifest.documents[0].stable_records.map(func(item): return item.id) == ["p1", "p2", "p3", "p4", "arc1", "caption"], "manifest preserves stable object, curve, and label order")
	_check(first.manifest.excluded_exploratory_surface_views.is_empty(), "plain walkthrough has no invented exploratory exclusions")
	_check(first.manifest.source.sha256 == _sha(planar.to_json().to_utf8_buffer()), "manifest checksum binds the exact normalized walkthrough source")

	var path := "user://walkthrough-publication-contract.zip"
	var absolute := ProjectSettings.globalize_path(path)
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_buffer(first.bundle)
	output = null
	var archive := ZIPReader.new()
	_check(archive.open(absolute) == OK, "Godot reopens the generated publication archive")
	var names := Array(archive.get_files())
	_check(names.has("walkthrough.json") and names.has("manifest.json") and names.has("documents/initial.svg") and names.has("documents/initial.tikz") and names.has("documents/initial.py") and names.has("documents/initial.json"), "archive contains source, manifest, and exact endpoint artifacts")
	_check(archive.read_file("walkthrough.json").get_string_from_utf8() == planar.to_json(), "archive retains exact normalized walkthrough JSON")
	var embedded_manifest = JSON.parse_string(archive.read_file("manifest.json").get_string_from_utf8())
	_check(embedded_manifest == first.manifest, "embedded manifest equals the adapter receipt")
	_check(archive.read_file("documents/initial.svg").get_string_from_utf8().begins_with("<svg"), "bundle contains Python-library SVG")
	_check("tikzpicture" in archive.read_file("documents/initial.tikz").get_string_from_utf8(), "bundle contains Python-library TikZ")
	_check("DiagramDocument.from_dict" in archive.read_file("documents/initial.py").get_string_from_utf8(), "bundle contains editable Python recipe")
	for artifact in first.manifest.documents[0].artifacts:
		var data := archive.read_file(artifact.path)
		_check(data.size() == artifact.bytes and _sha(data) == artifact.sha256, "manifest size and checksum verify " + artifact.path)
	archive.close()
	DirAccess.remove_absolute(absolute)

	var cover: WalkthroughDocument = WalkthroughDocument.parse(FileAccess.get_file_as_string(WalkthroughView.COVER_FIXTURE)).document
	var cover_result := WalkthroughPublicationBridge.build(cover)
	_check(cover_result.ok and cover_result.manifest.excluded_exploratory_surface_views.map(func(item): return item.id) == ["surface_before", "surface_after"], "cover bundle explicitly lists both excluded exploratory views")
	_check(cover_result.manifest.steps[0].surface_linkage.status == "supplied-exploratory-linkage" and cover_result.manifest.steps[0].surface_linkage.verification.status == "unverified", "cover linkage status and verification remain visible metadata")
	var cover_path := "user://walkthrough-cover-publication.zip"
	var cover_file := FileAccess.open(cover_path, FileAccess.WRITE)
	cover_file.store_buffer(cover_result.bundle)
	cover_file = null
	archive = ZIPReader.new()
	archive.open(ProjectSettings.globalize_path(cover_path))
	names = Array(archive.get_files())
	_check(not names.any(func(name): return "surface_before" in name or "surface_after" in name), "exploratory 3D records are not exported as certified geometry artifacts")
	_check('"surface_views"' in archive.read_file("walkthrough.json").get_string_from_utf8(), "exploratory records remain preserved in the exact source record")
	archive.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cover_path))

	var braid: WalkthroughDocument = WalkthroughDocument.parse(FileAccess.get_file_as_string(WalkthroughView.BRAID_FIXTURE)).document
	var braid_result := WalkthroughPublicationBridge.build(braid)
	var blocks: Array = []
	for item in braid_result.manifest.steps: blocks.append(item.literal_braid_block.map(func(value): return int(value)))
	var strand_ids: Array = braid_result.manifest.documents[0].stable_records.map(func(item): return int(item.id))
	_check(braid_result.ok and blocks == [[1], [-2], [1]], "braid bundle preserves literal block order and signs")
	_check(strand_ids == [1, 2, 3], "braid manifest preserves transported strand identities")
	_check(not WalkthroughPublicationBridge.build(null).ok and not WalkthroughPublicationBridge.build(planar.diagram("initial")).ok, "bridge rejects non-walkthrough values")

	var view := WalkthroughView.new()
	root.add_child(view)
	await process_frame
	_check(view.import_source(planar.to_json()) and view.publication.ok and not view.publication_button.disabled, "desktop viewer prepares the exact bundle after valid import")
	_check("bundle ready" in view.status.text and "excluded" in view.status.text, "desktop viewer reports publication readiness and 3D exclusion")
	var accepted_bundle: PackedByteArray = view.publication.bundle.duplicate()
	_check(not view.import_source("{}") and view.publication.bundle == accepted_bundle, "failed import preserves the accepted publication bundle")
	_check(view.save_publication("user://walkthrough-view-publication.zip"), "viewer saves the prepared binary bundle")
	_check(FileAccess.get_file_as_bytes("user://walkthrough-view-publication.zip") == accepted_bundle, "saved viewer bundle is byte-identical to the tested adapter result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://walkthrough-view-publication.zip"))
	view.queue_free()
	await process_frame

	var browser := WalkthroughView.new()
	browser.browser_mode = true
	root.add_child(browser)
	await process_frame
	_check(browser.import_source(planar.to_json()) and not browser.publication.ok and browser.publication_button.disabled, "browser viewer keeps Python publication explicitly unavailable")
	_check("Python publication export unavailable" in browser.status.text and not browser.save_publication("user://forbidden.zip"), "browser cannot claim or write an exact publication bundle")
	_check(not FileAccess.file_exists("user://forbidden.zip"), "disabled browser publication creates no file")
	browser.queue_free()
	await process_frame
	print("WALKTHROUGH PUBLICATION: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _sha(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
