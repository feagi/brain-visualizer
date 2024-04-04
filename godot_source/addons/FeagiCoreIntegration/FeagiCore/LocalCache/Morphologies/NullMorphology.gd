extends Morphology
class_name NullMorphology
## Only exists to act as a null or invalid morphology, to be passed as an error


func _init():
	type = MORPHOLOGY_TYPE.NULL
