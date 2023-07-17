extends MorphologyBase
class_name MorphologyVectors

var vector: Vector3

func _init(morphologyName: String, vec: Vector3):
	super(morphologyName)
	vector = vec
