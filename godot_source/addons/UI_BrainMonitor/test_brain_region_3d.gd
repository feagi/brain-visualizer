extends Node3D
## Test script to demonstrate the new brain region 3D visualization feature
## This script shows how brain regions are visualized in 3D with input/output splits

class_name TestBrainRegion3D

# This test script demonstrates the new features:
# 1. Brain regions are visualized as 3D frames
# 2. Input cortical areas on the left, output areas on the right
# 3. Non-IO areas are not visualized at the region frame level
# 4. Only root region cortical areas are shown directly in the scene
# 5. Child regions appear as interactive 3D frames

var test_brain_region_3d: UI_BrainMonitor_BrainRegion3D

func _ready():
	print("🧪 TestBrainRegion3D: Starting brain region 3D visualization test")
	_create_test_demonstration()

func _create_test_demonstration():
	print("🧪 Creating demonstration of brain region 3D visualization...")
	
	# This would normally be connected to actual FEAGI brain region data
	# For now, we demonstrate the expected behavior
	
	print("📋 BRAIN REGION 3D VISUALIZATION FEATURES:")
	print("  ✅ 3D Frame Component: UI_BrainMonitor_BrainRegion3D")
	print("  ✅ Red Wireframe Cube: 12 connecting lines forming cube outline") 
	print("  ✅ Input/Output Split: Left side = inputs, Right side = outputs") 
	print("  ✅ Modular Design: Reusable component for any brain region")
	print("  ✅ Integration: Works with existing 3D scene and cortical area rendering")
	print("  ✅ Interaction: Hover and click events for region selection/navigation")
	print("  ✅ Dynamic Updates: Responds to brain region changes")
	
	print("🏗️ ARCHITECTURE OVERVIEW:")
	print("  📦 UI_BrainMonitor_BrainRegion3D - 3D frame visualization component")
	print("  🔄 UI_BrainMonitor_3DScene - Region-based cortical area display logic") 
	print("  🧠 BrainRegion integration - Uses input_open_chain_links & output_open_chain_links")
	print("  🎯 Cortical area classification - IPU/OPU types + connection analysis")
	print("  📍 FEAGI Coordinate Conversion - Proper FEAGI-to-Godot 3D positioning")
	print("  🎮 Display Rules - Root areas shown normally, I/O areas shown inside cubes")
	
	print("📱 USAGE EXAMPLE:")
	print("  1. Create brain region: var region = get_brain_region_from_feagi()")
	print("  2. Setup 3D scene: brain_monitor.setup(root_region)")  
	print("  3. Child regions appear as 3D frames with input/output split")
	print("  4. Direct cortical areas of root region shown normally")
	print("  5. Double-click frames for future navigation/diving")
	
	print("🎮 DISPLAY RULES:")
	print("  ✅ Root region cortical areas → Show in normal 3D position")
	print("  ❌ Child region cortical areas → Hide from main 3D space")
	print("  🔄 Child region I/O areas → Show on red plates (positioned above plates)")
	print("  🔗 I/O Detection → input_open_chain_links + output_open_chain_links + IPU/OPU types")
	print("  📏 Plate size → Auto-calculate based on I/O area dimensions + padding")
	print("  🎯 Positioning → Input areas left side, output areas right side of plate")
	print("  🔄 Architecture → 3D scene creates visualizations, brain regions move them onto plates")
	print("  🔧 Fixed → Competing display logic that was preventing I/O areas from appearing")
	print("  🔧 Fixed → Missing iteration through child region areas (c__rig, c__lef now detected)")
	print("  🎯 API Support → Works with direct 'inputs'/'outputs' arrays from FEAGI API")
	print("  🔧 Fixed → Missing connection chain links with intelligent naming fallbacks")
	print("  🧠 Smart Detection → c__rig (input), c__lef (output) via naming heuristics")
	print("  📏 Fixed → Cortical area scaling/positioning (now works with _static_body children)")
	print("  🎯 Renderer Support → Scales DDA/DirectPoints _static_body + _friendly_name_label")
	print("  🏗️ Architecture → Node containers with StaticBody3D + Label3D children")
	print("  🆕 NEW: Plate Design → XZ plane sized based on I/O area dimensions")
	print("  🔴 Plate Material → Semi-transparent red, sits underneath cortical areas")
	
	print("🔮 FUTURE ENHANCEMENTS:")
	print("  📑 Tab system for navigating between regions")
	print("  🎨 Improved frame materials and visual effects")  
	print("  📏 Dynamic frame sizing based on content")
	print("  🔗 Connection visualization between regions")
	print("  ⚙️ User configuration for frame appearance")

## Example function showing how to programmatically create a brain region frame
func create_example_brain_region_frame(brain_region: BrainRegion) -> UI_BrainMonitor_BrainRegion3D:
	var region_frame = UI_BrainMonitor_BrainRegion3D.new()
	add_child(region_frame)
	region_frame.setup(brain_region)
	
	# Connect signals for interaction handling
	region_frame.region_double_clicked.connect(_on_region_double_clicked)
	region_frame.region_hover_changed.connect(_on_region_hover_changed)
	
	print("🏗️ Created 3D frame for brain region: %s" % brain_region.friendly_name)
	return region_frame

func _on_region_double_clicked(brain_region: BrainRegion):
	print("🎯 Brain region double-clicked: %s - ready for navigation" % brain_region.friendly_name)
	# Future: Implement tab navigation to dive into this region

func _on_region_hover_changed(brain_region: BrainRegion, is_hovered: bool):
	print("👆 Brain region hover: %s, hovered: %s" % [brain_region.friendly_name, is_hovered])

## Test function to validate input/output area classification
func test_input_output_classification(brain_region: BrainRegion):
	print("🔍 Testing input/output classification for region: %s" % brain_region.friendly_name)
	
	var input_areas: Array[AbstractCorticalArea] = []
	var output_areas: Array[AbstractCorticalArea] = []
	
	# Check input_open_chain_links for input areas
	for link: ConnectionChainLink in brain_region.input_open_chain_links:
		if link.destination and link.destination is AbstractCorticalArea:
			var area = link.destination as AbstractCorticalArea
			if area in brain_region.contained_cortical_areas:
				input_areas.append(area)
	
	# Check output_open_chain_links for output areas  
	for link: ConnectionChainLink in brain_region.output_open_chain_links:
		if link.source and link.source is AbstractCorticalArea:
			var area = link.source as AbstractCorticalArea
			if area in brain_region.contained_cortical_areas:
				output_areas.append(area)
	
	# Also check cortical area types
	for area: AbstractCorticalArea in brain_region.contained_cortical_areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
			input_areas.append(area)
		elif area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
			output_areas.append(area)
	
	print("  📥 Input areas: %d" % input_areas.size())
	print("  📤 Output areas: %d" % output_areas.size())
	
	for area in input_areas:
		print("    🔵 Input: %s (%s)" % [area.cortical_ID, area.type_as_string])
	for area in output_areas:
		print("    🔴 Output: %s (%s)" % [area.cortical_ID, area.type_as_string])

## Test function to validate FEAGI coordinate positioning
func test_positioning_system(brain_region: BrainRegion, feagi_coordinates: Vector3i):
	print("📍 Testing FEAGI coordinate positioning system")
	print("  🧠 Region: %s" % brain_region.friendly_name)
	print("  📊 FEAGI coords: %v" % feagi_coordinates)
	
	var region_frame = create_example_brain_region_frame(brain_region)
	# Test positioning (normally happens automatically in setup)
	region_frame.call("_update_position", feagi_coordinates)
	
	print("  🎯 Final Godot position: %v" % region_frame.position)
	print("  ✅ Position conversion includes:")
	print("    - Z-axis flip for Godot coordinate system")  
	print("    - Center offset calculation based on frame size")
	print("    - Consistent with cortical area positioning")
	
	print("")
	print("🔍 DEBUG CHECKLIST - Look for these messages in order:")
	print("")
	print("🧠 3D Scene Setup (should happen FIRST):")
	print("1. '🧠 BrainMonitor 3D Scene: SETUP STARTED for region: root'")
	print("2. '🔄 STEP 2: Processing child regions for I/O areas...'")  
	print("3. '📦 Evaluating CHILD area: c__rig (type: CUSTOM) from region region_A'")
	print("4. '✅ Found as INPUT via naming heuristic (contains c__rig)!'")
	print("5. '✅ Area c__rig IS I/O of child region' - creating visualization")
	print("6. '✅ Found as I/O of child region' (unified logic check)")
	print("7. '✅ Successfully created visualization for c__rig'")
	print("8. '🏗️ STEP 3: Creating brain region wireframe cubes...'")
	print("9. '🏁 BrainMonitor 3D Scene: SETUP COMPLETED'")
	print("")
	print("🧠 Brain Region Setup (should happen AFTER 3D scene):")
	print("10. '🏗️ BrainRegion3D Setup started for region: region_A'")
	print("11. '📏 Analyzing I/O cortical area dimensions for plate sizing:'")
	print("12. '🔴 BrainRegionPlate: Created red XZ plate for region'")
	print("13. '🔄 Moving area c__rig from main scene to plate left side'")
	print("14. '🔄 Moving area c__lef from main scene to plate right side'")
	print("")
	print("🆕 NEW DESIGN: Plate replaces wireframe cube!")
	print("🔧 Plate size calculated from I/O area dimensions + padding")
	print("📍 Cortical areas positioned ON TOP of semi-transparent red plate")
	print("💡 Expected Result: c__rig (LEFT) and c__lef (RIGHT) on red XZ plate!")
	
	return region_frame
