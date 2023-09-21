extends Node3D

var start_timer
var array_delta =[]

func _ready():
	while len(array_delta) < 6:
		await get_tree().create_timer(60.0).timeout
		start_timer = Time.get_ticks_msec()
		$"../../../FEAGIInterface".net.websocket_send("ping")
	var final_delta = 0
	for i in array_delta:
		final_delta += i
	final_delta = final_delta/6
	$"../3d_indicator/Sprite3D/SubViewport/delta_label".text = str(final_delta) + " ms"
	

func latency_calculation(end):
	var delta_timer = (end - start_timer)/2
	$"../3d_indicator/Sprite3D/SubViewport/delta_label".text = str(delta_timer) + " ms"
	array_delta.append(delta_timer)
