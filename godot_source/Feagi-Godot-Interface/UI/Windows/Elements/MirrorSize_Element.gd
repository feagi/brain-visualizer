extends Control
class_name MirrorSize_Element

@export var target_object_to_size: Control

func _ready():
    target_object_to_size.resized.connect(update_size)

func update_size() -> void:
    size = target_object_to_size.size