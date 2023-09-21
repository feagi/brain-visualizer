extends Node3D

var start_timer
var array_delta =[]

func _ready():
	while true:
		while len(array_delta) < 6:
			start_timer = Time.get_ticks_msec()
			$"../../../FEAGIInterface".net.websocket_send("ping")
			await get_tree().create_timer(1.0).timeout
		var final_delta = 0
		for i in array_delta:
			final_delta += i
		final_delta = final_delta/6
		$"../3d_indicator/Sprite3D/SubViewport/delta_label".text = str(final_delta) + " ms"
		array_delta =[]
		await get_tree().create_timer(5).timeout
	

func latency_calculation(end):
	var delta_timer = (end - start_timer)/2
	$"../3d_indicator/Sprite3D/SubViewport/delta_label".text = str(delta_timer) + " ms"
	array_delta.append(delta_timer)
