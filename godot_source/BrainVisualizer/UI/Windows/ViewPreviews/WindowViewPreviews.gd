extends BaseDraggableWindow
class_name WindowViewPreviews

const WINDOW_NAME: StringName = "view_previews"
const SCALAR_RES: Vector2i = Vector2i(2,2)

var _resolution_UI: Label
var _preview_container: PanelContainer
var _visual_preview: TextureRect
var _buttons: HBoxContainer


# cache
var _current_resolution: Vector2i = Vector2i(0,0)
var _preview_image: Image = Image.new()
var _preview_image_texture: ImageTexture = ImageTexture.new()
var _resolution_scalar_dyn: Vector2i = Vector2i(1,1)


func _ready():
	super()
	_resolution_UI = _window_internals.get_node("HBoxContainer/resolution")
	_preview_container = _window_internals.get_node("PanelContainer")
	_visual_preview = _window_internals.get_node("PanelContainer/MarginContainer/TextureRect")
	_buttons = _window_internals.get_node("sizes")
	

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	

func _update_preview_texture_from_raw_data(bytes: PackedByteArray) -> void:
	var resolution: Vector2i = Vector2i(bytes.decode_u16(2), bytes.decode_u16(4))
	if resolution == Vector2i(0,0):
		return
	if resolution != _current_resolution:
		_update_resolution(resolution)
	_preview_image.set_data(resolution.x, resolution.y, false, Image.FORMAT_RGB8, bytes.slice(6))
	_preview_image_texture.update(_preview_image)

func _update_resolution(res: Vector2i) -> void:
	_current_resolution = res
	if !_preview_container.visible:
		_preview_container.visible = true
		_buttons.visible = true
		_update_scale_size()
	_resolution_UI.text = "%d x %d" % [res.x, res.y]
	_preview_image = Image.create_empty(res.x, res.y, false, Image.FORMAT_RGB8)
	_preview_image_texture.set_image(_preview_image)
	_visual_preview.texture = _preview_image_texture
	
func _update_scale_size() -> void:
	_visual_preview.custom_minimum_size = _current_resolution * SCALAR_RES * _resolution_scalar_dyn

func _scale_button_pressed(scalar: int) -> void: # set with custom arguments from TSCN signal
	_resolution_scalar_dyn = Vector2i(scalar, scalar)
	_update_scale_size()
	
