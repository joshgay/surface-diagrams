class_name ExploratorySurface3D
extends SubViewportContainer

signal record_picked(record: Dictionary)

var document: SurfaceViewDocument
var viewport_3d: SubViewport
var scene_root: Node3D
var camera: Camera3D
var orientation_labels: Node3D
var selection_marker: MeshInstance3D
var nodes_by_id: Dictionary = {}
var positions_by_id: Dictionary = {}
var curve_points_by_id: Dictionary = {}
var records_by_id: Dictionary = {}
var hidden_ids: Dictionary = {}
var selected_id := ""
var yaw := 0.35
var pitch := -0.45
var distance := 8.5
var target := Vector3.ZERO
var dragging := false
var drag_moved := false
var drag_start := Vector2.ZERO
var focus_border: Panel

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_accessibility_name("Exploratory three dimensional surface view")
	set_accessibility_description("Arrow keys orbit, plus and minus zoom, and Home restores the fitted camera. This view uses supplied exploratory coordinates.")
	viewport_3d = SubViewport.new()
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.transparent_bg = false
	add_child(viewport_3d)
	focus_border = Panel.new()
	focus_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_border.visible = false
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color("#006fff")
	focus_style.set_border_width_all(3)
	focus_border.add_theme_stylebox_override("panel", focus_style)
	add_child(focus_border)
	focus_entered.connect(func(): focus_border.visible = true)
	focus_exited.connect(func(): focus_border.visible = false)
	scene_root = Node3D.new()
	viewport_3d.add_child(scene_root)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 45
	scene_root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.25
	scene_root.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(40, 155, 0)
	fill.light_energy = 0.45
	scene_root.add_child(fill)
	selection_marker = MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.17
	marker_mesh.height = 0.34
	selection_marker.mesh = marker_mesh
	selection_marker.material_override = _material(Color("#ffd54a"), true)
	selection_marker.visible = false
	scene_root.add_child(selection_marker)
	fit_view()

func set_document(value: SurfaceViewDocument) -> void:
	document = value
	selected_id = ""
	hidden_ids.clear()
	for child in scene_root.get_children():
		if child != camera and child != selection_marker and child is not Light3D:
			child.queue_free()
	nodes_by_id.clear()
	positions_by_id.clear()
	curve_points_by_id.clear()
	records_by_id.clear()
	selection_marker.visible = false
	if document == null: return
	var data := document.to_dict()
	var disk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = data.surface.radius
	mesh.bottom_radius = data.surface.radius
	mesh.height = data.surface.thickness
	mesh.radial_segments = 64
	disk.mesh = mesh
	disk.rotation_degrees.x = 90
	disk.material_override = _material(Color(data.surface.color), false)
	disk.name = "ExploratoryDisk"
	scene_root.add_child(disk)
	var planar := document.planar_document().data
	for index in data.objects.size():
		var record: Dictionary = data.objects[index]
		var node := MeshInstance3D.new()
		var point_mesh := SphereMesh.new()
		var object_kind: String = planar.surface.objects[index].kind
		point_mesh.radius = 0.12 if object_kind == "point" else 0.15
		point_mesh.height = point_mesh.radius * 2.0
		node.mesh = point_mesh
		node.material_override = _material(Color("#006fff") if object_kind == "point" else Color("#8b8b8b"), true)
		node.position = _vector(record.position)
		node.name = record.id
		scene_root.add_child(node)
		nodes_by_id[record.id] = node
		positions_by_id[record.id] = node.position
		records_by_id[record.id] = {"id": record.id, "kind": "object"}
	for record in data.curves:
		var points: Array[Vector3] = []
		for raw in record.points: points.append(_vector(raw))
		var node := MeshInstance3D.new()
		node.mesh = _line_mesh(points, Color("#ff00d4"))
		node.name = record.id
		scene_root.add_child(node)
		nodes_by_id[record.id] = node
		curve_points_by_id[record.id] = points
		positions_by_id[record.id] = _polyline_midpoint(points)
		records_by_id[record.id] = {"id": record.id, "kind": "curve"}
	orientation_labels = Node3D.new()
	scene_root.add_child(orientation_labels)
	_add_label("+x", Vector3(data.surface.radius + 0.35, 0, 0.1), Color("#b64040"))
	_add_label("+y", Vector3(0, data.surface.radius + 0.35, 0.1), Color("#3f8050"))
	_add_label("front +z", Vector3(0, -data.surface.radius - 0.45, 0.1), Color("#315fa8"))
	fit_view()

func select_id(id: String) -> bool:
	if not records_by_id.has(id): return false
	selected_id = id
	selection_marker.position = positions_by_id[id]
	selection_marker.visible = not hidden_ids.has(id)
	return true

func hide_selected() -> bool:
	if selected_id.is_empty() or not nodes_by_id.has(selected_id): return false
	hidden_ids[selected_id] = true
	nodes_by_id[selected_id].visible = false
	selection_marker.visible = false
	return true

func isolate_selected() -> bool:
	if selected_id.is_empty() or not nodes_by_id.has(selected_id): return false
	hidden_ids.clear()
	for id in nodes_by_id:
		var hidden: bool = id != selected_id
		nodes_by_id[id].visible = not hidden
		if hidden: hidden_ids[id] = true
	selection_marker.visible = true
	return true

func show_all() -> void:
	hidden_ids.clear()
	for node in nodes_by_id.values(): node.visible = true
	selection_marker.visible = not selected_id.is_empty()

func set_orientation_labels_visible(value: bool) -> void:
	if orientation_labels != null: orientation_labels.visible = value

func fit_view() -> void:
	yaw = 0.35
	pitch = -0.45
	distance = 8.5
	target = Vector3.ZERO
	_update_camera()

func orbit(delta: Vector2) -> void:
	if not delta.is_finite(): return
	yaw -= delta.x * 0.008
	pitch = clampf(pitch - delta.y * 0.008, -1.35, 1.35)
	_update_camera()

func zoom(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0: return
	distance = clampf(distance * factor, 3.5, 30.0)
	_update_camera()

func pick_at(screen_position: Vector2, threshold: float = 22.0) -> Dictionary:
	if document == null or camera == null or not screen_position.is_finite(): return {}
	var best := threshold
	var best_id := ""
	for id in positions_by_id:
		if hidden_ids.has(id): continue
		if records_by_id[id].kind == "object":
			var position: Vector3 = positions_by_id[id]
			if camera.is_position_behind(position): continue
			var distance_2d := camera.unproject_position(position).distance_to(screen_position)
			if distance_2d < best:
				best = distance_2d
				best_id = id
	for id in curve_points_by_id:
		if hidden_ids.has(id): continue
		var points: Array = curve_points_by_id[id]
		for index in points.size() - 1:
			if camera.is_position_behind(points[index]) or camera.is_position_behind(points[index + 1]): continue
			var a := camera.unproject_position(points[index])
			var b := camera.unproject_position(points[index + 1])
			var closest := Geometry2D.get_closest_point_to_segment(screen_position, a, b)
			var distance_2d := closest.distance_to(screen_position)
			if distance_2d < best:
				best = distance_2d
				best_id = id
	if best_id.is_empty(): return {}
	select_id(best_id)
	var result: Dictionary = records_by_id[best_id].duplicate(true)
	record_picked.emit(result)
	return result

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and handle_keyboard(event):
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom(1.0 / 0.9)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_moved = false
				drag_start = event.position
			else:
				dragging = false
				if not drag_moved: pick_at(event.position)
	elif event is InputEventMouseMotion and dragging:
		drag_moved = drag_moved or event.position.distance_to(drag_start) >= 3.0
		orbit(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			drag_moved = false
			drag_start = event.position
		else:
			dragging = false
			if not drag_moved: pick_at(event.position)
	elif event is InputEventScreenDrag:
		drag_moved = drag_moved or event.position.distance_to(drag_start) >= 3.0
		orbit(event.relative)

func handle_keyboard(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_LEFT:
			orbit(Vector2(-18.0, 0.0))
		KEY_RIGHT:
			orbit(Vector2(18.0, 0.0))
		KEY_UP:
			orbit(Vector2(0.0, -18.0))
		KEY_DOWN:
			orbit(Vector2(0.0, 18.0))
		KEY_EQUAL, KEY_KP_ADD:
			zoom(0.9)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom(1.0 / 0.9)
		KEY_HOME:
			fit_view()
		_:
			return false
	return true

func _update_camera() -> void:
	if camera == null: return
	var offset := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)

func _add_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 32
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	orientation_labels.add_child(label)

static func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.75
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

static func _line_mesh(points: Array[Vector3], color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material(color, true))
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func _polyline_midpoint(points: Array[Vector3]) -> Vector3:
	if points.is_empty(): return Vector3.ZERO
	return points[points.size() / 2]
