extends MorphologyBase
class_name MorphologyPatterns

var vector1: Vector3

var vector2: Vector3

func _init(morphologyName: String, vec1: Vector3, vec2: Vector3):
	super(morphologyName)
	vector1 = vec1
	vector2 = vec2
