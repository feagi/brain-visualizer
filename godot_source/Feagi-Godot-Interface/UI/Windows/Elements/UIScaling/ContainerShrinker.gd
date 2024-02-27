extends BoxContainer
class_name ContainerShrinker
## Holds input function that triggers a size recalculation for all contained

func _ready() -> void:
	VisConfig.UI_manager.UI_scale_changed.connect(recalculate_size.unbind(1))

## Any events that should cause a size recalculation should be connected via signal here
func recalculate_size() -> void:
	size = Vector2(0,0) # This is terrible. Too bad!
