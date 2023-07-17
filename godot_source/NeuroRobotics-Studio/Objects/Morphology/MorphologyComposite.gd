extends MorphologyBase
class_name MorphologyComposite

var seed: Vector3

func _init(morphologyName: String, vec: Vector3):
	super(morphologyName)
	seed = vec
