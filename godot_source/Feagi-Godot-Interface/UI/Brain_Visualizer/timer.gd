extends LineEdit

var start_timer
var array_delta =[]


func _ready():
	FeagiEvents.retrieved_latest_ping.connect(latency_calculation)
	while true:
		while len(array_delta) < 6:
			start_timer = Time.get_ticks_msec()
			if $"../../../../../FEAGIInterface".net.current_websocket_status == WebSocketPeer.STATE_OPEN:
				$"../../../../../FEAGIInterface".net.websocket_send("ping")
			await get_tree().create_timer(1.0).timeout
		var final_delta = 0
		for i in array_delta:
			final_delta += i
		final_delta = final_delta/6
		text = str(final_delta) + " ms"
		array_delta =[]
		await get_tree().create_timer(5).timeout


func latency_calculation(end):
	var delta_timer = (end - start_timer)/2
	text = str(delta_timer) + " ms"
	array_delta.append(delta_timer)
