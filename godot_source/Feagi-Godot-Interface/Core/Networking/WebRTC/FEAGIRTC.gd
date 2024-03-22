extends Object
class_name FEAGIRTC

enum RTC_STATUS {
	CLOSED,
	STARTING,
	ACTIVE
}

signal status_changed(RTS_status: RTC_STATUS)
signal recieved_data(data: PackedByteArray)

var status: RTC_STATUS = RTC_STATUS.CLOSED
var _RTC: WebRTCPeerConnection
var _channel: WebRTCDataChannel


func _on_generation_of_session_description(type: String, sdp: String) -> void:
	_RTC.set_local_description(type, sdp)
	status = RTC_STATUS.STARTING
	status_changed.emit(status)

func _init(STUN_URLs: Array[StringName], TURN_URLs: Array[StringName], channel_label: String, channel_ID: int) -> void:
	_RTC = WebRTCPeerConnection.new()
	_RTC.session_description_created.connect(_on_generation_of_session_description)
	_channel = _RTC.create_data_channel(
		channel_label,
		{
			"id": channel_ID,
		 	"negotiated": true
		}
	)
	_RTC.initialize({
		"iceServers": [
			{
				"urls": STUN_URLs, # One or more STUN servers.
			},
			{
				"urls": TURN_URLs, # One or more TURN servers.
				#"username": "a_username", # Optional username for the TURN server.
				#"credential": "a_password", # Optional password for the TURN server.
			}
		]
	})
	_RTC.create_offer()

## Call during _process when status is starting or active. keeps the RTC channel open and running
func poll() -> void:
	if _channel == null:
		return
	_RTC.poll()
	if status == RTC_STATUS.STARTING:
		if _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			status = RTC_STATUS.ACTIVE
			status_changed.emit(status)
	if _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		recieved_data.emit(_channel.get_packet())

func send_data(data: PackedByteArray) -> void:
	if _channel.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
		return
	_channel.put_packet(data)
