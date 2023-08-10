extends Node
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
