extends Node
class_name UI_Capsules_Capsule
## Abstraction for holding different types of UIs in different types of UIs

enum HELD_TYPE {
	UNKNOWN,
	BRAIN_MONITOR,
	CIRCUIT_BUILDER,
	BACKGROUND
}

static func spawn_uninitialized_UI_in_capsule(type: HELD_TYPE) -> UI_Capsules_Capsule:
	var new_capsule: UI_Capsules_Capsule = UI_Capsules_Capsule.new()
	match(type):
		HELD_TYPE.UNKNOWN:
			return null
		HELD_TYPE.BRAIN_MONITOR:
			new_capsule.add_child(UI_BrainMonitor_3DScene.create_uninitialized_brain_monitor())
		# TODO other types
	return new_capsule


## Gets the UI this capsule is representing (returns null if invalid)
func get_holding_UI() -> Variant:
	var output: Variant = get_child(0)
	if output:
		return output
	return null

func get_held_type() -> HELD_TYPE:
	var held_type: Variant = get_holding_UI() 
	if held_type is UI_BrainMonitor_3DScene:
		return HELD_TYPE.BRAIN_MONITOR
	# TODO other types
	return HELD_TYPE.UNKNOWN
