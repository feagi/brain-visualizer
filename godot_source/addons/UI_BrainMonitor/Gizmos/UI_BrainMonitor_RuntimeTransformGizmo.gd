extends Node3D
class_name UI_BrainMonitor_RuntimeTransformGizmo
## Runtime transform gizmo for Brain Monitor (not Godot editor gizmo).
##
## This is intentionally simple and deterministic:
## - MOVE mode: 3 colored axis arrows (X/Y/Z) that can be dragged to translate along that axis.
## - RESIZE mode: 3 colored axis handles (X/Y/Z) that can be dragged to scale dimensions along that axis.

enum MODE { MOVE, RESIZE }
enum AXIS { X, Y, Z }

const META_AXIS: StringName = &"bv_gizmo_axis"
const META_KIND: StringName = &"bv_gizmo_kind"

const KIND_MOVE: StringName = &"move"
const KIND_RESIZE: StringName = &"resize"
const KIND_CLOSE: StringName = &"close"

var _mode: MODE = MODE.MOVE
var _axis_length: float = 0.0
var _close_root: Node3D = null
var _close_hovered: bool = false
var _close_hover_tween: Tween = null
var _close_sprite: Sprite3D = null

func setup(mode: MODE) -> void:
	_mode = mode
	_clear_children()
	_build_axes()

## Length (world units) used for each axis visual.
func get_axis_length() -> float:
	return _axis_length

func _clear_children() -> void:
	for c in get_children():
		c.queue_free()

func _build_axes() -> void:
	# Visual size (world units). Kept small so it doesn't occlude large cortical volumes.
	var axis_length: float = 2.5
	_axis_length = axis_length
	# Thicker visuals to make interaction easier.
	var shaft_radius: float = 0.10
	var head_length: float = 0.45
	var head_radius: float = 0.22

	_add_axis(AXIS.X, Color(1.0, 0.2, 0.2, 0.9), Vector3.RIGHT, axis_length, shaft_radius, head_length, head_radius)
	_add_axis(AXIS.Y, Color(0.2, 1.0, 0.2, 0.9), Vector3.UP, axis_length, shaft_radius, head_length, head_radius)
	# FEAGI +Z maps to Godot -Z (FORWARD) in this project (see renderer Z flip).
	_add_axis(AXIS.Z, Color(0.2, 0.4, 1.0, 0.9), Vector3.FORWARD, axis_length, shaft_radius, head_length, head_radius)
	_add_close_handle(axis_length)

func _add_axis(axis: AXIS, color: Color, dir: Vector3, axis_length: float, shaft_radius: float, head_length: float, head_radius: float) -> void:
	var axis_root := Node3D.new()
	axis_root.name = "Axis_%s" % AXIS.keys()[axis]
	add_child(axis_root)

	# Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.height = axis_length - head_length
	shaft_mesh.top_radius = shaft_radius
	shaft_mesh.bottom_radius = shaft_radius
	shaft_mesh.radial_segments = 10
	shaft.mesh = shaft_mesh

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = color
	shaft_mat.emission_enabled = true
	shaft_mat.emission = color
	shaft_mat.emission_energy = 0.8
	shaft.material_override = shaft_mat

	# Godot cylinder is oriented along Y. Align Y to axis dir.
	shaft.transform.basis = _basis_from_y_axis(dir)
	# Place shaft so it starts at origin and extends outward.
	shaft.position = dir.normalized() * ((shaft_mesh.height * 0.5))
	axis_root.add_child(shaft)

	# Head (cone)
	var head: MeshInstance3D = MeshInstance3D.new()
	# Godot runtime doesn't always expose ConeMesh (depends on build/imports).
	# Use a CylinderMesh with top_radius=0 as a cone substitute.
	var cone_like: CylinderMesh = CylinderMesh.new()
	cone_like.height = head_length
	cone_like.top_radius = 0.0
	cone_like.bottom_radius = head_radius
	cone_like.radial_segments = 12
	head.mesh = cone_like
	head.material_override = shaft_mat
	head.transform.basis = _basis_from_y_axis(dir)
	head.position = dir.normalized() * (axis_length - head_length * 0.5)
	axis_root.add_child(head)

	# Collider (use a slightly fatter cylinder around the whole axis)
	var body := StaticBody3D.new()
	body.name = "Pick_%s" % AXIS.keys()[axis]
	body.set_meta(META_AXIS, axis)
	body.set_meta(META_KIND, KIND_MOVE if _mode == MODE.MOVE else KIND_RESIZE)

	var shape := CollisionShape3D.new()
	var pick_cyl := CylinderShape3D.new()
	pick_cyl.height = axis_length
	# Make hit area significantly thicker than visuals so it's easy to click/drag.
	pick_cyl.radius = 0.45
	shape.shape = pick_cyl
	body.add_child(shape)

	body.transform.basis = _basis_from_y_axis(dir)
	body.position = dir.normalized() * (axis_length * 0.5)
	axis_root.add_child(body)

func _add_close_handle(axis_length: float) -> void:
	var close_root := Node3D.new()
	close_root.name = "CloseHandle"
	add_child(close_root)
	_close_root = close_root

	var sprite := Sprite3D.new()
	sprite.texture = _create_close_icon_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.01
	close_root.add_child(sprite)
	_close_sprite = sprite

	var body := StaticBody3D.new()
	body.name = "Pick_Close"
	body.set_meta(META_KIND, KIND_CLOSE)
	body.collision_layer = 1
	body.collision_mask = 1
	body.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var pick_sphere := SphereShape3D.new()
	pick_sphere.radius = 1.2
	shape.shape = pick_sphere
	body.add_child(shape)
	close_root.add_child(body)

	# Place the close handle below the gizmo center.
	close_root.position = Vector3(0.0, -axis_length * 0.9, 0.0)

## Update close handle placement to face the camera and remain clickable.
func update_close_handle(world_pos: Vector3, camera_pos: Vector3) -> void:
	if _close_root == null:
		return
	_close_root.global_position = world_pos

## Grow/shrink close handle on hover so it's clearly interactive.
func set_close_hovered(is_hovered: bool) -> void:
	if _close_root == null or _close_hovered == is_hovered:
		return
	_close_hovered = is_hovered
	if _close_hover_tween != null and _close_hover_tween.is_running():
		_close_hover_tween.kill()
	_close_hover_tween = create_tween()
	var target_scale := Vector3.ONE * (1.25 if is_hovered else 1.0)
	_close_hover_tween.tween_property(_close_root, "scale", target_scale, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Builds a white X with a circular outline as a Sprite3D texture.
func _create_close_icon_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2, size / 2)
	var radius := 48.0
	var ring_thickness := 3.0
	var x_thickness := 3.0
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var d := p.distance_to(center)
			var on_ring: bool = abs(d - radius) <= ring_thickness
			var on_diag_a: bool = abs(float(x - y)) <= x_thickness
			var on_diag_b: bool = abs(float((size - 1 - x) - y)) <= x_thickness
			if on_ring or on_diag_a or on_diag_b:
				img.set_pixel(x, y, Color(1, 1, 1, 0.95))
	return ImageTexture.create_from_image(img)

func _basis_from_y_axis(target_dir: Vector3) -> Basis:
	var y := target_dir.normalized()
	var up := Vector3.UP
	if abs(y.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var x := up.cross(y).normalized()
	var z := y.cross(x).normalized()
	return Basis(x, y, z)
