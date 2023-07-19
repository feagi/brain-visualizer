extends Object
class_name MorphologiesHolder



var morphologiesStrArray: PackedStringArray: # String Array
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

func _init(coreReference: Core) -> void:
	_coreRef = coreReference

func CallMorphology(morphologyName: StringName) -> void:
	# Updates a morphology cache by string name
	# Remember, these are network calls thus NOT INSTANT
	# However, on completion they will signal up that that specific morphology was updated
	
	if !morphologiesStrArray.has(morphologyName): 
		print("Requesting non-existant morphology " + morphologyName + ". Ignoring...")
		return
	
	_coreRef.Get_Morphology_information(morphologyName)

func StoreMorphologyDataFromFEAGI(dataFromFEAGI: Dictionary) -> void:
	var morphology
	var morphologyName: String = dataFromFEAGI["morphology_name"]
	match(dataFromFEAGI["type"]):
		"patterns":
			morphology = MorphologyPatterns.new(morphologyName, dataFromFEAGI["parameters"]["patterns"][0], dataFromFEAGI["parameters"]["patterns"][1])
			_cachedMorphologies[morphologyName] = morphology
			return
		"vectors":
			morphology = MorphologyVectors.new(morphologyName, dataFromFEAGI["parameters"]["vectors"])
			_cachedMorphologies[morphologyName] = morphology
			return
		"composite":
			morphology = MorphologyComposite.new(morphologyName, dataFromFEAGI["parameters"]["src_seed"], dataFromFEAGI["parameters"]["src_pattern"])
			_cachedMorphologies[morphologyName] = morphology
			return
		"functions":
			# TODO
			pass
		_:
			print("Unknown Morphology of type " + morphologyName + "retireved from FEAGI. Ignoring...")
		


