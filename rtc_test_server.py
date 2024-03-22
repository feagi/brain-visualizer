import asyncio
import json
from websockets.server import serve
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCIceCandidate

peer_connection = None


async def handle_candidate(candidate_data):
	global peer_connection
	if peer_connection and isinstance(peer_connection, RTCPeerConnection):
		# Parse the candidate string
		fields = candidate_data["candidate"].split()
		candidate_dict = {
	   "foundation": fields[0],
	   "component": int(fields[1]),
	   "protocol": fields[2],
	   "priority": int(fields[3]),
	   "ip": fields[4],
	   "port": int(fields[5]),
	   "type": fields[7],
	   "sdpMid": candidate_data["sdpMid"],
	   "sdpMLineIndex": candidate_data["sdpMLineIndex"]
		}
		if len(fields) > 8:
			# Parse related address and port for relay and srflx candidates
			candidate_dict["relatedAddress"] = fields[9] if fields[8] == "raddr" else None
			candidate_dict["relatedPort"] = int(fields[10]) if fields[8] == "rport" else None

		# Create an RTCIceCandidate object from the dictionary
		candidate = RTCIceCandidate(**candidate_dict)

		# Add the ICE candidate to the peer connection
		await peer_connection.addIceCandidate(candidate)
	else:
		print("Peer connection has not been initialized.")


async def handle_offer(offer):
	global peer_connection
	peer_connection = RTCPeerConnection()
	await peer_connection.setRemoteDescription(RTCSessionDescription(offer['offer']['sdp'], offer['type']))

	# Create a data channel
	data_channel = peer_connection.createDataChannel("chat")

	# Correct way to set event handler for receiving messages
	@data_channel.on("message")
	def on_message(message):
		print("Received message from data channel:", message)

	# Create an answer
	answer = await peer_connection.createAnswer()
	await peer_connection.setLocalDescription(answer)
	return {
		'type': answer.type,
		'sdp': answer.sdp
	}


async def echo(websocket):
	global peer_connection
	while True:
		message = await websocket.recv()
		print("RECEIVED: ", message)
		data = json.loads(message)

		# Check if the message is an offer
		if data['type'] == 'offer':
		   answer = await handle_offer(data)
		   await websocket.send(json.dumps(answer))

		# Check if the message is a candidate
		if data['type'] == 'candidate':
		   await handle_candidate(data['candidate'])


async def main():
	async with serve(echo, "127.0.0.1", 9121):
		await asyncio.Future()  # run forever


asyncio.run(main())