extends Node

# Test script for the Rust deserializer integration
# This script tests the basic functionality of the FeagiDataDeserializer

func _ready():
	print("🧪 Testing Rust FEAGI Data Deserializer...")
	
	# Debug: Check if the class exists
	print("🔍 DEBUG: Checking if FeagiDataDeserializer class exists...")
	if ClassDB.class_exists("FeagiDataDeserializer"):
		print("✅ FeagiDataDeserializer class found!")
	else:
		print("❌ FeagiDataDeserializer class NOT found!")
		print("Available classes containing 'Feagi': ")
		var all_classes = ClassDB.get_class_list()
		for cls_name in all_classes:
			if "Feagi" in cls_name or "feagi" in cls_name:
				print("  - ", cls_name)
		return
	
	# Test 1: Initialize the deserializer (REQUIRED - no fallback)
	var rust_deserializer = ClassDB.instantiate("FeagiDataDeserializer")
	if rust_deserializer:
		print("✅ Test 1 PASSED: Rust deserializer initialized successfully")
	else:
		print("❌ Test 1 FAILED: Could not initialize Rust deserializer - CRITICAL ERROR!")
		print("🦀 Ensure the feagi_rust_deserializer addon is properly installed.")
		return
	
	# Test 2: Test structure type detection
	var test_buffer = PackedByteArray([11, 1, 0, 0])  # Type 11, Version 1, 0 areas
	var structure_type = rust_deserializer.get_structure_type(test_buffer)
	if structure_type == 11:
		print("✅ Test 2 PASSED: Structure type detection works (got ", structure_type, ")")
	else:
		print("❌ Test 2 FAILED: Expected structure type 11, got ", structure_type)
	
	# Test 3: Test empty buffer handling
	var empty_buffer = PackedByteArray([])
	var empty_type = rust_deserializer.get_structure_type(empty_buffer)
	if empty_type == -1:
		print("✅ Test 3 PASSED: Empty buffer handled correctly (got ", empty_type, ")")
	else:
		print("❌ Test 3 FAILED: Expected -1 for empty buffer, got ", empty_type)
	
	# Test 4: Test Type 11 decoding with minimal data
	var minimal_type11_buffer = PackedByteArray([11, 1, 0, 0])  # Type 11, Version 1, 0 areas
	var decode_result = rust_deserializer.decode_type_11_data(minimal_type11_buffer)
	
	if decode_result.has("success") and decode_result.has("areas") and decode_result.has("total_neurons"):
		if decode_result.success == false and decode_result.total_neurons == 0:
			print("✅ Test 4 PASSED: Type 11 decoding with 0 areas handled correctly")
		else:
			print("❌ Test 4 FAILED: Unexpected result for 0 areas: ", decode_result)
	else:
		print("❌ Test 4 FAILED: Missing expected keys in decode result: ", decode_result)
	
	# Test 5: Test bulk array conversion
	var x_bytes = PackedByteArray([1, 0, 0, 0, 2, 0, 0, 0])  # Two int32s: 1, 2
	var y_bytes = PackedByteArray([3, 0, 0, 0, 4, 0, 0, 0])  # Two int32s: 3, 4
	var z_bytes = PackedByteArray([5, 0, 0, 0, 6, 0, 0, 0])  # Two int32s: 5, 6
	var p_bytes = PackedByteArray([0, 0, 128, 63, 0, 0, 0, 64])  # Two float32s: 1.0, 2.0
	
	var bulk_result = rust_deserializer.convert_bulk_arrays_to_godot(x_bytes, y_bytes, z_bytes, p_bytes)
	
	if bulk_result.has("x_array") and bulk_result.has("y_array") and bulk_result.has("z_array") and bulk_result.has("p_array"):
		var x_array = bulk_result.x_array as PackedInt32Array
		var y_array = bulk_result.y_array as PackedInt32Array
		var z_array = bulk_result.z_array as PackedInt32Array
		var p_array = bulk_result.p_array as PackedFloat32Array
		
		if x_array.size() == 2 and x_array[0] == 1 and x_array[1] == 2:
			print("✅ Test 5a PASSED: X array conversion works: ", x_array)
		else:
			print("❌ Test 5a FAILED: X array conversion failed: ", x_array)
		
		if y_array.size() == 2 and y_array[0] == 3 and y_array[1] == 4:
			print("✅ Test 5b PASSED: Y array conversion works: ", y_array)
		else:
			print("❌ Test 5b FAILED: Y array conversion failed: ", y_array)
		
		if z_array.size() == 2 and z_array[0] == 5 and z_array[1] == 6:
			print("✅ Test 5c PASSED: Z array conversion works: ", z_array)
		else:
			print("❌ Test 5c FAILED: Z array conversion failed: ", z_array)
		
		if p_array.size() == 2 and abs(p_array[0] - 1.0) < 0.001 and abs(p_array[1] - 2.0) < 0.001:
			print("✅ Test 5d PASSED: P array conversion works: ", p_array)
		else:
			print("❌ Test 5d FAILED: P array conversion failed: ", p_array)
	else:
		print("❌ Test 5 FAILED: Missing arrays in bulk conversion result: ", bulk_result)
	
	print("🧪 Rust deserializer testing completed!")
	print("🦀 If all tests passed, the Rust integration is working correctly!")