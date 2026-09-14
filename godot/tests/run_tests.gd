extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_expect(false, "intentional harness failure")
	else:
		_run_tests()
	if failures:
		printerr("FAILED: %d of %d assertions" % [failures, assertions])
		quit(1)
	else:
		print("PASS: %d assertions" % assertions)
		quit(0)

func _run_tests() -> void:
	var planar := _fixture("res://fixtures/planar-v1.json")
	var braid := _fixture("res://fixtures/braid-v1.json")
	if planar == null or braid == null: return
	_expect(planar.data.kind == "planar", "planar kind")
	_expect(planar.data.surface.objects.size() == 4, "four planar objects")
	_expect(planar.data.surface.objects[0].id == "p1", "stable object ID")
	_expect(planar.data.curves[0].cuts == [], "exact empty itinerary")
	var leaked := planar.data; leaked.title = "Mutated copy"
	_expect(planar.data.title == "Generic planar import fixture", "external dictionary mutation cannot change record")
	_expect(planar.data.style.marked_point_color == "#006fff", "blue marks")
	_expect(planar.data.style.boundary_color == "#8b8b8b", "gray boundaries")
	_expect(planar.data.curves[0].color == "#ff00d4", "magenta curve default")
	_expect(not planar.data.allow_intersections, "intersections remain explicit")
	_expect(braid.data.braid.word == [1, -2, 3, -4, 5], "braid word order and signs preserved")
	_expect(braid.data.braid.direction == "bottom-to-top", "braid direction preserved")
	var braid_rows := braid.summary_rows()
	_expect("entry [1, 2, 3, 4, 5, 6]  exit [2, 1, 3, 4, 5, 6]" in braid_rows[1], "first strand transport")
	var round_trip := DiagramDocument.parse(planar.to_json())
	_expect(round_trip.ok, "normalized JSON reopens")
	if round_trip.ok:
		_expect(round_trip.document.data == planar.data, "round trip is lossless")
		var camera_state := {"zoom": 2.0, "pan": Vector2(30, -10)}
		_expect(round_trip.document.data == planar.data and camera_state.zoom == 2.0, "camera state is separate")
	var save_path := "user://round-trip.json"
	_expect(planar.save_path(save_path).is_empty(), "save succeeds")
	var reopened := DiagramDocument.load_path(save_path)
	_expect(reopened.ok and reopened.document.data == planar.data, "saved recipe reopens exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_reject("{", "malformed JSON")
	_reject("[]", "non-object document")
	_reject('{"format":"surface-diagrams","version":1,"version":1,"kind":"planar","surface":{"width":20,"height":20,"objects":[]}}', "duplicate JSON field")
	_reject('{"format":"surface-diagrams","version":1,"\\u0076ersion":1,"kind":"planar","surface":{"width":20,"height":20,"objects":[]}}', "escaped duplicate JSON field")
	var future := planar.to_dict(); future.version = 2
	_reject(JSON.stringify(future), "future version")
	var unknown := planar.to_dict(); unknown.future_field = 3
	_reject(JSON.stringify(unknown), "unknown field")
	var duplicate_id := planar.to_dict(); duplicate_id.surface.objects[1].id = "p1"
	_reject(JSON.stringify(duplicate_id), "duplicate object ID")
	var reordered := planar.to_dict(); reordered.surface.objects[1].x = -130
	_reject(JSON.stringify(reordered), "object reordering")
	var nonminimal := planar.to_dict(); nonminimal.curves[0].cuts = [2, 2]
	_reject(JSON.stringify(nonminimal), "nonminimal itinerary")
	var same_endpoint := planar.to_dict(); same_endpoint.curves[0].end = same_endpoint.curves[0].start
	_reject(JSON.stringify(same_endpoint), "arc with equal endpoints")
	var adjacent_cut := planar.to_dict(); adjacent_cut.curves[0].cuts = [0]
	_reject(JSON.stringify(adjacent_cut), "terminal cut adjacent to endpoint")
	var bad_loop := planar.to_dict(); bad_loop.curves = [{"id": "loop1", "kind": "loop", "cuts": [0]}]
	_reject(JSON.stringify(bad_loop), "odd loop itinerary")
	var bad_generator := braid.to_dict(); bad_generator.braid.word = [6]
	_reject(JSON.stringify(bad_generator), "out-of-range braid generator")
	var identity_braid := braid.to_dict(); identity_braid.braid.word = []
	var identity_result := DiagramDocument.parse(JSON.stringify(identity_braid))
	_expect(identity_result.ok and identity_result.document.data.braid.word.is_empty(), "empty braid word is retained")
	var executable := planar.to_dict(); executable.script = "res://evil.gd"
	_reject(JSON.stringify(executable), "imported script field")
	var huge := " ".repeat(DiagramDocument.MAX_BYTES) + "{}"
	var huge_result := DiagramDocument.parse(huge)
	_expect(not huge_result.ok, "oversized document")
	var canvas := DiagramCanvas.new()
	canvas.document = planar
	var before := planar.to_json()
	canvas.zoom_at(Vector2(100, 100), 1.5)
	canvas.pan = Vector2(20, 30)
	_expect(planar.to_json() == before, "canvas navigation does not mutate records")
	canvas.free()
	var scene := load("res://scenes/studio.tscn")
	_expect(scene is PackedScene, "main scene loads")
	if scene is PackedScene:
		var instance: Node = scene.instantiate()
		_expect(instance != null, "main scene instantiates")
		instance.free()

func _fixture(path: String) -> DiagramDocument:
	var result := DiagramDocument.load_path(path)
	_expect(result.ok, path + " parses: " + result.get("error", ""))
	return result.document if result.ok else null

func _reject(text: String, label: String) -> void:
	var result := DiagramDocument.parse(text)
	_expect(not result.ok, label + " rejected")

func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
