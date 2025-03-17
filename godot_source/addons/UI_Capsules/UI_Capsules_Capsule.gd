extends Node
class_name UI_Capsules_Capsule
## Abstraction for holding different types of UIs in different types of UIs

## Gets the UI this capsule is representing (returns null if invalid)
func get_holding_UI() -> Variant:
	var output: Variant = get_child(0)
	if output:
		return output
	return null
