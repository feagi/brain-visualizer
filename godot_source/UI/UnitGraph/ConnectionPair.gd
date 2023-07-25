extends Object
class_name ConnectionPair

# Holds data referring to src node and destination node connections, as well as
# simple functions to check

var source: CortexID:
	get: return _source

var destination: CortexID:
	get: return _destination

var _source: CortexID
var _destination: CortexID

func IsSource(check: CortexID) -> bool:
	return check.STR == _source.STR

func isDest(check: CortexID) -> bool:
	return check.STR == _destination.STR

func isEither(check: CortexID) -> bool:
	return (check.STR == _destination.STR) || (check.STR == _source.STR)

func isExactly(src: CortexID, dst: CortexID) -> bool:
	return (src.STR == _destination.STR) && (dst.STR == _source.STR)

func isReverse(src: CortexID, dst: CortexID) -> bool:
	return (dst.STR == _destination.STR) && (src.STR == _source.STR)