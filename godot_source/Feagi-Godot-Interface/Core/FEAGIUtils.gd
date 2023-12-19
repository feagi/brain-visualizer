extends Object
class_name FEAGIUtils
## A set of functions that are useful around the program. Treat this class as static

## Converts untyped array to int array
static func arr_to_int_arr(arr: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(arr)
	return out

## Converts untyped array to flloat array
static func arr_to_float_arr(arr: Array) -> Array[float]:
	var out: Array[float] = []
	out.assign(arr)
	return out

## Converts a 3 long int array to a Vector3i
static func int_array_to_vector3i(input: Array[int]) -> Vector3i:
	return Vector3i(int(input[0]), int(input[1]), int(input[2]))

## Converts a 2 long int array to a Vector2i
static func int_array_to_vector2i(input: Array[int]) -> Vector2i:
	return Vector2i(int(input[0]), int(input[1]))

## Converts a 3 long untyped array to a Vector3i
static func array_to_vector3i(input: Array[Variant]) -> Vector3i:
	return Vector3i(int(input[0]), int(input[1]), int(input[2]))

## Converts a 2 long untyped array to a Vector2i
static func array_to_vector2i(input: Array) -> Vector2i:
	return Vector2i(int(input[0]), int(input[1]))

## Converts an array of 3 long int arrays to an array of Vector3i
static func array_of_arrays_to_vector3i_array(input: Array[Array]) -> Array[Vector3i]:
	var output: Array[Vector3i] = []
	for sub_array in input:
		output.append(array_to_vector3i(sub_array))
	return output

## Converts an array of 2 long int arrays to an array of Vector3i
static func array_of_arrays_to_vector2i_array(input: Array[Array]) -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	for sub_array in input:
		output.append(array_to_vector2i(sub_array))
	return output

## Converts a Vector3i to a 3 long int array
static func vector3i_to_array(input: Vector3i) -> Array[int]:
	var output: Array[int] = [input.x, input.y, input.z]
	return output

## Converts a Vector3 to a 3 long float array
static func vector3_to_array(input: Vector3) -> Array[float]:
	var output: Array[float] = [input.x, input.y, input.z]
	return output

## Converts a Vector2i to a 2 long int array
static func vector2i_to_array(input: Vector2i) -> Array[int]:
	var output: Array[int] = [input.x, input.y]
	return output

static func vector3i_array_to_array_of_arrays(input: Array[Vector3i]) -> Array[Array]:
	var output: Array[Array] = []
	for v in input:
		output.append(vector3i_to_array(v))
	return output

static func vector2i_array_to_array_of_arrays(input: Array[Vector2i]) -> Array[Array]:
	var output: Array[Array] = []
	for v in input:
		output.append(vector2i_to_array(v))
	return output


## JSON library of godot does funny things, use this instead
static func vector3i_to_string(input: Vector3i) -> String:
	return "[%d,%d,%d]" % vector3i_to_array(input)

## JSON library of godot does funny things, use this instead
static func vector2i_to_string(input: Vector2i) -> String:
	return "[%d,%d,%d]" % vector2i_to_array(input)

# This is the best name
static func array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(input: Array[PatternVector3Pairs]) -> Array[Array]:
	var output: Array[Array] = []
	for pattern_pair in input:
		output.append(pattern_pair.to_array_of_arrays())
	return output

## Keeps input within defined bounds (floats)
static func bounds(input: float, lower: float, upper: float) -> float:
	if input < lower:
		return lower
	if input > upper:
		return upper
	return input

## Keeps input within defined bounds (for ints)
static func bounds_int(input: int, lower: int, upper: int) -> int:
	if input < lower:
		return lower
	if input > upper:
		return upper
	return input

## Limits text length to a certain length, if too long, cuts off end and replaces with '...'
static func limit_text_length(input: String, limit: int) -> String:
	if input.length() > (limit - 3):
		input = input.left(limit - 3) + "..."
	return input

## returns an array of elements that are in both input arrays
static func find_union(array_1: Array, array_2: Array) -> Array:
	var output: Array = []
	for e1 in array_1:
		if e1 in array_2:
			output.append(e1)
	return output

## returns an array of elements within "is_missing" that is missing from "is_missing_from"
static func find_missing_elements(is_missing: Array, is_missing_from: Array) -> Array:
	var output: Array = []
	for e in is_missing:
		if e not in is_missing_from:
			output.append(e)
	return output

## Combines 2 arrays without repeating elements
static func find_total_non_repeating(array_1: Array, array_2: Array) -> Array:
	var output: Array = array_1.duplicate()
	for e2 in array_2:
		if !(e2 in output):
			output.append(e2)
	return output


## why is this so dumb
static func untyped_array_to_int_array(input: Array) -> Array[int]:
	var output: Array[int] = []
	for i in input:
		output.append(int(i))
	return output

## bool type to 'true" or 'false'
static func bool_2_string(input: bool) -> StringName:
	if input:
		return &"true"
	else:
		return &"false"

## string type to bool
static func string_2_bool(input: String) -> bool:
	if input == "true":
		return true
	return false

## check if substring is in any element of a PackedStringArray
static func is_substring_in_array(arr: PackedStringArray, searching: String) -> bool:
	for element in arr:
		if element.contains(searching):
			return true
	return false

## Turn StringName Array into CSV string
static func string_name_array_to_CSV(arr: Array[StringName]) -> StringName:
	var output: String = ""
	var length: int = len(arr)
	if length == 0:
		return output
	for i in (length - 1):
		output = output + arr[i] + ", "
	output = output + arr[length - 1]
	return output

