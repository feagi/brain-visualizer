extends MorphologyBase
class_name MorphologyPatterns

var vector1: PatternVector:
	get: return _vector1
	set(v):
		_vector1 = v
		morphologyUpdated.emit(self)
	
var vector2: PatternVector:
	get: return _vector2
	set(v):
		_vector2 = v
		morphologyUpdated.emit(self)

var _vector1: PatternVector
var _vector2: PatternVector

func _init(morphologyName: String, vec1, vec2): # vec1/2 can be either Arrays or PatternVector
	super(morphologyName)
	_vector1 = vec1
	vector2 = vec2
