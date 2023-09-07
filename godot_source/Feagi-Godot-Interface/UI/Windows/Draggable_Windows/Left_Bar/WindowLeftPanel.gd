extends GrowingPanel
class_name WindowLeftPanel

signal window_closing()

var _cortical_area_ref: CorticalArea
var _top_section # cannot define type due to godot bug
var _middle_section
var _premium_section
var _bottom_section


func _ready():
	super._ready()
	var top_collapsible = $Main_Body/Top_Section
	var middle_collapsible = $Main_Body/Middle_Section
	var premium_collapsible = $Main_Body/Premium_Section
	var bottom_collapsible = $Main_Body/Bottom_Section
	top_collapsible.setup()
	middle_collapsible.setup()
	premium_collapsible.setup()
	bottom_collapsible.setup()
	if !(VisConfig.left_bar_allow_premium_monitoring):
		premium_collapsible.section_title = "(PREMIUM) Cortical Area Monitoring"
	
	_top_section = top_collapsible.collapsing_node
	_middle_section = middle_collapsible.collapsing_node
	_premium_section = premium_collapsible.collapsing_node
	_bottom_section = bottom_collapsible.collapsing_node
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
	_bottom_section.initial_values_from_FEAGI(cortical_area_reference)
	# Odds are we don't have the latest data from FEAGI, lets call in a refresh
	FeagiRequests.refresh_cortical_area(cortical_area_reference.cortical_ID)

func close_window():
	VisConfig.window_manager.force_close_window("left_bar")

## Called from top or middle, user sent dict of properties to request FEAGI to set
func _user_requested_update(changed_values: Dictionary) -> void:
	FeagiRequests.set_cortical_area_properties(_cortical_area_ref.cortical_ID, changed_values)

func _FEAGI_deleted_cortical_area(removed_cortical_area: CorticalArea):
	# confirm this is the cortical area removed
	if removed_cortical_area.cortical_ID == _cortical_area_ref.cortical_ID:
		close_window()

