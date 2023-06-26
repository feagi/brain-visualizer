extends Node

var bool_flag = true
var loading_box_timer = false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func trigger_api_timer():
	bool_flag = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if bool_flag == false:
		await get_tree().create_timer(1).timeout
		bool_flag = true
	if loading_box_timer:
		loading_box()

func loading_box():
	var data = ""
	while data == "" or data == "updated":
		await get_tree().create_timer(1).timeout
		data = str(network_setting.one_frame)
	loading_box_timer = false
