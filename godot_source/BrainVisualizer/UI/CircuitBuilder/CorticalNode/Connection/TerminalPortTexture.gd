extends TextureRect
class_name TerminalPortTexture

const TEX_PLASTIC: Texture = preload("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/Resources/cb-port-plastic.png")
const TEX_INPLASTIC: Texture = preload("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/Resources/cb-port-non-plastic.png")

signal terminal_moved()

func _ready() -> void:
	set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		terminal_moved.emit()

func setup(mapping_property_reference: MappingProperties) -> void:
	mapping_property_reference.mappings_changed.connect(mapping_property_updated)
	_texture_set_plastic(mapping_property_reference.is_any_mapping_plastic())

## Can be called form here or above.
func node_move_terminal() -> void:
	terminal_moved.emit()

func mapping_property_updated(self_mapping_property_reference: MappingProperties) -> void:
	_texture_set_plastic(self_mapping_property_reference.is_any_mapping_plastic())

func _texture_set_plastic(is_plastic: bool) -> void:
	texture = TEX_PLASTIC if is_plastic else TEX_INPLASTIC
