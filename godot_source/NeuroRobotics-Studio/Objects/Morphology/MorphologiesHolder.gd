extends Object
class_name MorphologiesHolder



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
var _coreRef: Core

func _init(initialMorphologyNames: PackedStringArray, coreReference: Core) -> void:
	_morphologiesArray = initialMorphologyNames
	_timeOfLastMorphologyArrayUpdate = Time.get_unix_time_from_system()
	_coreRef = coreReference

func CallUpdateMorphology(morphologyName: StringName) -> void:
	# Updates a morphology by string name
	# Remember, these are network calls thus NOT INSTANT
	# However, on completion they will signal up that that specific morphology was updated
	
	if !morphologiesStrList.has(morphologyName): 
		print("Requesting non-existant morphology " + morphologyName + ". Ignoring...")
		return
	
	_coreRef.Get_Morphology_information_CR(morphologyName, _ProcessUpdatedMorphology)
	

	


