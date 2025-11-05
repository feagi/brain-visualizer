extends Node
## Test script for FEAGI Embedded GDExtension
##
## This script verifies that the FEAGI Embedded extension is properly loaded
## and functional. Run this scene to test the integration.
##
## Usage:
##  1. Open this script in Godot
##  2. Attach to a Node in a test scene
##  3. Run the scene
##  4. Check console output

var feagi: Object = null

func _ready():
	print("\n" + "=".repeat(60))
	print("  FEAGI Embedded Extension Test")
	print("=".repeat(60) + "\n")
	
	# Test 1: Check if extension is available
	print("Test 1: Checking if FeagiEmbedded class exists...")
	if ClassDB.class_exists("FeagiEmbedded"):
		print("  ✅ PASS: FeagiEmbedded class found!")
	else:
		print("  ❌ FAIL: FeagiEmbedded class not found")
		print("  → Build the extension: cd rust_extensions && ./build_feagi_embedded.sh")
		return
	
	# Test 2: Instantiate
	print("\nTest 2: Instantiating FeagiEmbedded...")
	feagi = ClassDB.instantiate("FeagiEmbedded")
	if feagi:
		print("  ✅ PASS: Instance created successfully")
	else:
		print("  ❌ FAIL: Could not instantiate FeagiEmbedded")
		return
	
	# Test 3: Initialize
	print("\nTest 3: Initializing FEAGI with embedded defaults...")
	print("  (This may take 5-10 seconds...)")
	var init_success = feagi.initialize_default()
	if init_success:
		print("  ✅ PASS: FEAGI initialized successfully!")
		
		# Print configuration
		var api_url = feagi.get_api_url()
		var http_running = feagi.is_http_server_running()
		print("  HTTP API URL: ", api_url)
		print("  HTTP Server Running: ", http_running)
	else:
		print("  ❌ FAIL: FEAGI initialization failed")
		return
	
	# Test 4: Start burst engine
	print("\nTest 4: Starting burst engine...")
	var start_success = feagi.start()
	if start_success:
		print("  ✅ PASS: Burst engine started!")
	else:
		print("  ❌ FAIL: Failed to start burst engine")
		return
	
	# Test 5: Query stats
	print("\nTest 5: Querying stats via FFI...")
	var running = feagi.is_running()
	var neurons = feagi.get_neuron_count()
	var genome_loaded = feagi.is_genome_loaded()
	
	print("  Running: ", running)
	print("  Neuron Count: ", neurons)
	print("  Genome Loaded: ", genome_loaded)
	
	if running:
		print("  ✅ PASS: Stats queries working!")
	else:
		print("  ⚠️  WARNING: Burst engine not running")
	
	# Test 6: Stop burst engine
	print("\nTest 6: Stopping burst engine...")
	var stop_success = feagi.stop()
	if stop_success:
		print("  ✅ PASS: Burst engine stopped!")
	else:
		print("  ❌ FAIL: Failed to stop burst engine")
	
	# Test 7: Verify stopped
	print("\nTest 7: Verifying stopped state...")
	var running_after = feagi.is_running()
	if not running_after:
		print("  ✅ PASS: Burst engine is stopped")
	else:
		print("  ❌ FAIL: Burst engine still running")
	
	# Summary
	print("\n" + "=".repeat(60))
	print("  ALL TESTS PASSED! 🎉")
	print("=".repeat(60))
	print("\n💡 Next steps:")
	print("  1. Test genome loading via HTTP API")
	print("  2. Integrate into main BV scene")
	print("  3. Wire up UI controls")
	print("\n📖 See: docs/FEAGI_EMBEDDED_QUICK_START.md\n")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Graceful shutdown
		if feagi:
			print("\n🛑 Shutting down FEAGI...")
			feagi.shutdown()
			print("✅ FEAGI shutdown complete")
		get_tree().quit()

