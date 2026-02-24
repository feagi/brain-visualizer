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
const CLOSE_LAYER: int = 1 << 20
const GIZMO_AXIS_LAYER: int = 1 << 19

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

	var shaft_len := axis_length - head_length
	var arrow_body := MeshInstance3D.new()
	arrow_body.name = "ArrowBody"
	arrow_body.mesh = _build_unibody_axis_arrow_mesh(shaft_len, shaft_radius, head_length, head_radius)

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = color
	shaft_mat.emission_enabled = true
	shaft_mat.emission = color
	shaft_mat.emission_energy = 0.8
	shaft_mat.no_depth_test = true
	arrow_body.material_override = shaft_mat

	# Godot cylinder is oriented along Y. Align Y to axis dir.
	arrow_body.transform.basis = _basis_from_y_axis(dir)
	# Place unibody arrow so it starts at origin and extends outward.
	arrow_body.position = dir.normalized() * (axis_length * 0.5)
	axis_root.add_child(arrow_body)

	# Collider (use a slightly fatter cylinder around the whole axis)
	var body := StaticBody3D.new()
	body.name = "Pick_%s" % AXIS.keys()[axis]
	body.set_meta(META_AXIS, axis)
	body.set_meta(META_KIND, KIND_MOVE if _mode == MODE.MOVE else KIND_RESIZE)
	body.collision_layer = GIZMO_AXIS_LAYER
	body.collision_mask = GIZMO_AXIS_LAYER

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

func _build_unibody_axis_arrow_mesh(shaft_len: float, shaft_radius: float, head_length: float, head_radius: float) -> ArrayMesh:
	var tip_radius := maxf(0.001, head_radius * 0.06)
	var total_len := shaft_len + head_length
	var bottom_y := -total_len * 0.5
	var shaft_top_y := bottom_y + shaft_len
	var tip_y := total_len * 0.5
	var transition_h := maxf(0.01, head_length * 0.35)

	var profile: Array[Vector2] = [
		Vector2(shaft_radius, bottom_y),
		Vector2(shaft_radius, shaft_top_y - transition_h),
		Vector2(lerpf(head_radius, shaft_radius, 0.55), shaft_top_y - transition_h * 0.55),
		Vector2(head_radius, shaft_top_y),
		Vector2(head_radius * 0.52, shaft_top_y + head_length * 0.48),
		Vector2(head_radius * 0.22, shaft_top_y + head_length * 0.78),
		Vector2(tip_radius, tip_y),
	]
	return _build_revolved_profile_mesh(profile, 14)

func _build_revolved_profile_mesh(profile: Array[Vector2], radial_segments: int) -> ArrayMesh:
	if profile.size() < 2:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ring_idx in range(profile.size()):
		var radius := maxf(0.0, profile[ring_idx].x)
		var y := profile[ring_idx].y
		for seg_idx in range(radial_segments):
			var t := float(seg_idx) / float(radial_segments)
			var angle := t * TAU
			var x := cos(angle) * radius
			var z := sin(angle) * radius
			st.set_uv(Vector2(t, float(ring_idx) / float(profile.size() - 1)))
			st.add_vertex(Vector3(x, y, z))

	for ring_idx in range(profile.size() - 1):
		var ring_start := ring_idx * radial_segments
		var next_ring_start := (ring_idx + 1) * radial_segments
		for seg_idx in range(radial_segments):
			var next_seg := (seg_idx + 1) % radial_segments
			var a := ring_start + seg_idx
			var b := ring_start + next_seg
			var c := next_ring_start + seg_idx
			var d := next_ring_start + next_seg
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)

	st.generate_normals()
	return st.commit()

func _add_close_handle(axis_length: float) -> void:
	## Close handle is a camera-facing sprite + collider for click.
	var close_root := Node3D.new()
	close_root.name = "CloseHandle"
	add_child(close_root)
	_close_root = close_root

	var sprite := Sprite3D.new()
	sprite.texture = _create_close_icon_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.01
	sprite.no_depth_test = true
	close_root.add_child(sprite)
	_close_sprite = sprite

	var body := StaticBody3D.new()
	body.name = "Pick_Close"
	body.set_meta(META_KIND, KIND_CLOSE)
	body.collision_layer = CLOSE_LAYER
	body.collision_mask = CLOSE_LAYER
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
	## Called by the 3D scene to reposition the close handle.
	if _close_root == null:
		return
	_close_root.global_position = world_pos

## Grow/shrink close handle on hover so it's clearly interactive.
func set_close_hovered(is_hovered: bool) -> void:
	## Grow/shrink close handle on hover so it's clearly interactive.
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
	## Builds a white X with a circular outline as a Sprite3D texture.
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
