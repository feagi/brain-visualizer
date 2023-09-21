extends Node3D

var start_timer
var array_delta =[]

func _ready():
	while len(array_delta) < 6:
		start_timer = Time.get_ticks_msec()
		await get_tree().create_timer(1).timeout
		$"../../../FEAGIInterface".net.websocket_send("ping")
	var final_delta = 0
	for i in array_delta:
		final_delta += i
	final_delta = final_delta/6
	print("final: ", final_delta)
	print("array: ", array_delta)
func latency_calculation(end):
	var delta_timer = (end - start_timer)/2
	print("total: ", delta_timer)
	array_delta.append(delta_timer)
