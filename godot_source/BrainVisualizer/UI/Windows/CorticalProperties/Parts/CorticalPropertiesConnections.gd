extends VBoxContainer
class_name CorticalPropertiesConnections

var _scroll_afferent: ScrollSectionGeneric
var _scroll_efferent: ScrollSectionGeneric
var _recursive: Button
var _cortical_area_ref: AbstractCorticalArea

func _ready() -> void:
	_scroll_afferent = $Afferents
	_scroll_efferent = $Efferents
	_recursive = $recursive


## Get initial connections when the window is created
func initial_values_from_FEAGI(cortical_reference: AbstractCorticalArea) -> void:
	_cortical_area_ref = cortical_reference
	
	# Recursive
	for recursive_area: AbstractCorticalArea in cortical_reference.recursive_mappings.keys():
		_add_recursive_area(recursive_area)
	
	# Inputs
	for afferent_area: AbstractCorticalArea in cortical_reference.afferent_mappings.keys():
		_add_afferent_area(afferent_area)
		afferent_area.afferent_input_cortical_area_removed.connect(_remove_afferent_area)
	# Outputs
	for efferent_area: AbstractCorticalArea in cortical_reference.efferent_mappings.keys():
		_add_efferent_area(efferent_area)
		efferent_area.efferent_input_cortical_area_removed.connect(_remove_efferent_area)
	
	cortical_reference.recursive_cortical_area_added.connect(_add_recursive_area)
	cortical_reference.recursive_cortical_area_added.connect(_remove_recursive_area)
	cortical_reference.afferent_input_cortical_area_added.connect(_add_afferent_area)
	cortical_reference.efferent_input_cortical_area_added.connect(_add_efferent_area)
	cortical_reference.afferent_input_cortical_area_removed.connect(_remove_afferent_area)
	cortical_reference.efferent_input_cortical_area_removed.connect(_remove_efferent_area)
	_recursive.pressed.connect(_user_pressed_recursive_button)
	

func _add_recursive_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_recursive.text = "Recursive Connection"

func _add_afferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(area, _cortical_area_ref)
	var item: ScrollSectionGenericItem = _scroll_afferent.add_text_button_with_delete(
		area,
		" " + area.friendly_name + " ",
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	var delete_request: Callable = FeagiCore.requests.delete_mappings_between_corticals.bind(area, _cortical_area_ref)
	var delete_popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Delete these mappings?",
		"Are you sure you wish to delete the mappings from %s to this cortical area?" % area.friendly_name,
		delete_request,
		"Yes"
		)
	var popup_request: Callable = BV.WM.spawn_popup.bind(delete_popup)
	item.get_delete_button().pressed.connect(popup_request)

func _add_efferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(_cortical_area_ref, area)
	var item: ScrollSectionGenericItem = _scroll_efferent.add_text_button_with_delete(
		area,
		area.friendly_name,
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	var delete_request: Callable = FeagiCore.requests.delete_mappings_between_corticals.bind(_cortical_area_ref, area)
	var delete_popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Delete these mappings?",
		"Are you sure you wish to delete the mappings from this cortical area to %s?" % area.friendly_name,
		delete_request,
		"Yes"
		)
	var popup_request: Callable = BV.WM.spawn_popup.bind(delete_popup)
	item.get_delete_button().pressed.connect(popup_request)


func _remove_recursive_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_recursive.text = "None Recursive"

func _remove_afferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_scroll_afferent.attempt_remove_item(area)

func _remove_efferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_scroll_efferent.attempt_remove_item(area)

func _user_pressed_recursive_button() -> void:
	BV.WM.spawn_mapping_editor(_cortical_area_ref, _cortical_area_ref)

func _user_pressed_add_afferent_button() -> void:
	BV.WM.spawn_mapping_editor(null, _cortical_area_ref)

func _user_pressed_add_efferent_button() -> void:
	BV.WM.spawn_mapping_editor(_cortical_area_ref, null)
