extends Panel
class_name TitleBar

signal close_pressed()
signal dragged(current_position: Vector2, delta_offset: Vector2) # TODO

@export var title_gap: int:
	get: return $Title_Text.gap
	set(v): $Title_Text.gap = v

@export var title: String:
	get: return $Title_Text.text
	set(v): $Title_Text.text = v



# Called when the node enters the scene tree for the first time.
func _ready():
	$Close_Button.pressed.connect(_proxy_close_button)
	$Close_Button.resized.connect(_height_resized)
	$Title_Text.resized.connect(_recalculate_title_bar_min_width)
	_recalculate_title_bar_min_width()
	#resized.connect(_reposition_close_button)
func _proxy_close_button():
	close_pressed.emit()

func _height_resized() -> void:
	custom_minimum_size.y = VisConfig._minimum_button_size_pixel.y

	
	# Because button is a square

## What is the minimum width the title bar needs to be to fit everything?
func _recalculate_title_bar_min_width() -> void:
	custom_minimum_size.x = int($Close_Button.custom_minimum_size.y) + int($Title_Text.size.x) + title_gap # Yes, using the close button Y is intentional to avoid repositioning loops

# CAN POSSIBLY REMOVE
## Makes sure the X button stays on the left, called when title bar is resized
func _reposition_close_button() -> void:
	$Close_Button.position.x = size.x - $Close_Button.size.x
