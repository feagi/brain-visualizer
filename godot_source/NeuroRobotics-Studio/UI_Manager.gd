extends Control
class_name UI_Manager

# This scripts handles UI instantiation, control, and feedback

#####################################

# Properties and Public Vars

var currentLanguageISO: String:
	get: return _currentLanguageISO
	set(v):
		_currentLanguageISO = v
		if(!Activated): return
		#TODO language changing code

var Activated: bool = false

# References
var UI_Top_TopBar: Newnit_Box
var UI_LeftBar: Newnit_Popup
var UI_createcorticalBar : Newnit_Box
var UI_ManageNeuronMorphology : Newnit_Popup
var UI_MappingDefinition : Newnit_Box
var UI_CircuitImport : Newnit_Box
var UI_GraphCore: GraphCore
var UI_CreateMorphology: Newnit_Box
var UI_INDICATOR: Newnit_Box
var cache: FeagiCache
var vectors_holder = []
var src_global 
var dst_global
var import_close_button
var UI_holders = []
var global_json_data
var optionbutton_holder
var morphology_creation_add_button

# Internal cached vars
var _sideBarChangedValues := {}

#####################################
# Initialization

func Activate(langISO: String):
	# Initialize Vars
	currentLanguageISO = langISO #TODO Better language handling
	# Initialize UI
	
	# Initialize TopBar
	var topBarDict = HelperFuncs.GenerateDefinedUnitDict("TOPBAR", currentLanguageISO)
	_SpawnTopBar(topBarDict)
	var filess = FileAccess.open("res://brain_visualizer_source/type_option.json", FileAccess.READ)
	var test_json_conv = JSON.new()
	test_json_conv.parse(filess.get_as_text())
	global_json_data = test_json_conv.get_data()
	filess.close()
#	SpawnIndicator(createindicator)
#	SpawnNeuronManager()
	# Initialize GraphCore
	UI_GraphCore = $graphCore #TODO: this is very temporary
	UI_GraphCore.DataUp.connect(GraphEditInput)
	
	# Connect window size change function
	get_tree().get_root().size_changed.connect(WindowSizedChanged)

	Activated = true
	

func _SpawnTopBar(activation: Dictionary):
	UI_Top_TopBar = Newnit_Box.new()
	add_child(UI_Top_TopBar)
	UI_Top_TopBar.Activate(activation)
	UI_Top_TopBar.DataUp.connect(TopBarInput)
	# TODO best not to connect to Element children, better to connect to element signals itself
	# This may work for now but can cause weird issues later
	var import_circuit = UI_Top_TopBar.GetReferenceByID("GENOMEFILENAME").get_node("sideButton_GENOMEFILENAME")
	import_circuit.connect("pressed", Callable($Brain_Visualizer,"_on_import_pressed"))


####################################
####### Input Event Handling #######
####################################

signal DataUp(data: Dictionary)

######### Top Bar Control ##########
# We should be using this to make things more streamline
func TopBarInput(data: Dictionary, ElementID: StringName, ElementRef: Node):
	print("data: ", data, "elementid: ", ElementID)
	match(ElementID):
		"CORTICALAREAS":
			if "selectedIndex" in data.keys():
				var name_from_dropdown = UI_Top_TopBar.GetReferenceByID("CORTICALAREAS").get_node("dropDown_CORTICALAREAS").text
				$Brain_Visualizer.camera_list_selected(name_from_dropdown)
			if "sideButton" in data.keys():
				if not UI_createcorticalBar:
					SpawnCorticalCrete()
				else:
					UI_createcorticalBar.queue_free()
		"NEURONMORPHOLOGIES":
			if "sideButton" in data.keys():
				if not UI_CreateMorphology:
					SpawnCreateMophology()
				else:
					UI_CreateMorphology.queue_free()
			if "selectedIndex" in data.keys():
				if UI_ManageNeuronMorphology != null:
					UI_ManageNeuronMorphology.queue_free()
				var rule_name = UI_Top_TopBar.GetReferenceByID("NEURONMORPHOLOGIES").get_node("dropDown_NEURONMORPHOLOGIES").text
				if rule_name != " ":
					if "+" in rule_name:
						rule_name = rule_name.replace("+", "%2B")
					if "[" in rule_name:
						rule_name = rule_name.replace("[", "%5B")
					if "]" in rule_name:
						rule_name = rule_name.replace("]", "%5D")
					if ", " in rule_name:
						rule_name = rule_name.replace(", ", "%2C%20")
					$"..".Get_Morphology_information(rule_name)
					$"..".GET_USUAGE_MORPHOLOGY(rule_name)
				SpawnNeuronManager()
				UI_ManageNeuronMorphology.GetReferenceByID("header_title").get_node("field_header_title").text = rule_name
		"REFRESHRATE":
			DataUp.emit({"updatedBurstRate": data["value"]})

func CreateMorphologyInput(data: Dictionary, ElementID: String, ElementRef: Node):
	match(ElementID):
		"MorphologyType":
		#Drop down is changed, toggle between available morphology wizards
			var composite = UI_CreateMorphology.GetReferenceByID("Composite")
			var patterns = UI_CreateMorphology.GetReferenceByID("Patterns")
			var vectors = UI_CreateMorphology.GetReferenceByID("Vectors")
			if data["selectedIndex"] == 0:
				$Brain_Visualizer.new_morphology_clear()
				composite.visible = true; patterns.visible = false; vectors.visible = false; morphology_creation_add_button.visible = false
				UI_CreateMorphology.SetData({"Composite": {"MAPPING_DROPDOWN": {"MAPPINGDROPDOWN":{"options": optionbutton_holder}}}})
			if data["selectedIndex"] == 1:
				$Brain_Visualizer.new_morphology_clear()
				morphology_creation_add_button.emit_signal("pressed")
				composite.visible = false; patterns.visible = true; vectors.visible = false; morphology_creation_add_button.visible = true
			if data["selectedIndex"] == 2:
				$Brain_Visualizer.new_morphology_clear()
				composite.visible = false; patterns.visible = false; vectors.visible = true; morphology_creation_add_button.visible = true
				morphology_creation_add_button.emit_signal("pressed")
######### Side Bar Control #########

func LeftBarInput(data: Dictionary, _compRef, _unitRef):
#	print(JSON.stringify(data)) # useful for debugging
	match(data["ID"]):
		"UpdateButton":
			# Push update to cortex
			# only push stuff that do not match what is cached
#			_sideBarChangedValues["cortical_id"] = UI_LeftBar.data["CorticalName"]
			$"..".Update_Genome_CorticalArea(_sideBarChangedValues)
			_sideBarChangedValues = {} # reset
		_:
			# Check if this is a neuron property, if so cache change for Update
			if _isNeuronProperty(data["ID"]):
				_sideBarChangedValues[data["ID"]] = data["value"]

func _isNeuronProperty(ID: String) -> bool:
	if ID == "VoxelNeuronDensity": return true
	if ID == "SynapticAttractivity": return true
	if ID == "PostSynapticPotential": return true
	if ID == "PSPMax": return true
	if ID == "PlasticityConstant": return true
	if ID == "FireThreshold": return true
	if ID == "Thresholdlimit": return true
	if ID == "RefactoryPeriod": return true
	if ID == "LeakConstant": return true
	if ID == "LeakVaribility": return true
	if ID == "ThresholdINC": return true
	if ID == "ConsecutiveFireCount": return true
	if ID == "SnoozePeriod": return true
	if ID == "DegeneracyConstant": return true
	return false

func CorticalCreateInput(data: Dictionary, ElementID: StringName, ElementRef: Node):
	match(ElementID):
		"CORTICALAREA":
			if data["selectedIndex"] == 1:
				UI_createcorticalBar.GetReferenceByID("corticalnamedrop").visible = true
				UI_createcorticalBar.GetReferenceByID("OPUIPU").visible = true
				UI_createcorticalBar.GetReferenceByID("corticalnametext").visible = false
				$"..".GET_OPU('OPU')
			elif data["selectedIndex"] == 2:
				UI_createcorticalBar.GetReferenceByID("corticalnamedrop").visible = true
				UI_createcorticalBar.GetReferenceByID("OPUIPU").visible = true
				UI_createcorticalBar.GetReferenceByID("corticalnametext").visible = true
				$"..".GET_IPU('IPU')
			elif data["selectedIndex"] == 3:
				UI_createcorticalBar.GetReferenceByID("corticalnamedrop").visible = false
				UI_createcorticalBar.GetReferenceByID("corticalnametext").visible = true
				UI_createcorticalBar.GetReferenceByID("OPUIPU").visible = false

############ Graph Edit ############

# Takes input from GraphEdit
func GraphEditInput(data: Dictionary):
	if "CortexSelected" in data.keys():
		# Cortex has been selected, pop up side bar
#		SpawnLeftBar(data["CortexSelected"])
		DataUp.emit(data)
	pass

# Is called whenever the game window size changes
func WindowSizedChanged():
	var viewPortSize: Vector2 = get_viewport_rect().size
	UI_GraphCore.size = viewPortSize

####################################
###### Relay Feagi Dependents ######
####################################

# Handles Recieving data from Core, and distributing it to the correct element
func RelayDownwards(callType, data) -> void:
	match(callType):
		REF.FROM.healthstatus:
			if data["burst_engine"]:
				$"../../color_indicator/ColorRect".set_color(Color("#008F00"))
			else:
				$"../../color_indicator/ColorRect".set_color(Color("#131313"))
			if data["genome_availability"]:
				$"../../color_indicator/ColorRect2".set_color(Color("#008F00"))
			else:
				$"../../color_indicator/ColorRect2".set_color(Color("#131313"))
			if data["genome_validity"]:
				$"../../color_indicator/ColorRect3".set_color(Color("#008F00"))
			else:
				$"../../color_indicator/ColorRect3".set_color(Color("#131313"))
			if data["brain_readiness"]:
				$"../../color_indicator/ColorRect4".set_color(Color("#008F00"))
			else:
				$"../../color_indicator/ColorRect4".set_color(Color("#131313"))

		REF.FROM.circuit_size:
			if UI_CircuitImport:
				UI_CircuitImport.SetData({"WHD": {"W":{"value": int(data[0])}, "H":{"value": int(data[1])}, "D":{"value": int(data[2])}}})
		REF.FROM.circuit_list:
			if UI_CircuitImport:
				UI_CircuitImport.SetData({"dropdowncircuit": {"options":data}})
#		REF.FROM.pns_current_ipu:
#			pass
#		REF.FROM.pns_current_opu:
#			pass
		REF.FROM.genome_corticalAreaIdList:
			if UI_Top_TopBar:
				UI_Top_TopBar.SetData({"CORTICALAREAS": {"options":data}})
			if UI_MappingDefinition:
				UI_MappingDefinition.SetData({"testlabel": {"SOURCECORTICALAREA":{"options": data, "value": src_global}}})
				UI_MappingDefinition.SetData({"testlabel": {"DESTINATIONCORTICALAREA":{"options": data, "value": dst_global}}})
		REF.FROM.genome_morphologyList:
			if UI_Top_TopBar:
				UI_Top_TopBar.SetData({"NEURONMORPHOLOGIES": {"options":data}})
			if UI_MappingDefinition != null:
				UI_MappingDefinition.SetData({"third_box": {"mappingdefinitions": {"options": data}}})
				var original_dropdown = UI_MappingDefinition.get_node("box_third_box").get_node("dropdown_mappingdefinitions").get_node("dropDown_mappingdefinitions")
				for i in UI_MappingDefinition.get_children():
					if "Unit_third_box" in i.get_name():
						for x in original_dropdown.get_item_count():
							i.get_node("dropdown_mappingdefinitions").get_node("dropDown_mappingdefinitions").add_item(original_dropdown.get_item_text(x))
				UI_MappingDefinition.get_node("box_third_box").visible = false
			if UI_CreateMorphology != null:
				if UI_CreateMorphology.GetReferenceByID("Composite").visible:
					UI_CreateMorphology.SetData({"Composite": {"MAPPING_DROPDOWN": {"MAPPINGDROPDOWN":{"options": data}}}})
			optionbutton_holder = data
		REF.FROM.genome_fileName:
			UI_Top_TopBar.SetData({"GENOMEFILENAME": {"sideLabelText":data}})
#		REF.FROM.connectome_properties_mappings:
#			pass
#		REF.FROM.godot_fullCorticalData:
#			UI_GraphCore.RelayDownwards(REF.FROM.godot_fullCorticalData, data)
		REF.FROM.OPULIST:
			if UI_createcorticalBar:
				UI_createcorticalBar.SetData({"corticalnamedrop": {"CORTICALAREADROPDOWNINBOX": {"options": data}}})
		REF.FROM.IPULIST:
			if UI_createcorticalBar:
				UI_createcorticalBar.SetData({"corticalnamedrop": {"CORTICALAREADROPDOWNINBOX": {"options": data}}})
		REF.FROM.genome_corticalArea:
#			# Data for Specific Cortical Area
#			# Race conditions are technically possible. Verify input
			if UI_LeftBar == null: 
				return # ignore if Leftbar isnt open

#			# Assemble Dict to input values
			var inputVars = {
				"VoxelNeuronDensity": {"value": int(data["cortical_neuron_per_vox_count"])},
				"SynapticAttractivity": {"value": int(data["cortical_synaptic_attractivity"])},
				"PostSynapticPotential": {"value": data["neuron_post_synaptic_potential"]},
				"PSPMax": {"value": data["neuron_post_synaptic_potential_max"]},
				"PlasticityConstant": {"value": data["neuron_plasticity_constant"]},
				"FireThreshold": {"value": data["neuron_fire_threshold"]},
				"Thresholdlimit": {"value": int(data["neuron_firing_threshold_limit"])},
				"RefactoryPeriod": {"value": int(data["neuron_refractory_period"])},
				"LeakConstant": {"value": data["neuron_leak_coefficient"]},
				"LeakVaribility": {"value": data["neuron_leak_variability"]},
				"ConsecutiveFireCount": {"value": int(data["neuron_consecutive_fire_count"])},
				"SnoozePeriod": {"value": data["neuron_snooze_period"]},
				"ThresholdINC": {"value": data["neuron_fire_threshold_increment"]},
				"DegeneracyConstant": {"value": data["neuron_degeneracy_coefficient"]},
				"ChargeACC": {"value": data["neuron_mp_charge_accumulation"]},
				"PSPUNI": {"value": data["neuron_psp_uniform_distribution"]}
			}
			var cortical_properties = {
				"CorticalPropertiesSection": {"CorticalName": {"sideLabelText": data["cortical_name"]},
				"CorticalID": {"sideLabelText": data["cortical_id"]},
				"CorticalArea": {"sideLabelText": data["cortical_group"]},
				"XYZ": {"Pos_X": {"value": int(data["cortical_coordinates"][0])}, "Pos_Y": {"value": int(data["cortical_coordinates"][1])}, "Pos_Z": {"value": int(data["cortical_coordinates"][2])}},
				"WHD": {"W": {"value": int(data["cortical_dimensions"][0])}, "H": {"value": int(data["cortical_dimensions"][1])}, "D": {"value": int(data["cortical_dimensions"][2])}}}
			}
#			#print(inputVars)
			UI_LeftBar.SetData({"NeuronParametersSection": inputVars} )
			UI_LeftBar.SetData(cortical_properties)
			$"..".Update_Afferent_list(data["cortical_id"])
		REF.FROM.burstEngine:
			UI_Top_TopBar.SetData({"REFRESHRATE": {"value": data}})
	pass


####################################
############# Internals ############
####################################

func SpawnLeftBar(cortexName: String, activation: Dictionary):
	if UI_LeftBar != null:
		UI_LeftBar.queue_free() # We don't need this. We need to make it look prettier
	$"..".Update_GenomeCorticalArea_SPECIFC(cortexName) # Tell core to update cortex Info
	UI_LeftBar = Newnit_Popup.new()
	add_child(UI_LeftBar)
	UI_LeftBar.Activate(activation)
	UI_holders.append(UI_LeftBar)

	# Please do not get_children on nodes due to panel abstraction
	var delete_button = UI_LeftBar.GetReferenceByID("UpdateButtonTop").get_node("sideButton_UpdateButtonTop")
	var update1 = UI_LeftBar.GetReferenceByID("UpdateButtonTop").get_node("button_UpdateButtonTop")
	var update=UI_LeftBar.GetReferenceByID("NeuronParametersSection").GetReferenceByID("UpdateButton").get_node("button_UpdateButton")

	var add_row_button = UI_LeftBar.GetReferenceByID("EFFERENTLABEL").get_node("sideButton_EFFERENTLABEL")
	delete_button.connect("pressed", Callable($Brain_Visualizer,"_on_remove_pressed").bind(UI_LeftBar.GetReferenceByID("CorticalID")))
	update.connect("pressed", Callable($Brain_Visualizer,"_on_Update_pressed").bind(UI_LeftBar))
	update1.connect("pressed", Callable($Brain_Visualizer,"_on_Update_pressed").bind(UI_LeftBar))
	add_row_button.connect("pressed", Callable($Brain_Visualizer,"_on_cortical_mapping_add_pressed").bind(cortexName))


func mapping_definition_button(node):
	var src_id = UI_LeftBar.GetReferenceByID("CorticalName").get_node("sideLabel_CorticalName").text
	var mappingdefinitiongenerated = HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO)
	SpawnMappingDefinition(src_id, node.text, mappingdefinitiongenerated)

func SpawnCreateMophology():
	var CMDict = HelperFuncs.GenerateDefinedUnitDict("CREATEMORPHOLOGY", currentLanguageISO)
	UI_CreateMorphology = Newnit_Box.new()
	add_child(UI_CreateMorphology)
	UI_CreateMorphology.Activate(CMDict)
	var composite = UI_CreateMorphology.GetReferenceByID("Composite")
	var patterns = UI_CreateMorphology.GetReferenceByID("Patterns")
	var vectors = UI_CreateMorphology.GetReferenceByID("Vectors")
	var add_row = UI_CreateMorphology.get_node("button_AddRowButton").get_node("button_AddRowButton")
	var create_button = UI_CreateMorphology.GetReferenceByID("UPDATEBUTTON").get_node("button_UPDATEBUTTON")
	composite.visible = false
	patterns.visible = false
	vectors.visible = false
	add_row.visible = false
	vectors.get_node("box_XYZ").visible = false
	patterns.get_node("box_PatternRow0").visible = false
	$"..".Update_MorphologyList()
	UI_CreateMorphology.DataUp.connect(CreateMorphologyInput)
	UI_holders.append(UI_CreateMorphology)
	morphology_creation_add_button = add_row
	morphology_creation_add_button.connect("pressed", Callable($Brain_Visualizer,"_morphology_button_pressed").bind(UI_CreateMorphology))
	create_button.connect("pressed", Callable($Brain_Visualizer,"_on_create_pressed").bind(UI_CreateMorphology))

func SpawnCorticalCrete():
	UI_createcorticalBar = Newnit_Box.new()
	var createcorticalBar = HelperFuncs.GenerateDefinedUnitDict("CORTICAL_CREATE", currentLanguageISO)
	add_child(UI_createcorticalBar)
	UI_createcorticalBar.Activate(createcorticalBar)
	UI_createcorticalBar.DataUp.connect(CorticalCreateInput)
	UI_holders.append(UI_createcorticalBar)
	UI_createcorticalBar.SetData({"CORTICALAREA": {"options": (global_json_data["option"])}})
	var update = UI_createcorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton")
	var whd = UI_createcorticalBar.GetReferenceByID("WHD")
	var xyz = UI_createcorticalBar.GetReferenceByID("XYZ")
	var name_input = UI_createcorticalBar.GetReferenceByID("corticalnametext").get_node("field_CORTICALAREAFIELD").get_node("field_CORTICALAREAFIELD")
	var optionlist = UI_createcorticalBar.GetReferenceByID("CORTICALAREA").get_node("dropDown_CORTICALAREA")
	var w = whd.get_node("counter_W").get_node("counter_W")
	var h = whd.get_node("counter_H").get_node("counter_H")
	var d = whd.get_node("counter_D").get_node("counter_D")
	var x = xyz.get_node("counter_Pos_X").get_node("counter_Pos_X")
	var y = xyz.get_node("counter_Pos_Y").get_node("counter_Pos_Y")
	var z = xyz.get_node("counter_Pos_Z").get_node("counter_Pos_Z")
	w.connect("value_changed",Callable($Brain_Visualizer,"_on_W_Spinbox_value_changed").bind([w,h,d,x,y,z]))
	h.connect("value_changed",Callable($Brain_Visualizer,"_on_H_Spinbox_value_changed").bind([w,h,d,x,y,z]))
	d.connect("value_changed",Callable($Brain_Visualizer,"_on_D_Spinbox_value_changed").bind([w,h,d,x,y,z]))
	x.connect("value_changed",Callable($Brain_Visualizer,"_on_X_SpinBox_value_changed").bind([w,h,d,x,y,z]))
	y.connect("value_changed",Callable($Brain_Visualizer,"_on_Y_Spinbox_value_changed").bind([w,h,d,x,y,z]))
	z.connect("value_changed",Callable($Brain_Visualizer,"_on_Z_Spinbox_value_changed").bind([w,h,d,x,y,z]))
	name_input.connect("text_changed",Callable($"../../Button_to_Autoload","_on_type_text_changed"))
	update.connect("pressed",Callable($Brain_Visualizer,"_on_add_pressed").bind([w,h,d,x,y,z, name_input, optionlist, update]))

func SpawnIndicator(activation: Dictionary):
	UI_INDICATOR = Newnit_Box.new()
	add_child(UI_INDICATOR)
	UI_INDICATOR.Activate(activation)
	UI_holders.append(UI_INDICATOR)


func SpawnCircuitImport(activation: Dictionary):
	UI_CircuitImport = Newnit_Box.new()
	add_child(UI_CircuitImport)
	UI_CircuitImport.Activate(activation)
	UI_holders.append(UI_CircuitImport)
	# Link to BV
	var dropdown = UI_CircuitImport.GetReferenceByID("dropdowncircuit").get_node("dropDown_dropdowncircuit")
	var x = UI_CircuitImport.GetReferenceByID("XYZ").get_node("counter_Pos_X").get_node("counter_Pos_X")
	var y = UI_CircuitImport.GetReferenceByID("XYZ").get_node("counter_Pos_Y").get_node("counter_Pos_Y")
	var z = UI_CircuitImport.GetReferenceByID("XYZ").get_node("counter_Pos_Z").get_node("counter_Pos_Z")
	var w = UI_CircuitImport.GetReferenceByID("WHD").get_node("counter_W").get_node("counter_W")
	var h = UI_CircuitImport.GetReferenceByID("WHD").get_node("counter_H").get_node("counter_H")
	var d = UI_CircuitImport.GetReferenceByID("WHD").get_node("counter_D").get_node("counter_D")
	var import_button = UI_CircuitImport.GetReferenceByID("UpdateButtonTop").get_node("button_UpdateButtonTop")
	import_button.connect("pressed", Callable($Brain_Visualizer,"_on_insert_button_pressed").bind([dropdown, x,y,z]))
	dropdown.connect("item_selected",Callable($Brain_Visualizer,"_on_ItemList_item_selected").bind(dropdown))
	x.connect("value_changed",Callable($Brain_Visualizer,"_on_x_spinbox_value_changed").bind([x, y, z, w, h, d]))
	y.connect("value_changed",Callable($Brain_Visualizer,"_on_y_spinbox_value_changed").bind([x, y, z, w, h, d]))
	z.connect("value_changed",Callable($Brain_Visualizer,"_on_z_spinbox_value_changed").bind([x, y, z, w, h, d]))

func SpawnNeuronManager():
	UI_ManageNeuronMorphology = Newnit_Popup.new()
	var cerateneuronmorphology = HelperFuncs.GenerateDefinedUnitDict("MANAGE_MORPHOLOGY", currentLanguageISO)
	add_child(UI_ManageNeuronMorphology)
	UI_ManageNeuronMorphology.Activate(cerateneuronmorphology)
	UI_holders.append(UI_ManageNeuronMorphology)
	var save_button = UI_ManageNeuronMorphology.GetReferenceByID("SAVEDELETE").get_node("button_SAVEDELETE")
	var vectors = UI_ManageNeuronMorphology.GetReferenceByID("Vectors")
	var composite = UI_ManageNeuronMorphology.GetReferenceByID("Composite")
	var patterns = UI_ManageNeuronMorphology.GetReferenceByID("Patterns")
	var patterns_bar = UI_ManageNeuronMorphology.GetReferenceByID("PatternRow0")
	var vectors_bar = UI_ManageNeuronMorphology.GetReferenceByID("XYZ")
	var add_button = UI_ManageNeuronMorphology.GetReferenceByID("header_definition").get_node("sideButton_header_definition")
	patterns_bar.visible = false
	vectors.visible = false
	composite.visible = false
	patterns.visible = false
	vectors_bar.visible = false
#	UI_ManageNeuronMorphology.GetReferenceByID("button1").get_node("button_button1").visible = false
	add_button.connect("pressed", Callable($Brain_Visualizer,"_morphology_button_inside_red").bind(UI_ManageNeuronMorphology))
	save_button.connect("pressed", Callable($Brain_Visualizer,"_morphology_button_inside_red").bind(UI_ManageNeuronMorphology))
	UI_ManageNeuronMorphology.SetData({"box_one": {"box_three": {"Composite": {"MAPPING_DROPDOWN": {"MAPPINGDROPDOWN": {"options": optionbutton_holder}}}}}})
	
#	var node_button_box = UI_ManageNeuronMorphology.GetReferenceByID("button1")
#	var parent_of_button = UI_ManageNeuronMorphology.GetReferenceByID("morphology_list")
#	var duplicated_button_box = node_button_box.duplicate()
#	var duplicated_button = node_button_box.duplicate()
#	node_button_box.visible = false 
#	duplicated_button.visible = true
#	duplicated_button_box.add_child(duplicated_button)
#	parent_of_button.add_child(duplicated_button_box)
#	if optionbutton_holder:
#		for i in optionbutton_holder:
#			var new_node = duplicated_button.duplicate()
#			new_node.get_node("button_button1").visible = true
#			new_node.get_node("button_button1").text = i
#			new_node.set_name("button1" + str(i))
#			new_node.get_node("button_button1").connect("pressed", Callable(self,"button_rule").bind(new_node.get_node("button_button1").text))
#			UI_ManageNeuronMorphology.GetReferenceByID("morphology_list").add_child(new_node)


	var node_button_box = UI_ManageNeuronMorphology.GetReferenceByID("button1")
	var parent_of_button = UI_ManageNeuronMorphology.GetReferenceByID("morphology_list")
	var duplicated_button_box = node_button_box.duplicate()
	var duplicated_button = node_button_box.duplicate()
	duplicated_button_box.add_child(duplicated_button)
	parent_of_button.add_child(duplicated_button_box)
	if optionbutton_holder:
		for i in optionbutton_holder:
			var new_node = UI_ManageNeuronMorphology.GetReferenceByID("button1").get_node("button_button1").duplicate()
#			new_node.visible = true
			new_node.text = i
			new_node.set_name("button1" + str(i))
			new_node.connect("pressed", Callable(self,"button_rule").bind(new_node.text))
			UI_ManageNeuronMorphology.GetReferenceByID("button1").add_child(new_node)

func button_rule(rule_name):
	if rule_name != " ":
		if "+" in rule_name:
			rule_name = rule_name.replace("+", "%2B")
		if "[" in rule_name:
			rule_name = rule_name.replace("[", "%5B")
		if "]" in rule_name:
			rule_name = rule_name.replace("]", "%5D")
		if ", " in rule_name:
			rule_name = rule_name.replace(", ", "%2C%20")
		$"..".Get_Morphology_information(rule_name)
		$"..".GET_USUAGE_MORPHOLOGY(rule_name)
		UI_ManageNeuronMorphology.GetReferenceByID("header_title").get_node("field_header_title").text = rule_name


func SpawnMappingDefinition(src, dst, activation):
	if is_instance_valid(UI_MappingDefinition):
		UI_MappingDefinition.queue_free()
		$Brain_Visualizer.plus_node.clear()
	UI_MappingDefinition = Newnit_Box.new()
	add_child(UI_MappingDefinition)
	UI_MappingDefinition.Activate(activation)
	UI_holders.append(UI_MappingDefinition)
	$"..".Update_CortinalAreasIDs()
	$"..".Update_MorphologyList()
	var get_id_from_dst = $Brain_Visualizer.name_to_id(dst)
	src_global = $Brain_Visualizer.name_to_id(src)
	dst_global = get_id_from_dst
	var combine_url = '#&dst_cortical_area=$'.replace("#", src_global)
	combine_url= combine_url.replace("$", get_id_from_dst)
	Autoload_variable.BV_Core.Update_destination(combine_url)
	# Link with BV buttons
	var add_morphology = UI_MappingDefinition.GetReferenceByID("ADDMAPPING").get_node("button_ADDMAPPING")
	var update_button = UI_MappingDefinition.GetReferenceByID("updatebutton").get_node("button_updatebutton")
	add_morphology.connect("pressed", Callable($Brain_Visualizer,"_on_plus_add_pressed"))
	update_button.connect("pressed", Callable($Brain_Visualizer,"_on_update_inside_map_pressed").bind(UI_MappingDefinition))

# proxys for properties
var _currentLanguageISO: String 
