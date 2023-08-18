extends Node3D
var _shaderMat # EXPERIMENT
# Called when the node enters the scene tree for the first time.
func _ready():
	FeagiCacheEvents.cortical_area_added.connect(on_cortical_area_added)
	_shaderMat = $cortical_area_box.mesh.material # EXPERIMENT

func on_cortical_area_added(cortical_area: CorticalArea) -> void:
	generate_cortical_area(cortical_area)

func generate_cortical_area(cortical_area_data : CorticalArea):
	var new_node = $cortical_area_box.duplicate()
	new_node.visible = true
	new_node.set_name(cortical_area_data.name)
	new_node.scale = cortical_area_data.dimensions
	new_node.transform.origin = Vector3(cortical_area_data.coordinates_3D) * Vector3(1,1,-1)
	add_child(new_node)

## EXPERMENTING SHADER ONLY. NOT GOING TO BE OFFICIAL CODE
func _process(delta):
	UpdateRenderShader()

func UpdateRenderShader():
	_shaderMat.set_shader_parameter("ballPos", 0.5)
	_shaderMat.set_shader_parameter("paddlePosX", 0.0)
	_shaderMat.set_shader_parameter("isCurrentlyShocking", false)

## EXPERIMENTING ENDS
