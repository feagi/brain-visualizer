extends RefCounted
class_name ContinuousSelectedNeuronFiring
## Resolves Brain Monitor Space / Shift+Space voxel-firing actions.
## Shift+Space starts continuous stimulation; Space while running stops it.
## Space with no Shift, while idle, remains a one-shot fire.


enum SPACE_PRESS_ACTION {
	ONE_SHOT,
	START_CONTINUOUS,
	STOP_CONTINUOUS,
}


## Maps a non-echo Space keydown onto a firing action.
##
## [param shift_held]: true when Shift was held with Space (Shift+Space).
## [param continuous_active]: true when this Brain Monitor is already pulsing stimulation.
static func resolve_space_press(shift_held: bool, continuous_active: bool) -> SPACE_PRESS_ACTION:
	if continuous_active:
		return SPACE_PRESS_ACTION.STOP_CONTINUOUS
	if shift_held:
		return SPACE_PRESS_ACTION.START_CONTINUOUS
	return SPACE_PRESS_ACTION.ONE_SHOT


## True when [param simulation_timestep] can be used as a repeating stimulation interval.
static func is_valid_interval_seconds(simulation_timestep: float) -> bool:
	return simulation_timestep > 0.0
