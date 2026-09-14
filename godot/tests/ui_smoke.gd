extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/studio.tscn") as PackedScene
	_check(packed != null, "studio scene loads")
	if packed == null:
		_finish()
		return
	var studio := packed.instantiate()
	root.add_child(studio)
	await process_frame
	await process_frame
	_check(studio.document != null, "ready opens initial document")
	_check(studio.document.data.kind == "planar", "initial fixture is planar")
	_check(studio.record_list.item_count == 6, "planar inspector shows four objects, curve, and label")
	_check(studio.canvas.document.to_json() == studio.document.to_json(), "canvas receives same immutable record")
	studio._open_resource("res://fixtures/braid-v1.json")
	await process_frame
	_check(studio.document.data.kind == "braid", "braid fixture switches view")
	_check(studio.record_list.item_count == 6, "braid inspector shows summary and five crossings")
	var before: String = studio.document.to_json()
	studio.canvas.zoom_at(Vector2(80, 60), 1.2)
	studio.canvas.pan = Vector2(12, -7)
	_check(studio.document.to_json() == before, "navigation keeps source record exact")
	studio._open_result({"ok": false, "error": "test rejection"}, "bad.json")
	_check(studio.document.to_json() == before, "rejected open retains current document")
	_check("Not opened" in studio.status_label.text, "rejected open is visible")
	studio.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _finish() -> void:
	if failures:
		printerr("UI SMOKE FAILED: %d of %d assertions" % [failures, assertions])
		quit(1)
	else:
		print("UI SMOKE PASS: %d assertions" % assertions)
		quit(0)
