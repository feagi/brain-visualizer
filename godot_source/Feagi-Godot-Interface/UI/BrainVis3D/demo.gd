extends Node



# Called when the node enters the scene tree for the first time.
func _ready():
	FeagiCacheEvents.cortical_area_added.connect(on_cortical_area_added)

func on_cortical_area_added(cortical_area: CorticalArea) -> void:
	print(cortical_area.dimensions.x)
	print(cortical_area.dimensions.y)
	print(cortical_area.dimensions.z)
