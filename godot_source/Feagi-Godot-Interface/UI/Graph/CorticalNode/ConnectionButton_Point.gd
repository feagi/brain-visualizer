extends TextureButton
class_name ConnectionButton_Point

const CIRCLE_LOGO = "res://Feagi-Godot-Interface/UI/Resources/Icons/info.png"

enum ConnectionState {
	DISABLED,
	EMPTY,
	LOADING,
	FILLED
}

enum CorticalIO{
	INPUT,
	OUTPUT
}

@export var button_side: CorticalIO
var number_connections: int

