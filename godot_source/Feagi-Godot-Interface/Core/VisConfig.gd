extends Node
## AUTOLOADED
## Contains any general info about the state of the visualizer

enum STATES {
	LOADING_INITIAL,
	READY,
}

var UI_manager: Node
var is_premium: bool = true

var visualizer_state: STATES:
	get: return _visualizer_state
	set(v):
		print("STATE: SWITCH TO " + STATES.find_key(v))
		_visualizer_state = v

var _visualizer_state: STATES = STATES.LOADING_INITIAL


