extends Node
class_name FEAGIBitVisualization
## Neural activity from a feagi-core server, which streams one bit per voxel for the whole brain.
## The bits are pushed to the GPU as one texture ([member texture]) shared by every cortical area's
## material, and each area's shader reads its own range of it, starting at the byte index the
## server's visualization context gives for it.
##
## The texture is shared as a resource every material references, not as a global shader uniform,
## as global samplers read nothing in the Compatibility renderer.
##
## The server increments a change counter whenever the connectome's structure changes (a cortical
## area added, removed or resized), which moves where each area's bits start. When a packet's
## counter differs from the one the context was fetched for, the context is fetched again, one
## request at a time, and packets are not drawn until it arrives.
##
## Within an area the bits run x first, then y, then z, least significant bit of each byte first.
## The server drops the 4th dimension into a single layer, so areas are read as 3 dimensional.
## Their dimensions come from the cache.

## Width of the bit data texture. Bytes fill it row by row
const TEXTURE_WIDTH: int = 4096
## Header of a packet: version (u8), change counter (u16 LE)
const PACKET_HEADER_SIZE: int = 3
## The packet version this decodes
const SUPPORTED_PACKET_VERSION: int = 0

## Fired when the context changes. [param read_start_byte_indexes] maps cortical ID
## ([StringName]) to the byte index its bits start at. Empty when no context is known
signal visualization_context_changed(read_start_byte_indexes: Dictionary)

## Byte index each cortical area's bits start at, by cortical ID. Empty when no context is known
var read_start_byte_indexes: Dictionary:
	get: return _read_start_byte_indexes
## Change counter of the connectome structure the context is for, -1 when none is known
var context_change_counter: int:
	get: return _context_change_counter
## Bit data of the whole brain, as an R8 texture filled row by row. The same resource for as long
## as this exists, so materials can keep referencing it
var texture: ImageTexture:
	get: return _texture

var _read_start_byte_indexes: Dictionary = {}
var _context_change_counter: int = -1
var _is_context_request_in_flight: bool = false
var _texture: ImageTexture = ImageTexture.new()
var _texture_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_upload_bytes(PackedByteArray())


## Takes one visualization packet from the server. If its connectome structure is the one the
## context is for, its bits are pushed to the GPU. Otherwise the context is fetched again (if it
## is not being fetched already) and the packet is dropped.
# TODO called by the zenoh transport once the server publishes visualization
func ingest_visualization_packet(packet: PackedByteArray) -> void:
	if packet.size() < PACKET_HEADER_SIZE:
		push_warning("[ZENOH] Visualization packet too short (%d bytes)" % packet.size())
		return
	var version: int = packet.decode_u8(0)
	if version != SUPPORTED_PACKET_VERSION:
		push_warning("[ZENOH] Unsupported visualization packet version %d" % version)
		return
	var change_counter: int = packet.decode_u16(1)
	if change_counter != _context_change_counter:
		_refresh_context_for(change_counter)
		return
	_upload_bytes(packet.slice(PACKET_HEADER_SIZE))


## Forgets the context and clears the bit data, such as when the zenoh connection closes
func reset() -> void:
	_context_change_counter = -1
	_set_context({})
	_upload_bytes(PackedByteArray())


## Fetches the context for [param change_counter] unless a fetch is already waiting on the server
func _refresh_context_for(change_counter: int) -> void:
	if _is_context_request_in_flight:
		return
	_is_context_request_in_flight = true
	var context: Dictionary = await fetch_visualization_context(change_counter)
	_is_context_request_in_flight = false
	# The connection closed while waiting, nothing to apply it to
	if not is_inside_tree():
		return
	_context_change_counter = int(context.get("change_counter", change_counter))
	_set_context(context.get("read_start_byte_indexes", {}))


## Asks the server where each cortical area's bits start (its GenomeVisualizationContext), having
## seen packets for [param change_counter]. Returns a Dictionary with change_counter (int), the
## connectome structure the context is for, and read_start_byte_indexes (Dictionary of cortical
## ID [StringName] to byte index [int])
func fetch_visualization_context(change_counter: int) -> Dictionary:
	# TODO request the visualization context endpoint once the server serves it, taking the change
	# counter from its response. Until then no area has bits to read, so every area is drawn
	# without activity
	await get_tree().process_frame
	return {
		"change_counter": change_counter,
		"read_start_byte_indexes": {},
	}


func _set_context(read_start_byte_indexes: Dictionary) -> void:
	_read_start_byte_indexes = read_start_byte_indexes
	visualization_context_changed.emit(_read_start_byte_indexes)


## Pushes [param bytes] to the shared texture, row by row. Its image is only replaced when the
## number of rows changes, otherwise it is updated in place
func _upload_bytes(bytes: PackedByteArray) -> void:
	var rows: int = maxi(1, ceili(float(bytes.size()) / float(TEXTURE_WIDTH)))
	var size := Vector2i(TEXTURE_WIDTH, rows)
	var padded := bytes.duplicate()
	padded.resize(size.x * size.y) # zero filled, so padding reads as voxels off
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_R8, padded)
	if size == _texture_size:
		_texture.update(image)
		return
	_texture.set_image(image)
	_texture_size = size
