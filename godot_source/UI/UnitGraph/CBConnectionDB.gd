extends Object
class_name CBConnectionDB

# stores a forward and reverse dictionary for rapid connections lookup

var _forward: Dictionary
var _backward: Dictionary


# For adding a connection in the data store
func AddConnection(src: CortexID, dst: CortexID, label: Connection_Label) -> void:
	_AddForward(src, dst, label)
	_AddBackward(src, dst, label)

# For removing a connection from the data store
func RemoveConnection(src: CortexID, dst: CortexID) -> void:
	_RemoveForward(src, dst)
	_RemoveBackward(src, dst)

# To check if a specific connection even exists
func DoesConnectionExist(src: CortexID, dst: CortexID) -> bool:
	if src.ID not in _forward.keys(): return false
	if dst.ID not in _forward[src.ID].keys(): return false
	return true

# Get a specific connection Label. Will Error if it doesn't exist
func GetSpecificConnectionLabel(src: CortexID, dst: CortexID) -> Connection_Label:
	return _forward[src.ID][dst.ID]
	
# Get an array of connection labels that have a given source
func GetConnectionLabelsWithSource(src: CortexID) -> Array[Connection_Label]:
	if src.ID not in _forward.keys: return []
	return _forward[src.ID].keys()

# Get an array of connection labels that have a given destination
func GetConnectionLabelsWithDestination(dst: CortexID) -> Array[Connection_Label]:
	if dst.ID not in _backward.keys: return []
	return _backward[dst.ID].keys()


func _AddForward(src: CortexID, dst: CortexID, label: Connection_Label) -> void:

	if src.STR not in _forward.keys():
		_forward[src.STR] = {}
	
	if dst.STR not in _forward[src.STR].keys():
		_forward[src.STR][dst.STR] = label
		return
	
	@warning_ignore("assert_always_false")
	assert(false, "Attemped to define already existing connection " + src.ID + " -> " + dst.ID)

func _RemoveForward(src: CortexID, dst: CortexID) -> void:
	_forward[src.ID].erase(dst.ID)
	if _forward[src.ID] == {}: _forward.erase(src.ID)

func _AddBackward(src: CortexID, dst: CortexID, label: Connection_Label) -> void:

		if dst.STR not in _backward.keys():
			_backward[dst.STR] = {}
		
		if src.STR not in _backward[dst.STR].keys():
			_backward[dst.STR][src.STR] = label
			return
	
		@warning_ignore("assert_always_false")
		assert(false, "Attemped to define already existing connection " + src.ID + " -> " + dst.ID)

func _RemoveBackward(src: CortexID, dst: CortexID) -> void:
	_backward[dst.ID].erase(src.ID)
	if _backward[dst.ID] == {}: _backward.erase(dst.ID)
