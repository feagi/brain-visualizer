extends Object
class_name PatternVector3Pairs
## Organizes PatternVector3s into in/out pairs, which is used in [PatternMorphology]

var incoming: PatternVector3
var outgoing: PatternVector3

func _init(going_in: PatternVector3, going_out: PatternVector3):
	incoming = going_in
	outgoing = going_out
