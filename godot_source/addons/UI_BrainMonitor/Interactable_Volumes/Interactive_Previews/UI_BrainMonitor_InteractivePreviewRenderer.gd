extends UI_BrainMonitor_AbstractInteractableVolumeRenderer
class_name UI_BrainMonitor_InteractivePreviewRenderer
## Handles rendering Interactive Previews

const PREFAB: PackedScene = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/Preview_Body.tscn")
const SHADER_SIMPLE_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/PreviewShaderMatSimple.tres"

var _showing_voxels: bool
var _static_body: StaticBody3D
var _mat: ShaderMaterial
var _existing_cortical_area: AbstractCorticalArea  # Store reference to existing area for dynamic sizing

func setup(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool, cortical_area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE = AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN, existing_cortical_area: AbstractCorticalArea = null) -> void:
	_showing_voxels = show_voxels
	_existing_cortical_area = existing_cortical_area  # Store reference for dynamic sizing
	_static_body = PREFAB.instantiate()
	
	# Create the appropriate mesh based on cortical area type
	var mesh_instance = _static_body.get_node("MeshInstance3D") as MeshInstance3D
	if cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Calculate dynamic memory sphere size based on dimensions and density
		var memory_sphere_size = _calculate_memory_sphere_size(initial_dimensions, existing_cortical_area)
		
		# Use sphere mesh for memory cortical areas to match their actual appearance
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = memory_sphere_size.x  # radius
		sphere_mesh.height = memory_sphere_size.y  # height
		sphere_mesh.radial_segments = 16
		sphere_mesh.rings = 8
		mesh_instance.mesh = sphere_mesh
		
		# Update collision shape to match
		var collision_shape = _static_body.get_node("CollisionShape3D") as CollisionShape3D
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = memory_sphere_size.x  # Match visual sphere
		collision_shape.shape = sphere_shape
		print("   🔮 Created DYNAMIC SPHERE preview for memory cortical area (radius: %.2f)" % memory_sphere_size.x)
	else:
		# Keep default box mesh for other types (including power, which would need special handling for cone shape)
		print("   📦 Using default BOX preview for cortical area type: ", cortical_area_type)
	
	if _showing_voxels:
		pass # todo
	else:
		_mat = load(SHADER_SIMPLE_MAT_PATH).duplicate()
	
	mesh_instance.material_override = _mat
	add_child(_static_body)
	
	_position_FEAGI_space = initial_FEAGI_position
	update_dimensions(initial_dimensions)

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	_static_body.position = _position_godot_space
	
func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space # Update position stuff too since these are based in Godot space
	
	# For memory areas, update sphere size when dimensions change
	var mesh_instance = _static_body.get_node("MeshInstance3D") as MeshInstance3D
	if mesh_instance.mesh is SphereMesh:
		var memory_sphere_size = _calculate_memory_sphere_size(new_dimensions, _existing_cortical_area)
		var sphere_mesh = mesh_instance.mesh as SphereMesh
		sphere_mesh.radius = memory_sphere_size.x
		sphere_mesh.height = memory_sphere_size.y
		
		# Update collision shape too
		var collision_shape = _static_body.get_node("CollisionShape3D") as CollisionShape3D
		if collision_shape.shape is SphereShape3D:
			var sphere_shape = collision_shape.shape as SphereShape3D
			sphere_shape.radius = memory_sphere_size.x
		
		print("   🔮 Updated memory sphere size to radius: %.2f" % memory_sphere_size.x)
	
	if _showing_voxels:
		pass # todo

## Calculate memory sphere size using same logic as the renderer
func _calculate_memory_sphere_size(dimensions: Vector3i, existing_cortical_area: AbstractCorticalArea = null) -> Vector2:
	# Use same logic as UI_BrainMonitor_DirectPointsCorticalAreaRenderer._update_memory_sphere_size
	var neuron_count: int
	
	if existing_cortical_area != null and existing_cortical_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Use actual neuron count from existing memory area
		neuron_count = existing_cortical_area.neuron_count
		print("   🔮 Using actual neuron count from existing memory area: %d" % neuron_count)
	else:
		# For new memory areas, assume default density of 1.0 (can be refined later)
		var default_density = 1.0
		neuron_count = int(float(dimensions.x * dimensions.y * dimensions.z) * default_density)
		print("   🔮 Using estimated neuron count for new memory area: %d" % neuron_count)
	
	# Base size: 1.0 (normal cortical area size)  
	# Scale factor: logarithmic scaling to prevent huge spheres
	var base_size = 1.0
	var scale_factor = 1.0
	
	if neuron_count > 0:
		# Logarithmic scaling: log10(neuron_count + 1) + 1
		# This gives: 0 neurons = 1.0x, 10 neurons = 2.0x, 100 neurons = 3.0x, etc.
		scale_factor = log(neuron_count + 1) / log(10) + 1.0
		# Cap the maximum size to prevent overly large spheres
		scale_factor = min(scale_factor, 5.0)  # Max 5x size
	
	var sphere_radius = base_size * scale_factor * 0.5  # 0.5 is the base radius
	var sphere_height = base_size * scale_factor * 1.0  # 1.0 is the base height
	
	return Vector2(sphere_radius, sphere_height)
