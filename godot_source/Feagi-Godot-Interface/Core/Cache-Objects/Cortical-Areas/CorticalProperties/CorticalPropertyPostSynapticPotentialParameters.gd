extends Object
class_name CorticalPropertyPostSynapticPotentialParameters

signal neuron_psp_uniform_distribution_updated(new_val: bool, this_cortical_area: BaseCorticalArea)
signal neuron_neuron_mp_driven_psp_updated(new_val: bool, this_cortical_area: BaseCorticalArea)
signal neuron_post_synaptic_potential_updated(new_val: float, this_cortical_area: BaseCorticalArea)
signal neuron_post_synaptic_potential_max_updated(new_val: float, this_cortical_area: BaseCorticalArea)
signal neuron_degeneracy_coefficient_updated(new_val: int, this_cortical_area: BaseCorticalArea)

## Apply Properties from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if "neuron_post_synaptic_potential" in data.keys(): 
		neuron_post_synaptic_potential = data["neuron_post_synaptic_potential"]
	if "neuron_post_synaptic_potential_max" in data.keys(): 
		neuron_post_synaptic_potential_max = data["neuron_post_synaptic_potential_max"]
	if "neuron_degeneracy_coefficient" in data.keys(): 
		neuron_degeneracy_coefficient = data["neuron_degeneracy_coefficient"]
	if "neuron_psp_uniform_distribution" in data.keys(): 
		neuron_psp_uniform_distribution = data["neuron_psp_uniform_distribution"]
	if "neuron_mp_driven_psp" in data.keys():
		neuron_mp_driven_psp = data["neuron_mp_driven_psp"]
	return

var neuron_psp_uniform_distribution: bool:
	get:
		return _neuron_psp_uniform_distribution
	set(v):
		_set_neuron_psp_uniform_distribution(v)

var neuron_mp_driven_psp: bool:
	get:
		return _neuron_mp_driven_psp
	set(v):
		_set_neuron_mp_driven_psp(v)

var neuron_post_synaptic_potential: float:
	get:
		return _neuron_post_synaptic_potential
	set(v):
		_set_neuron_post_synaptic_potential(v)

var neuron_post_synaptic_potential_max: float:
	get:
		return _neuron_post_synaptic_potential_max
	set(v):
		_set_neuron_post_synaptic_potential_max(v)

var neuron_degeneracy_coefficient: int:
	get:
		return _neuron_degeneracy_coefficient
	set(v):
		_set_neuron_degeneracy_coefficient(v)

var _neuron_psp_uniform_distribution: bool = false
var _neuron_mp_driven_psp: bool = false
var _neuron_post_synaptic_potential: float = 0.0
var _neuron_post_synaptic_potential_max: float = 0.0
var _neuron_degeneracy_coefficient: int = 0

func _set_neuron_psp_uniform_distribution(new_val: bool) -> void:
	if new_val == _neuron_psp_uniform_distribution: 
		return
	_neuron_psp_uniform_distribution = new_val
	neuron_psp_uniform_distribution_updated.emit(new_val, self)

func _set_neuron_mp_driven_psp(new_val: bool) -> void:
	if new_val == _neuron_mp_driven_psp: 
		return
	_neuron_mp_driven_psp = new_val
	neuron_neuron_mp_driven_psp_updated.emit(new_val, self)

func _set_neuron_post_synaptic_potential(new_val: float) -> void:
	if new_val == _neuron_post_synaptic_potential: 
		return
	_neuron_post_synaptic_potential = new_val
	neuron_post_synaptic_potential_updated.emit(new_val, self)

func _set_neuron_post_synaptic_potential_max(new_val: float) -> void:
	if new_val == _neuron_post_synaptic_potential_max: 
		return
	_neuron_post_synaptic_potential_max = new_val
	neuron_post_synaptic_potential_max_updated.emit(new_val, self)

func _set_neuron_degeneracy_coefficient(new_val: int) -> void:
	if new_val == _neuron_degeneracy_coefficient: 
		return
	_neuron_degeneracy_coefficient = new_val
	neuron_degeneracy_coefficient_updated.emit(new_val, self)
