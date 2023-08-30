extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	$Scroll_Vertical.prefab_to_spawn = preload("res://Feagi-Godot-Interface/UI/Windows/Small_Groupings/spawn_prefabs/Button_Prefab/ScrollButtonPrefab.tscn")
	$Scroll_Vertical.spawn_list_item({"name":"test2", "text":"test4"})
