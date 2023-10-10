extends Control
class_name StateIndicator

var _burst_engine: BooleanIndicator
var _genome_availibility: BooleanIndicator
var _genome_validity: BooleanIndicator
var _brain_readiness: BooleanIndicator

func _ready():
	_burst_engine = $BurstEngine
	_genome_availibility = $GenomeAvailability
	_genome_validity = $GenomeValidity
	_brain_readiness = $BrainReadiness
	
	

func set_health_states(burst_engine: bool, genome_availibility: bool, genome_validity: bool, brain_readiness: bool) -> void:
	_burst_engine.boolean_state = burst_engine
	_genome_availibility.boolean_state = genome_availibility
	_genome_validity.boolean_state = genome_validity
	_brain_readiness.boolean_state = brain_readiness
