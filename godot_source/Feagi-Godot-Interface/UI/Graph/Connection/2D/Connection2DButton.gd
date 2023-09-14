extends TextButton_Element
class_name Connection2DButton
## Shows number of mappings

func _init(number_mappings: int):
    update_mapping_counter(number_mappings)

func update_mapping_counter(number_of_mappings: int):
    text = str(number_of_mappings)

func update_position(midpoint: Vector2) -> void:
    position = midpoint - (size / 2.0)