extends Object
class_name CorticalArea

# This object is intended to be used as a 'cache' for a specific cortical area

var timeOfLastUpdate: float:
	get: return _lastUpdatedUnixTimeStamp

var secondsSinceLastUpdate: float:
	get: return  _lastUpdatedUnixTimeStamp - Time.get_unix_time_from_system()

var ID: CortexID:
	get: return _ID

var cortical_group: String:
	get: return _cortical_group
	set(v): _ConfirmValidGroup(v)





var _lastUpdatedUnixTimeStamp: float
var _ID: CortexID
var _cortical_name: String
var _cortical_group: String
var _cortical_neuron_per_vox_count: int
var _cortical_visibility: bool
var _cortical_synaptic_attractivity: int
var _cortical_coordinates_3D: Vector3
var _cortical_coordinates_2D: Vector2
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

func ApplyDictionary(data: Dictionary) -> void:
	if "cortical_name" in data.keys(): _cortical_name = data["cortical_name"]

func Update_Genome() -> void:
	# TODO
	_lastUpdatedUnixTimeStamp = Time.get_unix_time_from_system()
	


func _init(corticalID: String, corticalName: String, data: Dictionary = {}):
	_ID = CortexID.new(corticalID)
	_cortical_name = corticalName
	ApplyDictionary(data)


func _ConfirmValidGroup(checking: String) -> void:
	
	if REF.CORTICALTYPE.has(checking):
		_cortical_group = checking
		return
	@warning_ignore("assert_always_false")
	assert(false, "Invalid cortical area type:" + checking)


