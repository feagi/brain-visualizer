extends BaseWindowPanel
class_name WindowCorticalProperties

var _cortical_area_ref: BaseCorticalArea

var collapsible_cortical: VerticalCollapsible
var collapsible_neuron_firing: VerticalCollapsible
var collapsible_post_synaptic_potential: VerticalCollapsible
var collapsible_memory: VerticalCollapsible
var collapsible_cortical_monitoring: VerticalCollapsible
var collapsible_connections: VerticalCollapsible
var collapsible_dangerzone: VerticalCollapsible

var section_cortical: CorticalPropertiesCorticalParameters
var section_neuron_firing: CorticalPropertiesNeuronFiringParameters
var section_post_synaptic_potential: CorticalPropertiesPostSynapticPotentialParameters
var section_memory: CorticalPropertiesMemoryParameters
var section_cortical_monitoring: CorticalPropertiesCorticalAreaMonitoring
var section_connections: CorticalPropertiesConnections
var section_dangerzone: CorticalPropertiesDangerZone

func _ready():
	_setup_base_window("left_bar")
	collapsible_cortical = $Main_Body/Cortical
	collapsible_neuron_firing = $Main_Body/Neuron_Firing
	collapsible_post_synaptic_potential = $Main_Body/Post_Synaptic_Potential
	collapsible_memory = $Main_Body/Memory
	collapsible_cortical_monitoring = $Main_Body/Coritcal_Monitoring
	collapsible_connections = $Main_Body/Connections
	collapsible_dangerzone = $Main_Body/DangerZone
	
	collapsible_cortical.setup()
	collapsible_neuron_firing.setup()
	collapsible_post_synaptic_potential.setup()
	collapsible_memory.setup()
	collapsible_cortical_monitoring.setup()
	collapsible_connections.setup()
	collapsible_dangerzone.setup()
	
	section_cortical = collapsible_cortical.collapsing_node
	section_neuron_firing = collapsible_neuron_firing.collapsing_node
	section_post_synaptic_potential = collapsible_post_synaptic_potential.collapsing_node
	section_memory = collapsible_memory.collapsing_node
	section_cortical_monitoring = collapsible_cortical_monitoring.collapsing_node
	section_connections = collapsible_connections.collapsing_node
	section_dangerzone = collapsible_dangerzone.collapsing_node
	
	section_cortical.top_panel = self
	
	section_cortical.user_requested_update.connect(_user_requested_update)
	section_neuron_firing.user_requested_update.connect(_user_requested_update)
	section_post_synaptic_potential.user_requested_update.connect(_user_requested_update)
	section_memory.user_requested_update.connect(_user_requested_update)
	
	FeagiCacheEvents.cortical_area_removed.connect(_FEAGI_deleted_cortical_area)
	if !(VisConfig.is_premium):
		collapsible_cortical_monitoring.section_title = "(PREMIUM) Cortical Area Monitoring"

## Load in initial values of the cortical area from Cache
func setup(cortical_area_reference: BaseCorticalArea) -> void:
	_cortical_area_ref = cortical_area_reference
	print("loading Cortical Properties Window for cortical area " + cortical_area_reference.cortical_ID)

	section_cortical.display_cortical_properties(cortical_area_reference)
	section_post_synaptic_potential.display_cortical_properties(cortical_area_reference)
	section_cortical_monitoring.display_cortical_properties(cortical_area_reference)
	section_connections.initial_values_from_FEAGI(cortical_area_reference)
	section_dangerzone.initial_values_from_FEAGI(cortical_area_reference)
	
	if cortical_area_reference.has_neuron_firing_parameters:
		section_neuron_firing.display_cortical_properties(cortical_area_reference)
		
	else:
		collapsible_neuron_firing.visible = false
	
	if cortical_area_reference.has_memory_parameters:
		section_memory.display_cortical_properties(cortical_area_reference)
	else:
		collapsible_memory.visible = false
	

	# Odds are we don't have the latest data from FEAGI, lets call in a refresh
	FeagiRequests.refresh_cortical_area(cortical_area_reference)

## OVERRIDDEN from Window manager, to save previous position and collapsible states
func save_to_memory() -> Dictionary:
	return {
		"position": position,
		"toggles": _get_expanded_sections()
	}

## OVERRIDDEN from Window manager, to load previous position and collapsible states
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]
	if "toggles" in previous_data.keys():
		_set_expanded_sections(previous_data["toggles"])

## Called from top or middle, user sent dict of properties to request FEAGI to set
func _user_requested_update(changed_values: Dictionary) -> void:
	FeagiRequests.set_cortical_area_properties(_cortical_area_ref.cortical_ID, changed_values)

func _FEAGI_deleted_cortical_area(removed_cortical_area: BaseCorticalArea):
	# confirm this is the cortical area removed
	if removed_cortical_area.cortical_ID == _cortical_area_ref.cortical_ID:
		close_window()

## Flexible method to return all collapsed sections in Cortical Properties
func _get_expanded_sections() -> Array[bool]:
	var main_body: Control = get_child(0)
	var output: Array[bool] = []
	for child in main_body.get_children():
		if child is VerticalCollapsible:
			output.append((child as VerticalCollapsible).is_open)
	return output

## Flexible method to set all collapsed sections in Cortical Properties
func _set_expanded_sections(expanded: Array[bool]) -> void:
	var collapsibles: Array[VerticalCollapsible] = []
	var main_body: Control = get_child(0)
	
	for child in main_body.get_children():
		if child is VerticalCollapsible:
			collapsibles.append((child as VerticalCollapsible))
	
	var max: int = len(collapsibles)
	if len(expanded) < max:
		max = len(expanded)
	
	for i: int in max:
		collapsibles[i].is_open = expanded[i]
	
