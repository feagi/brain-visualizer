extends MorphologyBase
class_name MorphologyComposite

var seed: Vector3i:
	get: return _seed
	set(v):
		_seed = v
		morphologyUpdated.emit(self)

var pattern: Array:
	get: return [_v1, _v2, _v3]
	set(v):
		_v1 = HelperFuncs.Array2Vector2i(v[0])
		_v2 = HelperFuncs.Array2Vector2i(v[1])
		_v3 = HelperFuncs.Array2Vector2i(v[2])



var _seed: Vector3i
var _v1: Vector2i
var _v2: Vector2i
var _v3: Vector2i

func _init(morphologyName: String, inputSeed: Array, arrayArrayPattern: Array):
	super(morphologyName)
	seed = HelperFuncs.Array2Vector3i(inputSeed)
	_v1 = HelperFuncs.Array2Vector2i(arrayArrayPattern[0])
	_v2 = HelperFuncs.Array2Vector2i(arrayArrayPattern[1])
	_v3 = HelperFuncs.Array2Vector2i(arrayArrayPattern[2])
