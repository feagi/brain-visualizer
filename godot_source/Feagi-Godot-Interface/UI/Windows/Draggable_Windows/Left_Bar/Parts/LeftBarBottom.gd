extends VBoxContainer
class_name LeftBarBottom

var _scroll_afferent: BaseScroll
var _scroll_efferent: BaseScroll
var _cortical_area_ref: CorticalArea

func _ready() -> void:
	_scroll_afferent = $MarginContainer/Afferent
	_scroll_efferent = $MarginContainer2/Efferent

## Get initial connections when the window is created
func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_reference
	
	# Afferent
	var afferents: Array[StringName] = cortical_reference.afferent_connections
	for aff in afferents:
		
		_scroll_afferent.spawn_list_item(
			{
			"source": FeagiCache.cortical_areas_cache.cortical_areas[aff],
			"destination": cortical_reference,
			"aff2this": true
			}
			)

	# Efferent
	# yes, more type array casting shenanigans
	var efferents: Array = cortical_reference.efferent_connections_with_count.keys()
	for eff in efferents:
		_scroll_efferent.spawn_list_item(
			{
			"source": cortical_reference,
			"destination": FeagiCache.cortical_areas_cache.cortical_areas[eff],
			"aff2this": false
			}
			)
	
	cortical_reference.efferent_area_added.connect(_add_efferent_connection)
	cortical_reference.afferent_area_added.connect(_add_afferent_connection)
	cortical_reference.efferent_area_removed.connect(_remove_efferent_connection)
	cortical_reference.afferent_area_removed.connect(_remove_afferent_connection)
	

func _add_efferent_connection(efferent_area: CorticalArea):
	_scroll_efferent.spawn_list_item(
		{
			"source": _cortical_area_ref,
			"destination": efferent_area,
			"aff2this": false
		}
	)

func _add_afferent_connection(afferent_area: CorticalArea):
	_scroll_afferent.spawn_list_item(
		{
			"source": afferent_area,
			"destination": _cortical_area_ref,
			"aff2this": true
		}
	)

func _remove_efferent_connection(efferent_area: CorticalArea):
	_scroll_efferent.remove_child_by_name(efferent_area.cortical_ID)

func _remove_afferent_connection(afferent_area: CorticalArea):
	_scroll_afferent.remove_child_by_name(afferent_area.cortical_ID)

func _user_pressed_add_afferent_button() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(null, _cortical_area_ref)

func _user_pressed_add_efferent_button() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_cortical_area_ref, null)
