# PURPOSE: ModelView2D - Displays a 3D GLTF model as a 2D UI element.
extends SubViewportContainer

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var model_root: Node3D = $SubViewport/ModelRoot

@export_range(0.5, 1.0, 0.01) var fill_ratio: float = 0.92
@export var spin_enabled: bool = true
@export var base_rotation_degrees: Vector3 = Vector3(-20, 0, 0)

var _spin_tween: Tween = null
var _current_bounds_size: Vector3 = Vector3.ZERO
var _pending_gltf_path: String = ""

func _ready() -> void:
	_sync_viewport_size()
	if _pending_gltf_path != "":
		var pending_path = _pending_gltf_path
		_pending_gltf_path = ""
		load_model(pending_path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_sync_viewport_size()
		if _current_bounds_size != Vector3.ZERO:
			_fit_camera_to_bounds(_current_bounds_size)

func load_model(gltf_path: String) -> void:
	if not is_node_ready():
		_pending_gltf_path = gltf_path
		return
	
	if _spin_tween:
		_spin_tween.kill()
		_spin_tween = null
	
	for child in model_root.get_children():
		child.queue_free()
	_current_bounds_size = Vector3.ZERO
	
	if gltf_path == "":
		return
	
	var full_path = gltf_path
	if not full_path.begins_with("res://"):
		full_path = "res://assets/models/" + full_path
	if not full_path.ends_with(".gltf"):
		full_path += ".gltf"
	
	if ResourceLoader.exists(full_path):
		var scene = load(full_path).instantiate()
		model_root.add_child(scene)
		_auto_center_model(scene)
	else:
		printerr("[ModelView2D] Failed to find model: ", full_path)

func _auto_center_model(node: Node3D) -> void:
	var aabb = _get_aabb_recursive(node)
	if aabb.size == Vector3.ZERO:
		return
	
	node.scale = Vector3.ONE
	node.position = -aabb.get_center()
	node.rotation_degrees = base_rotation_degrees
	_current_bounds_size = aabb.size
	_fit_camera_to_bounds(aabb.size)
	
	if spin_enabled:
		_spin_tween = create_tween().set_loops()
		_spin_tween.tween_property(node, "rotation:y", 2 * PI, 5.0).from(0.0)

func _fit_camera_to_bounds(bounds_size: Vector3) -> void:
	_sync_viewport_size()
	var target_size = _get_target_size()
	var aspect = max(target_size.x / max(target_size.y, 1.0), 0.01)
	var vertical_size = max(bounds_size.y, bounds_size.x / aspect)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = max(vertical_size / max(fill_ratio, 0.01), 0.01)
	camera.position = Vector3(0, 0, max(bounds_size.z * 2.0, 2.0))
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _sync_viewport_size() -> void:
	if stretch:
		return
	
	var target_size = _get_target_size()
	viewport.size = Vector2i(
		max(1, int(ceil(target_size.x))),
		max(1, int(ceil(target_size.y)))
	)

func _get_target_size() -> Vector2:
	var target_size = size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = custom_minimum_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = Vector2(64, 64)
	return target_size

func _get_aabb_recursive(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var aabb = AABB()
	var found = false
	var current_transform = parent_transform
	
	if node is Node3D:
		current_transform = parent_transform * node.transform
	
	if node is MeshInstance3D and node.mesh:
		aabb = _transform_aabb(current_transform, node.mesh.get_aabb())
		found = true
	
	for child in node.get_children():
		var child_aabb = _get_aabb_recursive(child, current_transform)
		if child_aabb.size != Vector3.ZERO:
			if not found:
				aabb = child_aabb
				found = true
			else:
				aabb = aabb.merge(child_aabb)
	
	return aabb

func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var start = aabb.position
	var end = aabb.end
	var points = [
		Vector3(start.x, start.y, start.z),
		Vector3(end.x, start.y, start.z),
		Vector3(start.x, end.y, start.z),
		Vector3(end.x, end.y, start.z),
		Vector3(start.x, start.y, end.z),
		Vector3(end.x, start.y, end.z),
		Vector3(start.x, end.y, end.z),
		Vector3(end.x, end.y, end.z),
	]
	
	var transformed = AABB(transform * points[0], Vector3.ZERO)
	for i in range(1, points.size()):
		transformed = transformed.expand(transform * points[i])
	return transformed

func set_color_tint(color: Color) -> void:
	$SubViewport/OmniLight3D.light_color = color
	$SubViewport/OmniLight3D.light_energy = 2.0
