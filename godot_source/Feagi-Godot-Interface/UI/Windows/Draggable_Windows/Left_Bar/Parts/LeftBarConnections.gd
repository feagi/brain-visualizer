extends VBoxContainer
class_name LeftBarConnections

var _scroll_afferent: BaseScroll
var _scroll_efferent: BaseScroll
var _cortical_area_ref: BaseCorticalArea

func _ready() -> void:
	_scroll_afferent = $Afferent
	_scroll_efferent = $Efferent

## Get initial connections when the window is created
func initial_values_from_FEAGI(cortical_reference: BaseCorticalArea) -> void:
	_cortical_area_ref = cortical_reference
	
	# Afferent
	for aff: BaseCorticalArea in cortical_reference.afferent_connections:
		
		_scroll_afferent.spawn_list_item(
			{
			"source": aff,
			"destination": cortical_reference,
			"aff2this": true
			}
			)

	# Efferent
	# yes, more type array casting shenanigans
	for eff: BaseCorticalArea in cortical_reference.efferent_connections:
		_scroll_efferent.spawn_list_item(
			{
			"source": cortical_reference,
			"destination": eff,
			"aff2this": false
			}
			)
	
	cortical_reference.efferent_mapping_added.connect(_add_efferent_connection)
	cortical_reference.afferent_mapping_added.connect(_add_afferent_connection)
	

func _add_efferent_connection(mappings: MappingProperties):
	_scroll_efferent.spawn_list_item(
		{
			"source": _cortical_area_ref,
			"destination": mappings.destination_cortical_area,
			"aff2this": false
		}
	)

func _add_afferent_connection(mappings: MappingProperties):
	_scroll_afferent.spawn_list_item(
		{
			"source": mappings.source_cortical_area,
			"destination": _cortical_area_ref,
			"aff2this": true
		}
	)

func _remove_efferent_connection(efferent_area: BaseCorticalArea):
	_scroll_efferent.remove_child_by_name(efferent_area.cortical_ID)

func _remove_afferent_connection(afferent_area: BaseCorticalArea):
	_scroll_afferent.remove_child_by_name(afferent_area.cortical_ID)

func _user_pressed_add_afferent_button() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(null, _cortical_area_ref)

func _user_pressed_add_efferent_button() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_cortical_area_ref, null)
