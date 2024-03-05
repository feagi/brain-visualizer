extends BoxContainer
class_name ContainerShrinker
## Holds input function that triggers a size recalculation for all contained

## Shrink when any child changes size. THIS IS VERY INEFFICIENT
@export var shrink_on_any_change: bool = false # WARNING: Too bad!

@export var shrink_on_ui_scale_change: bool = true


func _ready() -> void:
	if shrink_on_ui_scale_change:
		VisConfig.UI_manager.UI_scale_changed.connect(recalculate_size.unbind(1))
	if shrink_on_any_change:
		for child: Control in get_children():
			child.resized.connect(recalculate_size)

## Any events that should cause a size recalculation should be connected via signal here
func recalculate_size() -> void:
	size = Vector2(0,0) # This is terrible. Too bad!

