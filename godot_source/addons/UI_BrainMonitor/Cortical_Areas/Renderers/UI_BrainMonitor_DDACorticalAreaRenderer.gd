extends UI_BrainMonitor_AbstractCorticalAreaRenderer
class_name UI_BrainMonitor_DDACorticalAreaRenderer
## Renders a cortical area using the DDA Shader on a Box Mesh

const DDA_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA_CA_mat.tres"

var _child_mesh_instance: MeshInstance3D
var _child_box_mesh: BoxMesh
var _DDA_mat: ShaderMaterial

# TODO shader stuff

func setup(area: AbstractCorticalArea) -> void:
	_child_mesh_instance = MeshInstance3D.new()
	_child_box_mesh = BoxMesh.new()
	_DDA_mat = load(DDA_MAT_PATH).duplicate()
	_child_mesh_instance.mesh = _child_box_mesh
	_child_box_mesh.material = _DDA_mat
	add_child(_child_mesh_instance)
	
	# Set initial properties
	update_friendly_name(area.friendly_name)
	update_position(area.coordinates_3D)
	update_dimensions(area.dimensions_3D)
	

func update_friendly_name(new_name: String) -> void:
	print(new_name) # TODO

func update_position(new_position: Vector3i) -> void:
	_child_mesh_instance.position = new_position

func update_dimensions(new_dimensions: Vector3i) -> void:
	_child_box_mesh.size = new_dimensions

# TODO other controls
