extends SceneTree

const FORMAT := "surface-diagrams-studio-benchmark"
const VERSION := 1
const WORKLOAD := "bounded-m7-v1"
const RUNTIME := "4.7.2.stable.official.ed1daf0bf"
const GENERAL_SAMPLES := 5
const PUBLICATION_SAMPLES := 3
const IMPORT_PAIRS := 40
const HISTORY_COMMANDS := 100
const TIMELINE_SAMPLES := 257

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var planar_parsed := DiagramDocument.parse(_planar_source())
	var braid_parsed := DiagramDocument.parse(_braid_source())
	var walkthrough_parsed := WalkthroughDocument.parse(
		FileAccess.get_file_as_string("res://fixtures/walkthroughs/supplied-cover-disk-v1.json"))
	_require(planar_parsed.ok, "maximum planar fixture parses")
	_require(braid_parsed.ok, "maximum braid fixture parses")
	_require(walkthrough_parsed.ok, "publication fixture parses")
	if not failures.is_empty():
		_finish({})
		return

	var planar: DiagramDocument = planar_parsed.document
	var braid: DiagramDocument = braid_parsed.document
	var walkthrough: WalkthroughDocument = walkthrough_parsed.document
	var planar_json := planar.to_json()
	var braid_json := braid.to_json()
	var walkthrough_json := walkthrough.to_json()

	# One unrecorded pass warms code paths and the Python interpreter cache. The
	# measured calls still execute the complete production operation each time.
	_import_once(planar_json, braid_json)
	_history_once(planar)
	_timeline_once(braid)
	var warm_geometry := PythonGeometryBridge.render(planar)
	var warm_publication := WalkthroughPublicationBridge.build(walkthrough)
	_require(warm_geometry.get("ok", false), "geometry warmup succeeds")
	_require(warm_publication.get("ok", false), "publication warmup succeeds")
	if not failures.is_empty():
		_finish({})
		return

	var measurements: Array[Dictionary] = []
	measurements.append(_measure_import(planar_json, braid_json))
	var history_measurement := _measure_history(planar)
	measurements.append(history_measurement.measurement)
	var recovery_check := _recovery_once(planar)
	var timeline_measurement := _measure_timeline(braid)
	measurements.append(timeline_measurement.measurement)
	var geometry_measurement := _measure_geometry(planar)
	measurements.append(geometry_measurement.measurement)
	var publication_measurement := _measure_publication(walkthrough)
	measurements.append(publication_measurement.measurement)

	_require(measurements.all(func(item): return item.samples_us.all(func(value): return value > 0)), "all measured samples are positive")
	_require(history_measurement.initial_sha256 == _sha_text(planar_json), "history undo returns exact initial record")
	_require(history_measurement.retention.cache_aligned and history_measurement.retention.within_source_bounds,
		"history retention remains aligned and inside the conservative source envelope")
	_require(history_measurement.retention.totals.command_count == HISTORY_COMMANDS
		and history_measurement.retention.totals.snapshot_count == HISTORY_COMMANDS,
		"history retention reports the complete command and runtime snapshot bounds")
	_require(history_measurement.retention.totals.snapshot_source_bytes == 0
		and history_measurement.retention.bounds.maximum_snapshot_source_bytes == 0,
		"runtime snapshots retain immutable documents without duplicate source strings")
	_require(recovery_check.ok and recovery_check.version == WorkspaceRecovery.VERSION
		and recovery_check.commands == HISTORY_COMMANDS
		and recovery_check.documents == HISTORY_COMMANDS + 1,
		"compact recovery covers the complete maximum-fixture history")
	_require(recovery_check.compact_history_bytes < recovery_check.legacy_history_bytes
		and recovery_check.envelope_bytes <= WorkspaceRecovery.MAX_BYTES,
		"compact recovery reduces retained endpoint text inside its explicit envelope")
	_require(recovery_check.initial_matches and recovery_check.final_matches
		and recovery_check.cache_aligned,
		"compact recovery reproduces every exact maximum-fixture endpoint")
	_require(timeline_measurement.final_crossings == 128 and timeline_measurement.final_paths == 32, "timeline reaches the exact maximum braid endpoint")
	_require(geometry_measurement.svg_sha256 == _sha_text(warm_geometry.svg), "geometry output remains byte-identical after warmup")
	_require(geometry_measurement.tikz_sha256 == _sha_text(warm_geometry.tikz), "TikZ output remains byte-identical after warmup")
	_require(publication_measurement.bundle_sha256 == _sha(warm_publication.bundle), "publication bundle remains byte-identical after warmup")

	var receipt := {
		"format": FORMAT,
		"version": VERSION,
		"workload": WORKLOAD,
		"runtime": RUNTIME,
		"environment": {
			"os": OS.get_name(),
			"architecture": Engine.get_architecture_name(),
			"processor_count": OS.get_processor_count(),
			"display_driver": DisplayServer.get_name()
		},
		"interpretation": {
			"status": "performance-observation-only",
			"timings_establish_correctness": false,
			"thresholds_enforced": false,
			"unit": "microseconds",
			"note": "Repeatable workloads and exact fingerprints are deterministic; elapsed times vary by host and load."
		},
		"bounds": {
			"document_bytes": DiagramDocument.MAX_BYTES,
			"planar_objects": DiagramDocument.MAX_OBJECTS,
			"planar_curves": DiagramDocument.MAX_CURVES,
			"labels": DiagramDocument.MAX_LABELS,
			"braid_strands": DiagramDocument.MAX_OBJECTS,
			"braid_word": DiagramDocument.MAX_WORD,
			"history_commands": DiagramEditHistory.MAX_HISTORY
		},
		"fixtures": [
			{"id": "maximum-planar", "normalized_bytes": planar_json.to_utf8_buffer().size(),
				"sha256": _sha_text(planar_json), "objects": 32, "curves": 16, "labels": 32},
			{"id": "maximum-braid", "normalized_bytes": braid_json.to_utf8_buffer().size(),
				"sha256": _sha_text(braid_json), "strands": 32, "word": 128},
			{"id": "representative-linked-publication", "normalized_bytes": walkthrough_json.to_utf8_buffer().size(),
				"sha256": _sha_text(walkthrough_json), "documents": 2, "steps": 1,
				"scope": "representative, not the schema maximum"}
		],
		"measurements": measurements,
		"integrity": {
			"history_initial_sha256": history_measurement.initial_sha256,
			"history_final_sha256": history_measurement.final_sha256,
			"history_retention": history_measurement.retention,
			"workspace_recovery": recovery_check,
			"timeline_final_paths": timeline_measurement.final_paths,
			"timeline_final_crossings": timeline_measurement.final_crossings,
			"geometry_svg_sha256": geometry_measurement.svg_sha256,
			"geometry_tikz_sha256": geometry_measurement.tikz_sha256,
			"geometry_svg_bytes": geometry_measurement.svg_bytes,
			"geometry_tikz_bytes": geometry_measurement.tikz_bytes,
			"publication_bundle_sha256": publication_measurement.bundle_sha256,
			"publication_bundle_bytes": publication_measurement.bundle_bytes,
			"publication_documents": publication_measurement.documents,
			"excluded_exploratory_surface_views": publication_measurement.exclusions
		}
	}
	_finish(receipt)

func _measure_import(planar_json: String, braid_json: String) -> Dictionary:
	var samples: Array[int] = []
	for sample_index in GENERAL_SAMPLES:
		var started := Time.get_ticks_usec()
		for iteration in IMPORT_PAIRS:
			var planar := DiagramDocument.parse(planar_json)
			var braid := DiagramDocument.parse(braid_json)
			_require(planar.ok and braid.ok, "bounded import sample parses")
		samples.append(Time.get_ticks_usec() - started)
	return _measurement("bounded-import", samples, IMPORT_PAIRS * 2,
		"40 maximum planar plus 40 maximum braid parses per sample")

func _import_once(planar_json: String, braid_json: String) -> void:
	_require(DiagramDocument.parse(planar_json).ok and DiagramDocument.parse(braid_json).ok,
		"import warmup succeeds")

func _measure_history(planar: DiagramDocument) -> Dictionary:
	var samples: Array[int] = []
	var edit_samples: Array[int] = []
	var undo_samples: Array[int] = []
	var redo_samples: Array[int] = []
	var last: Dictionary = {}
	for sample_index in GENERAL_SAMPLES:
		last = _history_once(planar)
		_require(last.ok, "history sample completes")
		samples.append(last.elapsed_us)
		edit_samples.append(last.edit_us)
		undo_samples.append(last.undo_us)
		redo_samples.append(last.redo_us)
	var measurement := _measurement("edit-undo-redo", samples, HISTORY_COMMANDS * 3,
		"100 label edits, 100 exact undos, and 100 exact redos per sample")
	measurement.phases = {
		"edit": _timing_summary(edit_samples, HISTORY_COMMANDS),
		"undo": _timing_summary(undo_samples, HISTORY_COMMANDS),
		"redo": _timing_summary(redo_samples, HISTORY_COMMANDS)
	}
	return {"measurement": measurement,
		"initial_sha256": last.initial_sha256, "final_sha256": last.final_sha256,
		"retention": last.retention}

func _history_once(planar: DiagramDocument) -> Dictionary:
	var history := DiagramEditHistory.new()
	history.set_document(planar)
	var initial := planar.to_json()
	var edit_started := Time.get_ticks_usec()
	for index in HISTORY_COMMANDS:
		var moved := history.move_label("label01", Vector2(-309.0 + index * 0.25, -120.0 + index * 0.125))
		if not moved.ok: return {"ok": false, "elapsed_us": Time.get_ticks_usec() - edit_started}
	var edit_us := Time.get_ticks_usec() - edit_started
	var final := history.current.to_json()
	var retention := history.retention_audit()
	var undo_started := Time.get_ticks_usec()
	for index in HISTORY_COMMANDS:
		if not history.undo().ok: return {"ok": false, "elapsed_us": edit_us + Time.get_ticks_usec() - undo_started}
	var undo_us := Time.get_ticks_usec() - undo_started
	if history.current.to_json() != initial: return {"ok": false, "elapsed_us": edit_us + undo_us}
	var redo_started := Time.get_ticks_usec()
	for index in HISTORY_COMMANDS:
		if not history.redo().ok: return {"ok": false, "elapsed_us": edit_us + undo_us + Time.get_ticks_usec() - redo_started}
	var redo_us := Time.get_ticks_usec() - redo_started
	if history.current.to_json() != final: return {"ok": false, "elapsed_us": edit_us + undo_us + redo_us}
	if history.retention_audit() != retention: return {"ok": false, "elapsed_us": edit_us + undo_us + redo_us}
	return {"ok": true, "elapsed_us": edit_us + undo_us + redo_us,
		"edit_us": edit_us, "undo_us": undo_us, "redo_us": redo_us,
		"initial_sha256": _sha_text(initial), "final_sha256": _sha_text(final),
		"retention": retention}

func _recovery_once(planar: DiagramDocument) -> Dictionary:
	var history := DiagramEditHistory.new()
	history.set_document(planar)
	var initial := planar.to_json()
	for index in HISTORY_COMMANDS:
		var moved := history.move_label("label01", Vector2(-309.0 + index * 0.25, -120.0 + index * 0.125))
		if not moved.ok:
			return {"ok": false}
	var final := history.current.to_json()
	var legacy_history_bytes := JSON.stringify(history.to_state(), "", false, true).to_utf8_buffer().size()
	var compact_state := history.to_compact_state()
	var compact_history_bytes := JSON.stringify(compact_state, "", false, true).to_utf8_buffer().size()
	var encoded := WorkspaceRecovery.encode(initial, history, {}, {})
	if not encoded.ok:
		return {"ok": false}
	var parsed := WorkspaceRecovery.parse(encoded.text)
	if not parsed.ok:
		return {"ok": false}
	var restored := DiagramEditHistory.new()
	if not restored.restore_state(parsed.history_state).ok:
		return {"ok": false}
	for index in HISTORY_COMMANDS:
		if not restored.undo().ok:
			return {"ok": false}
	var initial_matches := restored.current.to_json() == initial
	for index in HISTORY_COMMANDS:
		if not restored.redo().ok:
			return {"ok": false}
	var audit := restored.retention_audit()
	return {
		"ok": true,
		"version": parsed.recovery_version,
		"commands": restored.undo_stack.size() + restored.redo_stack.size(),
		"documents": compact_state.documents.size(),
		"envelope_bytes": encoded.text.to_utf8_buffer().size(),
		"maximum_envelope_bytes": WorkspaceRecovery.MAX_BYTES,
		"compact_history_bytes": compact_history_bytes,
		"legacy_history_bytes": legacy_history_bytes,
		"saved_history_bytes": legacy_history_bytes - compact_history_bytes,
		"initial_matches": initial_matches,
		"final_matches": restored.current.to_json() == final,
		"cache_aligned": audit.cache_aligned and audit.totals.command_count == HISTORY_COMMANDS,
		"initial_sha256": _sha_text(initial),
		"final_sha256": _sha_text(final),
	}

func _measure_timeline(braid: DiagramDocument) -> Dictionary:
	var samples: Array[int] = []
	var last: Dictionary = {}
	for sample_index in GENERAL_SAMPLES:
		last = _timeline_once(braid)
		_require(last.ok, "timeline sample completes")
		samples.append(last.elapsed_us)
	return {"measurement": _measurement("braid-timeline", samples, TIMELINE_SAMPLES,
		"257 half-step samples across a maximum 32-strand, 128-generator word"),
		"final_paths": last.final_paths, "final_crossings": last.final_crossings}

func _timeline_once(braid: DiagramDocument) -> Dictionary:
	var result: Dictionary = {}
	var started := Time.get_ticks_usec()
	for index in TIMELINE_SAMPLES:
		var direction := "bottom-to-top" if index % 2 == 0 else "top-to-bottom"
		result = BraidTimeline.sample(braid, index * 0.5, direction)
		if not result.ok: return {"ok": false, "elapsed_us": Time.get_ticks_usec() - started}
	# Evaluate the exact final endpoint independently of the alternating sequence.
	result = BraidTimeline.sample(braid, 128.0, "bottom-to-top")
	return {"ok": result.ok, "elapsed_us": Time.get_ticks_usec() - started,
		"final_paths": result.paths.size(), "final_crossings": result.crossings.size()}

func _measure_geometry(planar: DiagramDocument) -> Dictionary:
	var samples: Array[int] = []
	var expected_svg := ""
	var expected_tikz := ""
	for sample_index in GENERAL_SAMPLES:
		var started := Time.get_ticks_usec()
		var result := PythonGeometryBridge.render(planar)
		var elapsed := Time.get_ticks_usec() - started
		_require(result.get("ok", false), "exact geometry sample completes")
		if result.get("ok", false):
			if expected_svg.is_empty():
				expected_svg = result.svg
				expected_tikz = result.tikz
			_require(result.svg == expected_svg and result.tikz == expected_tikz,
				"exact geometry samples are byte-identical")
		samples.append(elapsed)
	return {"measurement": _measurement("exact-svg-tikz", samples, 1,
		"one maximum-planar Python SVG and TikZ render per sample"),
		"svg_sha256": _sha_text(expected_svg), "tikz_sha256": _sha_text(expected_tikz),
		"svg_bytes": expected_svg.to_utf8_buffer().size(), "tikz_bytes": expected_tikz.to_utf8_buffer().size()}

func _measure_publication(walkthrough: WalkthroughDocument) -> Dictionary:
	var samples: Array[int] = []
	var expected := PackedByteArray()
	var manifest: Dictionary = {}
	for sample_index in PUBLICATION_SAMPLES:
		var started := Time.get_ticks_usec()
		var result := WalkthroughPublicationBridge.build(walkthrough)
		var elapsed := Time.get_ticks_usec() - started
		_require(result.get("ok", false), "publication sample completes")
		if result.get("ok", false):
			if expected.is_empty():
				expected = result.bundle
				manifest = result.manifest
			_require(result.bundle == expected, "publication samples are byte-identical")
		samples.append(elapsed)
	var documents: Array = manifest.get("documents", []).map(func(item): return item.id)
	var exclusions: Array = manifest.get("excluded_exploratory_surface_views", []).map(func(item): return item.id)
	return {"measurement": _measurement("publication-bundle", samples, 1,
		"one representative linked walkthrough ZIP per sample"),
		"bundle_sha256": _sha(expected), "bundle_bytes": expected.size(),
		"documents": documents, "exclusions": exclusions}

func _measurement(id: String, samples: Array[int], units: int, description: String) -> Dictionary:
	var summary := _timing_summary(samples, units)
	summary.merge({"id": id, "description": description, "sample_count": samples.size(),
		"units_per_sample": units})
	return summary

func _timing_summary(samples: Array[int], units: int) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	var median: int = ordered[ordered.size() / 2]
	return {"samples_us": samples, "minimum_us": ordered.front(),
		"median_us": median, "maximum_us": ordered.back(),
		"median_per_unit_us": snappedf(float(median) / units, 0.001)}

func _planar_source() -> String:
	var objects: Array = []
	var curves: Array = []
	var labels: Array = []
	for index in 32:
		objects.append({"id": "p%02d" % (index + 1), "kind": "boundary" if index in [0, 31] else "point",
			"x": -310 + index * 20})
		labels.append({"id": "label%02d" % (index + 1), "text": "Stable object p%02d" % (index + 1),
			"x": -310 + index * 20, "y": -120 + (index % 4) * 18})
	for index in 16:
		curves.append({"id": "curve%02d" % (index + 1), "kind": "arc",
			"start": index * 2 + 1, "end": index * 2 + 2, "cuts": [],
			"direction": "up" if index % 2 == 0 else "down", "color": "#ff00d4"})
	return JSON.stringify({"format": "surface-diagrams", "version": 1, "kind": "planar",
		"title": "Bounded maximum planar benchmark", "surface": {"width": 800, "height": 320, "objects": objects},
		"curves": curves, "labels": labels, "allow_intersections": false}, "\t", false, true) + "\n"

func _braid_source() -> String:
	var word: Array = []
	for index in 128:
		var generator := index % 31 + 1
		word.append(generator if index % 2 == 0 else -generator)
	return JSON.stringify({"format": "surface-diagrams", "version": 1, "kind": "braid",
		"title": "Bounded maximum braid benchmark", "braid": {"strands": 32, "word": word,
			"spacing": 20, "step": 12, "direction": "bottom-to-top"}, "labels": []}, "\t", false, true) + "\n"

func _finish(receipt: Dictionary) -> void:
	if not failures.is_empty():
		for failure in failures: printerr("BENCHMARK FAIL: " + failure)
		quit(1)
		return
	var text := JSON.stringify(receipt, "  ") + "\n"
	var output := _receipt_path()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			printerr("BENCHMARK FAIL: could not write receipt")
			quit(1)
			return
		file.store_string(text)
	print("BENCHMARK PASS " + JSON.stringify({"measurements": receipt.measurements.map(func(item): return {"id": item.id, "median_us": item.median_us}), "receipt": output}))
	quit(0)

func _receipt_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="): return argument.trim_prefix("--receipt=")
	return ""

func _require(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func _sha_text(value: String) -> String:
	return _sha(value.to_utf8_buffer())

func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()
