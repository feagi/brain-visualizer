extends MorphologyBase
class_name MorphologyComposite

var seed: Vector3:
	get: return _seed
	set(v):
		_seed = v
		morphologyUpdated.emit(self)

var _seed: Vector3

func _init(morphologyName: String, vec: Vector3):
	super(morphologyName)
	_seed = vec
