extends Button
class_name Connection_Button


func update_position(start_point: Vector2, end_point: Vector2) -> void:
	position = (start_point + end_point) / 2.0
