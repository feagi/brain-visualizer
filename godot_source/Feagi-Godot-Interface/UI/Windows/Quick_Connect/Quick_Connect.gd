extends Panel
var src = ""
var destination = "" # updates from cortical_area_box node's script
var morphology_list # list of morphology

func _ready():
	$TitleBar/Title_Text.text = "Quick_Connect"


func updated_morphology():
	morphology_list = FeagiCache.morphology_cache.available_morphologies
	$morphology_menulist/Scroll_Vertical._ready()
	
func _on_source_pressed():
	$source.text = "Select a cortical"

func _on_destination_pressed():
	$destination.text = "Select a cortical"

func _on_ca_connect_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		morphology_list = []
		for i in FeagiCache.morphology_cache.available_morphologies:
			morphology_list.append(i)
		$morphology_menulist.dir_contents("res://Feagi-Godot-Interface/UI/Resources/morphology_icons/")


func _on_arrow_pressed():
	$morphology_menulist.visible = true


func _on_visibility_changed():
	if not visible:
		$morphology_menulist.visible = false
		$source.text = "Source"
		$destination.text = "Destination"
		$arrow/Label.text = "Select a morphology"


func _on_connect_pressed():
	var source_id = src
	var destination_id = destination
	var morphology_name = $arrow/Label.text
	# Pretty simple check to try to prevent invalid connections
	# TODO WARNING: This is not a safe way of handling this, this script should be redone
	if source_id not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		return
	if destination_id not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		return
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		return

	var source_area: CorticalArea = FeagiCache.cortical_areas_cache.cortical_areas[source_id]
	var destination_area: CorticalArea = FeagiCache.cortical_areas_cache.cortical_areas[destination_id]
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[morphology_name]
	visible = false
	FeagiRequests.request_default_mapping_between_corticals(source_area, destination_area, morphology_used)
	
	$"../../Brain_Visualizer".update_all_node_from_cortical(source_id, global_material.deselected)
	$"../../Brain_Visualizer".update_all_node_from_cortical(destination, global_material.deselected)

func _on_texture_button_pressed(value):
	$arrow/Label.text = value
	$morphology_menulist.visible = false
