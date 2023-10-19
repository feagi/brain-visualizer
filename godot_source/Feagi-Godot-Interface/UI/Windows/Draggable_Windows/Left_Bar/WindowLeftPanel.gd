extends DraggableWindow
class_name WindowLeftPanel

var section_toggles: Array[bool]:
	get:
		var output: Array[bool] = [_top_collapsible.is_open, _middle_collapsible.is_open, _premium_collapsible.is_open, _bottom_collapsible.is_open]
		return output
	set(v):
		if len(v) != 4:
			push_warning("Left Bar section_toggles must be 4 long!")
			return
		_top_collapsible.is_open = v[0]
		_middle_collapsible.is_open = v[1]
		_premium_collapsible.is_open = v[2]
		_bottom_collapsible.is_open = v[3]

var _cortical_area_ref: CorticalArea

var _top_collapsible: VerticalCollapsible
var _middle_collapsible: VerticalCollapsible
var _premium_collapsible: VerticalCollapsible
var _bottom_collapsible: VerticalCollapsible

var _top_section # cannot define type due to godot bug
var _middle_section
var _premium_section
var _bottom_section


func _ready():
	super._ready()
	_top_collapsible = $Main_Body/Top_Section
	_middle_collapsible = $Main_Body/Middle_Section
	_premium_collapsible = $Main_Body/Premium_Section
	_bottom_collapsible = $Main_Body/Bottom_Section
	_top_collapsible.setup()
	_middle_collapsible.setup()
	_premium_collapsible.setup()
	_bottom_collapsible.setup()
	if !(VisConfig.is_premium):
		_premium_collapsible.section_title = "(PREMIUM) Cortical Area Monitoring"
	
	_top_section = _top_collapsible.collapsing_node
	_middle_section = _middle_collapsible.collapsing_node
	_premium_section = _premium_collapsible.collapsing_node
	_bottom_section = _bottom_collapsible.collapsing_node
	_top_section.user_requested_update.connect(_user_requested_update)
	_middle_section.user_requested_update.connect(_user_requested_update)
	FeagiCacheEvents.cortical_area_removed.connect(_FEAGI_deleted_cortical_area)

## Load in initial values of the cortical area from Cache
func setup_from_FEAGI(cortical_area_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_area_reference
	print("loading Left Pane Window for cortical area " + cortical_area_reference.cortical_ID)
	_cortical_area_ref.dimensions_updated.connect(_top_section.FEAGI_set_cortical_dimension)
	_cortical_area_ref.coordinates_3D_updated.connect(_top_section.FEAGI_set_cortical_position)
	_cortical_area_ref.name_updated.connect(_top_section.FEAGI_set_cortical_name)
	_cortical_area_ref.details_updated.connect(_middle_section.FEAGI_set_properties)
	_top_section.initial_values_from_FEAGI(cortical_area_reference)
	_middle_section.initial_values_from_FEAGI(cortical_area_reference)
	_premium_section.initial_values_from_FEAGI(cortical_area_reference)
	_bottom_section.initial_values_from_FEAGI(cortical_area_reference)
	# Odds are we don't have the latest data from FEAGI, lets call in a refresh
	FeagiRequests.refresh_cortical_area(cortical_area_reference)

## OVERRIDDEN from Window manager, to save previous position and collapsible states
func save_to_memory() -> Dictionary:
	return {
		"position": position,
		"toggles": section_toggles
	}

## OVERRIDDEN from Window manager, to load previous position and collapsible states
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]
	if "toggles" in previous_data.keys():
		section_toggles = previous_data["toggles"]

## Called from top or middle, user sent dict of properties to request FEAGI to set
func _user_requested_update(changed_values: Dictionary) -> void:
	FeagiRequests.set_cortical_area_properties(_cortical_area_ref.cortical_ID, changed_values)

## Called via delete button press (signal connected via tscn)
func _user_pressed_delete_button() -> void:
	print("Left Bar requesting cortical area deletion")
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

func _FEAGI_deleted_cortical_area(removed_cortical_area: CorticalArea):
	# confirm this is the cortical area removed
	if removed_cortical_area.cortical_ID == _cortical_area_ref.cortical_ID:
		close_window("left_bar")

