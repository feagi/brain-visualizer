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

var _mode: MODE = MODE.MOVE
var _axis_length: float = 0.0

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

func _basis_from_y_axis(target_dir: Vector3) -> Basis:
	var y := target_dir.normalized()
	var up := Vector3.UP
	if abs(y.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var x := up.cross(y).normalized()
	var z := y.cross(x).normalized()
	return Basis(x, y, z)
