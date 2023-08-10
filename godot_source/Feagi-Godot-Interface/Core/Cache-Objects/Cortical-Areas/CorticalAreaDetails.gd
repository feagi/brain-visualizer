extends Object
class_name CorticalAreaDetails
## Holds details of a cortical area not generally required except when looking in the side bar details

signal property_changed(property_changed_with_value: Dictionary)

var cortical_neuron_per_vox_count: int:
    get: return _cortical_neuron_per_vox_count
    set(v):
        _cortical_neuron_per_vox_count = v
        property_changed.emit({"cortical_neuron_per_vox_count": v})

var cortical_synaptic_attractivity: int:
    get: return _cortical_synaptic_attractivity
    set(v):
        _cortical_synaptic_attractivity = v
        property_changed.emit({"cortical_synaptic_attractivity": v})

var cortical_destinations: Dictionary:
    get: return _cortical_destinations
    set(v):
        _cortical_destinations = _process_cortical_destinations(v)
        # Be wary with this one, since the dictionary was converted to an CorticalMappingProperties object. Use the 'to_dictionary' method to change it back before sending to feagi
        property_changed.emit({"cortical_destinations": v})

var neuron_post_synaptic_potential: float:
    get: return _neuron_post_synaptic_potential
    set(v):
        _neuron_post_synaptic_potential = v
        property_changed.emit({"neuron_post_synaptic_potential": v})

var neuron_post_synaptic_potential_max: float:
    get: return _neuron_post_synaptic_potential_max
    set(v):
        _neuron_post_synaptic_potential_max = v
        property_changed.emit({"neuron_post_synaptic_potential_max": v})

var neuron_plasticity_constant: float:
    get: return _neuron_plasticity_constant
    set(v):
        _neuron_plasticity_constant = v
        property_changed.emit({"neuron_plasticity_constant": v})

var neuron_fire_threshold: float:
    get: return _neuron_fire_threshold
    set(v):
        _neuron_fire_threshold = v
        property_changed.emit({"neuron_fire_threshold": v})

var neuron_fire_threshold_increment: float:
    get: return _neuron_fire_threshold_increment
    set(v):
        _neuron_fire_threshold_increment = v
        property_changed.emit({"neuron_fire_threshold_increment": v})

var neuron_firing_threshold_limit: float:
    get: return _neuron_firing_threshold_limit
    set(v):
        _neuron_firing_threshold_limit = v
        property_changed.emit({"neuron_firing_threshold_limit": v})

var neuron_refractory_period: float:
    get: return _neuron_refractory_period
    set(v):
        _neuron_refractory_period = v
        property_changed.emit({"neuron_refractory_period": v})

var neuron_leak_coefficient: float:
    get: return _neuron_leak_coefficient
    set(v):
        _neuron_leak_coefficient = v
        property_changed.emit({"neuron_leak_coefficient": v})

var neuron_leak_variability: float:
    get: return _neuron_leak_variability
    set(v):
        _neuron_leak_variability = v
        property_changed.emit({"neuron_leak_variability": v})

var neuron_consecutive_fire_count: float:
    get: return _neuron_consecutive_fire_count
    set(v):
        _neuron_consecutive_fire_count = v
        property_changed.emit({"neuron_consecutive_fire_count": v})

var neuron_snooze_period: float:
    get: return _neuron_snooze_period
    set(v):
        _neuron_snooze_period = v
        property_changed.emit({"neuron_snooze_period": v})

var neuron_degeneracy_coefficient: float:
    get: return _neuron_degeneracy_coefficient
    set(v):
        _neuron_degeneracy_coefficient = v
        property_changed.emit({"neuron_degeneracy_coefficient": v})

var neuron_psp_uniform_distribution: bool:
    get: return _neuron_psp_uniform_distribution
    set(v):
        _neuron_psp_uniform_distribution = v
        property_changed.emit({"neuron_psp_uniform_distribution": v})

var neuron_mp_charge_accumulation: bool:
    get: return _neuron_mp_charge_accumulation
    set(v):
        _neuron_mp_charge_accumulation = v
        property_changed.emit({"neuron_mp_charge_accumulation": v})

var _cortical_neuron_per_vox_count: int = 0
var _cortical_synaptic_attractivity: int = 0
var _cortical_destinations: Dictionary = {}
var _neuron_post_synaptic_potential: float = 0
var _neuron_post_synaptic_potential_max: float = 0
var _neuron_plasticity_constant: float = 0
var _neuron_fire_threshold: float = 0
var _neuron_fire_threshold_increment: float = 0
var _neuron_firing_threshold_limit: float = 0
var _neuron_refractory_period: float = 0
var _neuron_leak_coefficient: float = 0
var _neuron_leak_variability: float = 0
var _neuron_consecutive_fire_count: float = 0
var _neuron_snooze_period: float = 0
var _neuron_degeneracy_coefficient: float = 0
var _neuron_psp_uniform_distribution: bool = false
var _neuron_mp_charge_accumulation: bool = false

## Updates all variables in here from a dict from FEAGI
func apply_dictionary(data: Dictionary) -> void:
    
    if data == {}:
        return
    if "cortical_neuron_per_vox_count" in data.keys(): 
        _cortical_neuron_per_vox_count = data["cortical_neuron_per_vox_count"]
    if "cortical_synaptic_attractivity" in data.keys(): 
        _cortical_synaptic_attractivity = data["cortical_synaptic_attractivity"]
    if "cortical_destinations" in data.keys(): 
        _cortical_destinations = _process_cortical_destinations(data["cortical_destinations"])
    if "neuron_post_synaptic_potential" in data.keys(): 
        _neuron_post_synaptic_potential = data["neuron_post_synaptic_potential"]
    if "neuron_post_synaptic_potential_max" in data.keys(): 
        _neuron_post_synaptic_potential_max = data["neuron_post_synaptic_potential_max"]
    if "neuron_plasticity_constant" in data.keys(): 
        _neuron_plasticity_constant = data["neuron_plasticity_constant"]
    if "neuron_fire_threshold" in data.keys(): 
        _neuron_fire_threshold = data["neuron_fire_threshold"]
    if "neuron_fire_threshold_increment" in data.keys(): 
        _neuron_fire_threshold_increment = data["neuron_fire_threshold_increment"]
    if "neuron_firing_threshold_limit" in data.keys(): 
        _neuron_firing_threshold_limit = data["neuron_firing_threshold_limit"]
    if "neuron_refractory_period" in data.keys(): 
        _neuron_refractory_period = data["neuron_refractory_period"]
    if "neuron_leak_coefficient" in data.keys(): 
        _neuron_leak_coefficient = data["neuron_leak_coefficient"]
    if "neuron_leak_variability" in data.keys(): 
        _neuron_leak_variability = data["neuron_leak_variability"]
    if "neuron_consecutive_fire_count" in data.keys(): 
        _neuron_consecutive_fire_count = data["neuron_consecutive_fire_count"]
    if "neuron_snooze_period" in data.keys(): 
        _neuron_snooze_period = data["neuron_snooze_period"]
    if "neuron_degeneracy_coefficient" in data.keys(): 
        _neuron_degeneracy_coefficient = data["neuron_degeneracy_coefficient"]
    if "neuron_psp_uniform_distribution" in data.keys(): 
        _neuron_psp_uniform_distribution = data["neuron_psp_uniform_distribution"]
    if "neuron_mp_charge_accumulation" in data.keys(): 
        _neuron_mp_charge_accumulation = data["neuron_mp_charge_accumulation"]

## Converts dictionary from FEAGI into dictionary referring to CorticalMappingProperties objects
func _process_cortical_destinations(raw_dict: Dictionary) -> Dictionary:
    var output: Dictionary = {}
    for cortexID_str in raw_dict.keys():
        var array_per_cortical_area: Array[CorticalMappingProperties] = []
        for raw_CMP in raw_dict[cortexID_str]:
            array_per_cortical_area.append(CorticalMappingProperties.new(raw_CMP))
        output[cortexID_str] = array_per_cortical_area
    return output

