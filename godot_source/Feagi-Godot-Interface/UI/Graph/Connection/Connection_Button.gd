extends Button
class_name Connection_Button


func update_position(points: PackedVector2Array) -> void:
	position = (points[0] + points[1]) / 2.0
