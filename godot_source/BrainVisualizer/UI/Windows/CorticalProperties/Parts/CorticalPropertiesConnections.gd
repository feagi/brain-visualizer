extends VBoxContainer
class_name CorticalPropertiesConnections

var _scroll_afferent: ScrollSectionGeneric
var _scroll_efferent: ScrollSectionGeneric
var _cortical_area_ref: AbstractCorticalArea

func _ready() -> void:
	_scroll_afferent = $Afferents
	_scroll_efferent = $Efferents


## Get initial connections when the window is created
func initial_values_from_FEAGI(cortical_reference: AbstractCorticalArea) -> void:
	_cortical_area_ref = cortical_reference
	
	# Inputs
	for afferent_area: AbstractCorticalArea in cortical_reference.afferent_areas:
		_add_afferent_area(afferent_area)
	for efferent_area: AbstractCorticalArea in cortical_reference.efferent_areas:
		_add_efferent_area(efferent_area)
	
	cortical_reference.afferent_input_cortical_area_added.connect(_add_afferent_area)
	cortical_reference.efferent_input_cortical_area_added.connect(_add_efferent_area)
	cortical_reference.afferent_input_cortical_area_removed.connect(_add_afferent_area)
	cortical_reference.efferent_input_cortical_area_removed.connect(_add_efferent_area)

func _add_afferent_area(area: AbstractCorticalArea) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(area, _cortical_area_ref)
	var item: ScrollSectionGenericItem = _scroll_afferent.add_text_button_with_delete(
		area,
		" " + area.friendly_name + " ",
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	# item.get_delete_button().pressed.connect() #TODO delete confirmation

func _add_efferent_area(area: AbstractCorticalArea) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(_cortical_area_ref, area)
	var item: ScrollSectionGenericItem = _scroll_efferent.add_text_button_with_delete(
		area,
		area.friendly_name,
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	# item.get_delete_button().pressed.connect() #TODO delete confirmation

func _remove_afferent_area(area: AbstractCorticalArea) -> void:
	_scroll_afferent.attempt_remove_item(area)

func _remove_efferent_area(area: AbstractCorticalArea) -> void:
	_scroll_efferent.attempt_remove_item(area)

func _remove_efferent_connection(efferent_area: AbstractCorticalArea):
	_scroll_efferent.remove_child_by_name(efferent_area.cortical_ID)

func _remove_afferent_connection(afferent_area: AbstractCorticalArea):
	_scroll_afferent.remove_child_by_name(afferent_area.cortical_ID)

func _user_pressed_add_afferent_button() -> void:
	BV.WM.spawn_mapping_editor(null, _cortical_area_ref)

func _user_pressed_add_efferent_button() -> void:
	BV.WM.spawn_mapping_editor(_cortical_area_ref, null)