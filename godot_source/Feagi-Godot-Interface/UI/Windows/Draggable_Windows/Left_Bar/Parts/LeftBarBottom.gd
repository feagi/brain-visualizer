extends VBoxContainer
class_name LeftBarBottom

var _scroll_afferent: BaseScroll
var _scroll_efferent: BaseScroll
var _delete_button: TextButton_Element
var _cortical_area_ref: CorticalArea

func _ready() -> void:
	_scroll_afferent = $Afferent
	_scroll_efferent = $Efferent
	_delete_button = $Delete_Button
	_delete_button.pressed.connect(_user_pressed_delete_button)


func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_reference
	
	# Afferent
	var afferents: Array[StringName] = cortical_reference.afferent_connections
	for aff in afferents:
		
		var spawned_afferent: LeftBarBottomMappingPrefab = _scroll_afferent.spawn_list_item(
			{
			"source": FeagiCache.cortical_areas_cache.cortical_areas[aff],
			"destination": cortical_reference,
			"aff2this": true
			}
			)
		# reverse connection!
	# Efferent
	# yes, more type array casting shenanigans
	var efferents: Array = cortical_reference.efferent_connections_with_count.keys()
	for eff in efferents:
		_scroll_afferent.spawn_list_item(
			{
			"source": cortical_reference,
			"destination": FeagiCache.cortical_areas_cache.cortical_areas[eff],
			"aff2this": false
			}
			)

func _user_pressed_delete_button():
	print("Left Bar requesting cortical area deletion")
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)
