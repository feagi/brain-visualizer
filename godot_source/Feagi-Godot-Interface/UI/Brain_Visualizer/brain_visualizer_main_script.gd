extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	FeagiCacheEvents.cortical_area_added.connect(on_cortical_area_added)
	print("done")

func on_cortical_area_added(cortical_area: CorticalArea) -> void:
	generate_cortical_area(cortical_area)

func generate_cortical_area(cortical_area_data : CorticalArea):
	var new_node = $cortical_area_box.duplicate()
	new_node.visible = true
	new_node.set_name(cortical_area_data.name)
	new_node.scale = cortical_area_data.dimensions
	new_node.transform.origin = Vector3(cortical_area_data.coordinates_3D) * Vector3	(1,1,-1)
	add_child(new_node)
