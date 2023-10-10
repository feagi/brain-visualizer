extends Node


func _ready():
	print("a")
	var b = get_node("../UI")
	print(b)
