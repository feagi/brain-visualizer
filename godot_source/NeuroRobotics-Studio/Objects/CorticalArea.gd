extends Object
class_name CorticalArea

# This object is intended to be used as a 'cache' for a specific cortical area



var timeOfLastCorticalAreaUpdate: float:
	get: return _lastCorticalAreaUpdatedUnixTimeStamp

var secondsSinceLastCorticalAreaUpdate: float:
	get: return  _lastCorticalAreaUpdatedUnixTimeStamp - Time.get_unix_time_from_system()

var ID: CortexID:
	get: return _ID

var cortical_group: String:
	get: return _cortical_group
	set(v): _ConfirmValidGroup(v)

var cortical_neuron_per_vox_count: int:
	get: return _cortical_neuron_per_vox_count
	set(v):
		_cortical_neuron_per_vox_count = v

var cortical_visibility: bool:
	get: return _cortical_visibility
	set(v):
		_cortical_visibility = v

var cortical_synaptic_attractivity: int:
	get: return _cortical_synaptic_attractivity
	set(v):
		_cortical_synaptic_attractivity = v

var cortical_coordinates_3D: Vector3i:
	get: return _cortical_coordinates_3D
	set(v):
		_cortical_coordinates_3D = v

var cortical_coordinates_2D: Vector2i:
	get: 
		if _2D_coordinates_isDefined:
			return _cortical_coordinates_2D
		push_warning("Trying to load 2D coordinates when none exist for cortex " + ID.str)
		return Vector2(0,0) # must be here to allow compiling
	set(v):
		_cortical_coordinates_2D = v
		_2D_coordinates_isDefined = true

var cortical_dimensions: Vector3:
	get: return _cortical_dimensions
	set(v):
		_cortical_dimensions = v

var cortical_destinations: Dictionary:
	get: return _cortical_destinations
	set(v):
		_cortical_destinations = v

var neuron_post_synaptic_potential: float:
	get: return _neuron_post_synaptic_potential
	set(v):
		_neuron_post_synaptic_potential = v

var neuron_post_synaptic_potential_max: float:
	get: return _neuron_post_synaptic_potential_max
	set(v):
		_neuron_post_synaptic_potential_max = v

var neuron_plasticity_constant: float:
	get: return _neuron_plasticity_constant
	set(v):
		_neuron_plasticity_constant = v

var neuron_fire_threshold: float:
	get: return _neuron_fire_threshold
	set(v):
		_neuron_fire_threshold = v

var neuron_fire_threshold_increment: float:
	get: return _neuron_fire_threshold_increment
	set(v):
		_neuron_fire_threshold_increment = v

var neuron_firing_threshold_limit: float:
	get: return _neuron_firing_threshold_limit
	set(v):
		_neuron_firing_threshold_limit = v

var neuron_refractory_period: float:
	get: return _neuron_refractory_period
	set(v):
		_neuron_refractory_period = v

var neuron_leak_coefficient: float:
	get: return _neuron_leak_coefficient
	set(v):
		_neuron_leak_coefficient = v

var neuron_leak_variability: float:
	get: return _neuron_leak_variability
	set(v):
		_neuron_leak_variability = v

var neuron_consecutive_fire_count: float:
	get: return _neuron_consecutive_fire_count
	set(v):
		_neuron_consecutive_fire_count = v

var neuron_snooze_period: float:
	get: return _neuron_snooze_period
	set(v):
		_neuron_snooze_period = v

var neuron_degeneracy_coefficient: float:
	get: return _neuron_degeneracy_coefficient
	set(v):
		_neuron_degeneracy_coefficient = v

var neuron_psp_uniform_distribution: bool:
	get: return _neuron_psp_uniform_distribution
	set(v):
		_neuron_psp_uniform_distribution = v

var neuron_mp_charge_accumulation: bool:
	get: return _neuron_mp_charge_accumulation
	set(v):
		_neuron_mp_charge_accumulation = v

var connectedTowards: Dictionary:
	get: return _connectedTowards


var _coreRef: Core
var _lastCorticalAreaUpdatedUnixTimeStamp: float = -1.0
var _ID: CortexID
var _cortical_name: String
var _cortical_group: String
var _cortical_neuron_per_vox_count: int
var _cortical_visibility: bool
var _cortical_synaptic_attractivity: int
var _cortical_coordinates_3D: Vector3i = Vector3i(0,0,0)
var _cortical_coordinates_2D: Vector2i
var _2D_coordinates_isDefined: bool = false
var _cortical_dimensions: Vector3
var _cortical_destinations: Dictionary
var _neuron_post_synaptic_potential: float
var _neuron_post_synaptic_potential_max: float
var _neuron_plasticity_constant: float
var _neuron_fire_threshold: float
var _neuron_fire_threshold_increment: float
var _neuron_firing_threshold_limit: float
var _neuron_refractory_period: float
var _neuron_leak_coefficient: float
var _neuron_leak_variability: float
var _neuron_consecutive_fire_count: float
var _neuron_snooze_period: float
var _neuron_degeneracy_coefficient: float
var _neuron_psp_uniform_distribution: bool
var _neuron_mp_charge_accumulation: bool
var _connectedTowards: Dictionary = {}


func ApplyDictionary(data: Dictionary) -> void:
	
	if "cortical_id" in data.keys(): _ID = CortexID.new(data["cortical_id"])
	if "cortical_name" in data.keys(): _cortical_name = data["cortical_name"]
	if "cortical_group" in data.keys(): _ConfirmValidGroup(data["cortical_group"])
	if "cortical_neuron_per_vox_count" in data.keys(): _cortical_neuron_per_vox_count = data["cortical_neuron_per_vox_count"]
	if "cortical_visibility" in data.keys(): _cortical_visibility = data["cortical_visibility"]
	if "cortical_synaptic_attractivity" in data.keys(): _cortical_synaptic_attractivity = data["cortical_synaptic_attractivity"]
	if "cortical_coordinates" in data.keys(): _cortical_coordinates_3D = HelperFuncs.Array2Vector3i(data["cortical_coordinates"])
	if "cortical_coordinates_2d" in data.keys(): _cortical_coordinates_2D = HelperFuncs.Array2Vector2i(data["cortical_coordinates_2d"]); _2D_coordinates_isDefined = true
	if "cortical_dimensions" in data.keys(): _cortical_dimensions = HelperFuncs.Array2Vector3(data["cortical_dimensions"])
	if "cortical_destinations" in data.keys(): _cortical_destinations = data["cortical_destinations"]
	if "neuron_post_synaptic_potential" in data.keys(): _neuron_post_synaptic_potential = data["neuron_post_synaptic_potential"]
	if "neuron_post_synaptic_potential_max" in data.keys(): _neuron_post_synaptic_potential_max = data["neuron_post_synaptic_potential_max"]
	if "neuron_plasticity_constant" in data.keys(): _neuron_plasticity_constant = data["neuron_plasticity_constant"]
	if "neuron_fire_threshold" in data.keys(): _neuron_fire_threshold = data["neuron_fire_threshold"]
	if "neuron_fire_threshold_increment" in data.keys(): _neuron_fire_threshold_increment = data["neuron_fire_threshold_increment"]
	if "neuron_firing_threshold_limit" in data.keys(): _neuron_firing_threshold_limit = data["neuron_firing_threshold_limit"]
	if "neuron_refractory_period" in data.keys(): _neuron_refractory_period = data["neuron_refractory_period"]
	if "neuron_leak_coefficient" in data.keys(): _neuron_leak_coefficient = data["neuron_leak_coefficient"]
	if "neuron_leak_variability" in data.keys(): _neuron_leak_variability = data["neuron_leak_variability"]
	if "neuron_consecutive_fire_count" in data.keys(): _neuron_consecutive_fire_count = data["neuron_consecutive_fire_count"]
	if "neuron_snooze_period" in data.keys(): _neuron_snooze_period = data["neuron_snooze_period"]
	if "neuron_degeneracy_coefficient" in data.keys(): _neuron_degeneracy_coefficient = data["neuron_degeneracy_coefficient"]
	if "neuron_psp_uniform_distribution" in data.keys(): _neuron_psp_uniform_distribution = data["neuron_psp_uniform_distribution"]
	if "neuron_mp_charge_accumulation" in data.keys(): _neuron_mp_charge_accumulation = data["neuron_mp_charge_accumulation"]

func ProxyUpdate_Genome_CortialArea() -> void:
	# This function calls for an update from feagi of the current cortical area information.
	# This takes time, and thus is NOT instant, please beware while using this in code
	_coreRef.Update_Genome_CorticalArea_SPECIFIC(ID.str)
	


func _init(corticalID: String, corticalName: String, coreReference: Core, data: Dictionary = {}):
	_ID = CortexID.new(corticalID)
	_cortical_name = corticalName
	_coreRef = coreReference
	ApplyDictionary(data)

func _Update_Genome_CorticalArea(data: Dictionary) -> void:
	_lastCorticalAreaUpdatedUnixTimeStamp = Time.get_unix_time_from_system()
	ApplyDictionary(data)
	

func _ConfirmValidGroup(checking: String) -> void:
	
	if REF.CORTICALTYPE.has(checking):
		_cortical_group = checking
		return
	@warning_ignore("assert_always_false")
	assert(false, "Invalid cortical area group:" + checking)


