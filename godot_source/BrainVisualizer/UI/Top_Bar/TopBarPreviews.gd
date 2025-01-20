extends PanelContainer
class_name TopBarPreviews


var _visual_preview: TextureRect

#visual
var _preview_res: Vector2i
var _preview_image: Image = Image.new()
var _preview_image_texture: ImageTexture = ImageTexture.new()

func _ready() -> void:
	_visual_preview = $MarginContainer/HBoxContainer/VisualPreview
	
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)

func _toggle_visibility() -> void:
	visible = !visible

func _update_preview_texture_from_raw_data(bytes: PackedByteArray) -> void:
	var resolution: Vector2i = Vector2i(bytes.decode_u16(2), bytes.decode_u16(4))
	if resolution == Vector2i(0,0):
		return
	if resolution != _preview_res:
		_preview_res = resolution
		_preview_image = Image.create_empty(resolution.x, resolution.y, false, Image.FORMAT_RGB8)
		_preview_image_texture.set_image(_preview_image)
		_visual_preview.texture = _preview_image_texture
	_preview_image.set_data(resolution.x, resolution.y, false, Image.FORMAT_RGB8, bytes.slice(6))
	_preview_image_texture.update(_preview_image)
