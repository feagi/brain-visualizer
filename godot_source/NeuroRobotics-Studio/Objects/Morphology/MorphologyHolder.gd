extends Object
class_name MorphologyHolder



var morphologiesStrList: PackedStringArray: # String Array
	get: return _morphologiesArray

var timeOfLastMorphologyArrayUpdate: float:
	get: return _timeOfLastMorphologyArrayUpdate

var secondsSinceLastMorphologyArrayUpdate: float:
	get: return  _timeOfLastMorphologyArrayUpdate - Time.get_unix_time_from_system()

var cachedMorphologies: Dictionary: # Only stores morphologies that have at some point been requested
	get: return _cachedMorphologies


var _timeOfLastMorphologyArrayUpdate: float
var _morphologiesArray: PackedStringArray
var _cachedMorphologies: Dictionary

func _init(initialMorphologyNames: PackedStringArray) -> void:
	_morphologiesArray = initialMorphologyNames
	_timeOfLastMorphologyArrayUpdate = Time.get_unix_time_from_system()

func CallUpdateMorphology(morphologyName: StringName) -> void:
	# Updates a morphology by string name
	# Remember, these are network calls thus NOT INSTANT
	# However, on completion they will signal up that that specific morphology was updated
	
	if !morphologiesStrList.has(morphologyName): 
		print("Requesting non-existant morphology " + morphologyName + ". Ignoring...")
		return
	
	how do we call when getting morphology doesnt return name
	

func _ProcessUpdatedMorphology(name: StringName, type: StringName, data: Dictionary) -> void:
	


