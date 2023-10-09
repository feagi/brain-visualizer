extends Object
class_name CircuitDetails

var file_name: StringName:
	get: return _file_name
var friendly_name: StringName:
	get: return CircuitDetails.file_name_to_friendly_name(_file_name)
var dimensions: Vector3i:
	get: return _dimensions
var details: StringName:
	get: return _details

var _file_name: StringName
var _dimensions: Vector3i
var _details: StringName

func _init(circuit_file_name: StringName, circuit_dimensions: Vector3i, circuit_details: StringName) -> void:
	_file_name = circuit_file_name
	_dimensions = circuit_dimensions
	_details = circuit_details

static func file_name_to_friendly_name(circuit_file_name: StringName) -> StringName:
	return circuit_file_name.left(circuit_file_name.length() - 5)

static func friendly_name_to_file_name(circuit_friendly_name: StringName) -> StringName:
	return circuit_friendly_name + ".json"

static func file_name_array_to_friendly_name_array(circuit_file_names: PackedStringArray) -> PackedStringArray:
	for i in circuit_file_names.size():
		circuit_file_names[i] = String(CircuitDetails.file_name_to_friendly_name(circuit_file_names[i]))
	return circuit_file_names

static func friendly_name_array_to_file_nam_arraye(circuit_friendly_names: PackedStringArray) -> PackedStringArray:
	for i in circuit_friendly_names.size():
		circuit_friendly_names[i] = CircuitDetails.friendly_name_to_file_name(circuit_friendly_names[i])
	return circuit_friendly_names

