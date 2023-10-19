extends DraggableWindow
class_name TutorialDisplay

const MAX_NUMBER_SLIDES: int = 10

var _previous_button: TextButton_Element
var _next_button: TextButton_Element
var _TextureBox: TextureRect
var _current_slide_number: int = 2

func _ready():
	super()
	_TextureBox = $VBoxContainer/Texture
	_previous_button = $VBoxContainer/HBoxContainer/previous_button
	_next_button = $VBoxContainer/HBoxContainer/next_button
	_previous_button.pressed.connect(_decrement_slide)
	_next_button.pressed.connect(_increment_slide)
	_previous_button.disabled = true
	

## Incrememnts slide count, and controls button availability depending on slide number
func _increment_slide() -> void:
	if _current_slide_number == 2:
		_previous_button.disabled = false
	_current_slide_number = _current_slide_number + 1
	_TextureBox.texture = _get_slide(_current_slide_number)
	if _current_slide_number == MAX_NUMBER_SLIDES:
		_next_button.disabled = true

## Decrements slide count, and controls button availability depending on slide number
func _decrement_slide() -> void:
	if _current_slide_number == MAX_NUMBER_SLIDES:
		_next_button.disabled = false
	_current_slide_number = _current_slide_number - 1
	_TextureBox.texture = _get_slide(_current_slide_number)
	if _current_slide_number == 2:
		_previous_button.disabled = true

## Given a slide number from 1 to MAX_NUMBER_SLIDES, returns the slide image
func _get_slide(slide_number: int) -> CompressedTexture2D:
	const BASE_PATH = "res://Feagi-Godot-Interface/UI/Resources/tutorial_assets/"
	const EXTENSION = ".png"
	const PREFIX = "t"
	var path = BASE_PATH + PREFIX + str(slide_number) + EXTENSION
	return load(path) # these image files are large and not used consistently, so no preloading
