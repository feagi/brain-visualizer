extends Node
## Appends required reference to VisCOnfig Autoload before deleting self.
# This is terrible. Too Bad!

func _ready():
	var UI_manager_reference: Node = get_node("../UI")
	VisConfig.UI_manager = UI_manager_reference
	queue_free()
