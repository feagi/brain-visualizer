extends Control
class_name StateIndicator

var _burst_engine: BooleanIndicator
var _genome_availibility: BooleanIndicator
var _genome_validity: BooleanIndicator
var _brain_readiness: BooleanIndicator
var _data: BooleanIndicator
var _summary: BooleanIndicator

func _ready():
	_burst_engine = $BurstEngine
	_genome_availibility = $GenomeAvailability
	_genome_validity = $GenomeValidity
	_brain_readiness = $BrainReadiness
	_data = $Data
	_summary = $Summary

func set_feagi_states(burst_engine: bool, genome_availibility: bool, genome_validity: bool, brain_readiness: bool) -> void:
	_burst_engine.boolean_state = burst_engine
	_genome_availibility.boolean_state = genome_availibility
	_genome_validity.boolean_state = genome_validity
	_brain_readiness.boolean_state = brain_readiness
	_refresh_summary()

func set_websocket_state(state: WebSocketPeer.State) -> void:
	var is_websocket_working: bool = state == WebSocketPeer.State.STATE_OPEN
	_data.boolean_state = is_websocket_working
	_refresh_summary()

func toggle_collapse(is_collapsed: bool) -> void:
	_burst_engine.visible = !is_collapsed
	_genome_availibility.visible = !is_collapsed
	_genome_validity.visible = !is_collapsed
	_brain_readiness.visible = !is_collapsed
	_data.visible = !is_collapsed
	_summary.visible = is_collapsed
	size = Vector2(0,0) # force smallest possible size

func _refresh_summary() -> void:
	_summary.boolean_state = (
		_burst_engine.boolean_state && _genome_availibility.boolean_state && 
		_genome_validity.boolean_state && _brain_readiness.boolean_state &&
		_data.boolean_state)
