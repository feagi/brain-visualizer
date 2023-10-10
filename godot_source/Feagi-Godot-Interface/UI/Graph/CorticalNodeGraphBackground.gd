extends FullScreenControl
class_name CorticalNodeGraphBackground


func _apply_pan_visuals(pan: Vector2) -> void:
	material.set_shader_parameter("offset", -pan)