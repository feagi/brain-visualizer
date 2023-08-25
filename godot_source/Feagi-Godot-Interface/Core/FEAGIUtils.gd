extends Object
class_name FEAGIUtils
## A set of functions that are useful around the program. Treat this class as static

## Converts a 3 long int array to a Vector3i
static func array_to_vector3i(input: Array) -> Vector3i:
	return Vector3i(input[0], input[1], input[2])

## Converts a 2 long int array to a Vector2i
static func array_to_vector2i(input: Array) -> Vector2i:
	return Vector2i(input[0], input[1])

## Converts an array of 3 long int arrays to an array of Vector3i
static func array_of_arrays_to_vector3i_array(input: Array[Array]) -> Array[Vector3i]:
	var output: Array[Vector3i] = []
	for sub_array in input:
		output.append(array_to_vector3i(sub_array))
	return output

## Converts an array of 32 long int arrays to an array of Vector3i
static func array_of_arrays_to_vector2i_array(input: Array[Array]) -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	for sub_array in input:
		output.append(array_to_vector2i(sub_array))
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
