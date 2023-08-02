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
var Windows: WindowManager


var UI_Top_TopBar: Newnit_Box
var UI_BUTTON: Newnit_Box
var UI_LeftBar: Newnit_Popup
var UI_CreateCorticalBar : Newnit_Popup
var UI_ManageNeuronMorphology : Newnit_Popup
var UI_morphologyLIST : Newnit_Popup
var UI_CORTICALLIST : Newnit_Popup
var UI_MappingDefinition : Newnit_Popup
var UI_CircuitImport : Newnit_Popup
var UI_QUICKCONNECT: Newnit_Popup

var UI_CreateMorphology: Newnit_Popup
var UI_TUTORIAL_DIALOGUE: Newnit_Popup
var UI_TUTORIAL: Newnit_Popup
var UI_INDICATOR: Newnit_Box
var vectors_holder := []
var src_global 
var dst_global
var import_close_button
var UI_holders := []
var global_json_data # TODO replace dependent with Newnit library system
var optionbutton_holder
var morphology_creation_add_button
var name_selected_morphology = ""
var tutorial_holder = []
var current_image = 0

# Internal cached vars
var _sideBarChangedValues := {}





####################################
############### Vars ###############
####################################

var CoreRef: Core
var UI_GraphCore: GraphCore



####################################
##### Required Initialization ######
####################################


func _ready():

	CoreRef = get_parent()
	_initGraphCore()



func _initGraphCore() -> void:
	UI_GraphCore = $graphCore
	UI_GraphCore.CortexSelected.connect(CortexSelected)
	UI_GraphCore.ConnectionRequest.connect(RequestConnection)
	UI_GraphCore.ConnectionSelected.connect(EditConnection)
	UI_GraphCore.DisconnectionRequest.connect(RequestConnectionDeletion)


####################################
####### Input Event Handling #######
####################################


func CortexSelected(cortex: CortexID) -> void:
	CoreRef.FEAGICalls.GET_GE_corticalArea(cortex.ID)
	$Brain_Visualizer.update_cortical_map_name(cortex.ID)
	#TODO switch to WM
	SpawnLeftBar(cortex.ID)

func RequestConnection(source: CortexID, destination: CortexID) -> void:
	#TODO switch to WM
	var mappingdefinitiongenerated = HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO)
	#SpawnMappingDefinition(source.ID, destination.ID, mappingdefinitiongenerated)	# TODO change from friendly name to ID with BV update
	SpawnMappingDefinition(FeagiCache.corticalAreas.ID2Name(source), FeagiCache.corticalAreas.ID2Name(destination), mappingdefinitiongenerated)

func EditConnection(source: CortexID, destination: CortexID) -> void:
	#TODO switch to WM
	var mappingdefinitiongenerated = HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO)
	#SpawnMappingDefinition(source.ID, destination.ID, mappingdefinitiongenerated)	# TODO change from friendly name to ID with BV update
	SpawnMappingDefinition(FeagiCache.corticalAreas.ID2Name(source), FeagiCache.corticalAreas.ID2Name(destination), mappingdefinitiongenerated)

func RequestConnectionDeletion(source: CortexID, destination: CortexID) -> void:
	CoreRef.FEAGICalls.PUT_GE_mappingProperties_T(source.ID, destination.ID, [])



####################################
###### Output Event Handling #######
####################################

# Tells ui to delete a cortical area from view (and any connections to / from it)
func DeleteCortex(cortex: CortexID) -> void:
	UI_GraphCore.RemoveCorticalNode(cortex)









### Below is old and needs redoing. Pushing down to remember what was worked on

#####################################
# Initialization

func Activate(langISO: String):
	# Initialize Vars
	currentLanguageISO = langISO #TODO Better language handling
	# Initialize UI
	Windows = WindowManager.new(self, currentLanguageISO)
	
	
	# Initialize TopBar
	var topBarDict = HelperFuncs.GenerateDefinedUnitDict("TOP_BAR", currentLanguageISO)
	_SpawnTopBar(topBarDict)
	
	# Write to global_json_data
	var files = FileAccess.open("res://brain_visualizer_source/type_option.json", FileAccess.READ)
	var test_json_conv = JSON.new()
	test_json_conv.parse(files.get_as_text())
	global_json_data = test_json_conv.get_data()
	files.close()


	
	# Connect window size change function
	get_tree().get_root().size_changed.connect(WindowSizedChanged)
	WindowSizedChanged()
	
	Activated = true
	focus_entered.connect(FocusControl)

func _SpawnTopBar(activation: Dictionary):
	UI_Top_TopBar = Newnit_Box.new()
	add_child(UI_Top_TopBar)
	UI_Top_TopBar.Activate(activation)
	UI_Top_TopBar.DataUp.connect(TopBarInput)
	# TODO best not to connect to Element children, better to connect to element signals itself
	# https://media.tenor.com/pb0kIF-blqsAAAAC/minion-typing.gif
	var import_circuit = UI_Top_TopBar.GetReferenceByID("IMPORT_NEURONAL_CIRCUIT_TEXTUREBUTTON").get_node("textureButton_IMPORT_NEURONAL_CIRCUIT_TEXTUREBUTTON")
	import_circuit.connect("pressed", Callable($Brain_Visualizer,"_on_import_pressed"))


####################################
####### Input Event Handling #######
####################################

signal DataUp(data: Dictionary)



######### Top Bar Control ##########
# We should be using this to make things more streamline
func TopBarInput(data: Dictionary, ElementID: StringName, _ElementRef: Node):
	print("data: ", data, "elementid: ", ElementID)
	match(ElementID):
		"tutorial_button":
			if not UI_TUTORIAL: SpawnTUTORIAL()
		"CB_AND_BV_BUTTON":
			var get_name = UI_Top_TopBar.GetReferenceByID("CBANDBV").text
			print(get_name)
			if get_name == "Circuit builder":
				$graphCore.visible = true
				$Brain_Visualizer.visible = false
				UI_Top_TopBar.SetData({"CBANDBV":{"text": "Brain Visualizer"}})
				UI_Top_TopBar.GetReferenceByID("CB_AND_BV_BUTTON").LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/BV.png")
			elif get_name == "Brain Visualizer":
				$graphCore.visible = false
				$Brain_Visualizer.visible = true
				UI_Top_TopBar.SetData({"CBANDBV":{"text": "Circuit builder"}})
				UI_Top_TopBar.GetReferenceByID("CB_AND_BV_BUTTON").LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/CB.png")

		# Lets keep this in order from Left to Right
		# REFRESH_RATE_BOX
		"REFRESH_RATE_FLOATFIELD":
			DataUp.emit({"updatedBurstRate": 1/data["value"]})
		
		# NEURONAL_CIRCUITS_BOX
		"IMPORT_NEURONAL_CIRCUIT_TEXTUREBUTTON":
			pass
		
		# CORTICAL_AREAS_BOX
		"LIST_CORTICAL_AREAS_TEXTURE_BUTTON":
			if not UI_CORTICALLIST:
				UI_CORTICALLIST = Newnit_Popup.new()
				var corticallistDICT = HelperFuncs.GenerateDefinedUnitDict("CORTICALLISTONLY", currentLanguageISO)
				add_child(UI_CORTICALLIST)
				UI_CORTICALLIST.Activate(corticallistDICT)
				UI_holders.append(UI_CORTICALLIST)
			
				# Copy n paste cus no reason to do extra work
				const ButtonItem := { "type": "button", "ID": "morphologyOption", "alignment": 0}
				var corticaloption = FeagiCache.corticalAreas.GE_corticalMap
				var corticalScroll: Newnit_Scroll = UI_CORTICALLIST.GetReferenceByID("cortical_list")
				for i in corticaloption:
					var spawnedItem = corticalScroll.SpawnItem(ButtonItem, {"fullText": $Brain_Visualizer.id_to_name(i)})
					spawnedItem.connect("DataUp", Callable(self,"camera_focus"))
		"CREATE_CORTICAL_AREA_TEXTURE_BUTTON":
			if not UI_CreateCorticalBar: SpawnCorticalCreate() # Only spawn if not already up
		"QUICK_CONNECT_CORTICAL_AREAS_TEXTURE_BUTTON":
			if not UI_QUICKCONNECT: SpawnQuickConnect()
		
		# NEURON_MORPHOLOGIES_BOX
		"CREATE_NEURON_MORPHOLOGY_TEXTURE_BOX":
			if not UI_CreateMorphology: SpawnCreateMophology()
		"MANAGE_NEURON_MORPHOLOGIES": 
			if not UI_ManageNeuronMorphology: SpawnNeuronManager()

func CreateMorphologyInput(data: Dictionary, ElementID: String, _ElementRef: Node):
	print("data: ", data, " elementid: ", ElementID, " ElementRef: ", _ElementRef)
	var composite = UI_CreateMorphology.GetReferenceByID("Composite")
	var patterns = UI_CreateMorphology.GetReferenceByID("Patterns")
	var vectors = UI_CreateMorphology.GetReferenceByID("Vectors")
	match(ElementID):
		"MorphologyType":
		#Drop down is changed, toggle between available morphology wizards
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
		"RPATTERNS", "RCOMPOSITE", "RVECTORS":
			for i in UI_CreateMorphology.GetReferenceByID("MorphologyType").get_children():
				if i.get_child(1).is_pressed():
					name_selected_morphology = i.get_name()
					name_selected_morphology = name_selected_morphology.replace("checkBox_R", "").capitalize()
			match(ElementID):
				"RCOMPOSITE":
					$Brain_Visualizer.new_morphology_clear()
					composite.visible = true; patterns.visible = false; vectors.visible = false; morphology_creation_add_button.visible = false
					UI_CreateMorphology.SetData({"Composite": {"MAPPING_DROPDOWN": {"MAPPINGDROPDOWN":{"options": optionbutton_holder}}}})
				"RPATTERNS":
					$Brain_Visualizer.new_morphology_clear()
					morphology_creation_add_button.emit_signal("pressed")
					composite.visible = false; patterns.visible = true; vectors.visible = false; morphology_creation_add_button.visible = true
				"RVECTORS":
					$Brain_Visualizer.new_morphology_clear()
					composite.visible = false; patterns.visible = false; vectors.visible = true; morphology_creation_add_button.visible = true
					morphology_creation_add_button.emit_signal("pressed")

func TUTORIALINPUT(data: Dictionary, ElementID: String, _ElementRef: Node):
	print("data: ", data, " elementid: ", ElementID, " ElementRef: ", _ElementRef)
	match(ElementID):
		"t2.png":
			SpawnTUTORIALdialogue()
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("TUTORIAL_IMAGE").LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/" + str(ElementID))
			for i in range(len(tutorial_holder)):
				if ElementID == tutorial_holder[i]:
					current_image = i
			if current_image == len(tutorial_holder)-1:
				UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = true
			else:
				UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = false
			if current_image == 0:
				UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = true
			else:
				UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = false

func TUTORIALDIA_INPUT(data: Dictionary, ElementID: String, _ElementRef: Node):
	if "value" in data.keys():
		if current_image - 1 >= 0:
			current_image -= 1
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("TUTORIAL_IMAGE").LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/" + tutorial_holder[current_image])
		if current_image == 0:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = true
		else:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = false
		if current_image == len(tutorial_holder)-1:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").text = "FINISHED"
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = true
		else:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").text = "NEXT"
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = false
	if "sideButton" in data.keys():
		if current_image + 1 <= len(tutorial_holder)-1:
			current_image += 1
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("TUTORIAL_IMAGE").LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/" + tutorial_holder[current_image])
		if current_image == len(tutorial_holder)-1:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").text = "FINISHED"
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = true
		else:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").text = "NEXT"
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("sideButton_BUTTONS").disabled = false
		if current_image == 0:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = true
		else:
			UI_TUTORIAL_DIALOGUE.GetReferenceByID("BUTTONS").get_node("button_BUTTONS").disabled = false
	######### Side Bar Control #########

func LeftBarInput(data: Dictionary, _compRef, _unitRef):
#	print(JSON.stringify(data)) # useful for debugging
#	print("data: ", data, " compref: ", _compRef, " unitref: ", _unitRef)
	match(data["ID"]):
		"UpdateButton":
			# Push update to cortex
			# only push stuff that do not match what is cached
#			_sideBarChangedValues["cortical_id"] = UI_LeftBar.data["CorticalName"]
			$"..".Update_Genome_CorticalArea(_sideBarChangedValues)
			_sideBarChangedValues = {} # reset
		_: # ????
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
	
func QuickConnectINPUT(_data: Dictionary, ElementID: StringName, _ElementRef: Node):
	match(ElementID):
		"SRC_CORTICAL":
			$Brain_Visualizer.glow_reset()
			var button = UI_QUICKCONNECT.GetReferenceByID("SRC_CORTICAL").get_node("button_SRC_CORTICAL")
			button.text = "Click any cortical"
		"ARROW":
			if UI_morphologyLIST:
				if UI_morphologyLIST != null:
					UI_morphologyLIST.queue_free()
			UI_morphologyLIST = Newnit_Popup.new()
			var morphologylistDICT = HelperFuncs.GenerateDefinedUnitDict("MORPHOLOGYLISTONLY", currentLanguageISO)
			add_child(UI_morphologyLIST)
			UI_morphologyLIST.Activate(morphologylistDICT)
			UI_holders.append(UI_morphologyLIST)
			const ButtonItem := { "type": "texturebutton", 
				"ID": "morphologyOption",
				"internal_custom_minimum_size": Vector2(200,200)}
			var morphologyOptions: Array = ["projector", "block_to_block", "any_to_any", "lateral_+x", "lateral_+y", "lateral_-y"]
			var morphologyScroll: Newnit_Scroll = UI_morphologyLIST.GetReferenceByID("morphology_list")
			for i in morphologyOptions:
				var spawnedItem = morphologyScroll.SpawnItem(ButtonItem)
				spawnedItem.get_node("textureButton_morphologyOption").connect("pressed", Callable(self, "arrow_name_updater").bind(i))
				spawnedItem.LoadTextureFromPath("res://brain_visualizer_source/menu_assets/image/" + str(i) + ".png")
		"DESTINATION":
			$Brain_Visualizer.destination_reset()
			var button = UI_QUICKCONNECT.GetReferenceByID("DESTINATION").get_node("button_DESTINATION")
			button.text = "Click any cortical"
		"CONNECT":
			var src = UI_QUICKCONNECT.GetReferenceByID("SRC_CORTICAL").get_node("button_SRC_CORTICAL").text
			var morphology_name = UI_QUICKCONNECT.GetReferenceByID("ARROW").get_node("button_ARROW").text
			var dest = UI_QUICKCONNECT.GetReferenceByID("DESTINATION").get_node("button_DESTINATION").text
			$Brain_Visualizer.quick_connect_to_feagi(src, morphology_name, dest)
			$Brain_Visualizer.glow_reset()
			$Brain_Visualizer.destination_reset()
		"POPUP_TOPBAR":
			$Brain_Visualizer.glow_reset()
			$Brain_Visualizer.destination_reset()
func CorticalCreateInput(data: Dictionary, ElementID: StringName, _ElementRef: Node):
	print("data: ", data, "elementid: ", ElementID)
	match(ElementID):
		"UpdateButton":
			UI_CreateCorticalBar.queue_free()
		"CORTICALAREAFIELD":
				var box = UI_CreateCorticalBar.GetReferenceByID("XYZ")
				var boxx = UI_CreateCorticalBar.GetReferenceByID("WHD")
				var update = UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton")
				if data["value"] == "":
					if box.visible:
						update.disabled = true
						box.visible = false
				else:
					if not box.visible:
						update.disabled = false
						box.visible = true
				if data["value"] == "":
					if boxx.visible:
						boxx.visible = false
				else:
					if not boxx.visible:
						boxx.visible = true
		"OPU":
			UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton").disabled = false
			UI_CreateCorticalBar.GetReferenceByID("corticalnamedrop").visible = true
			UI_CreateCorticalBar.GetReferenceByID("OPUIPU").visible = true
			UI_CreateCorticalBar.GetReferenceByID("corticalnametext").visible = false
			UI_CreateCorticalBar.GetReferenceByID("XYZ").visible = true
			UI_CreateCorticalBar.GetReferenceByID("WHD").visible = true
			$"..".FEAGICalls.GET_GE_corticalTypeOptions('OPU')
		"IPU":
			UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton").disabled = false
			UI_CreateCorticalBar.GetReferenceByID("corticalnamedrop").visible = true
			UI_CreateCorticalBar.GetReferenceByID("OPUIPU").visible = true 
			UI_CreateCorticalBar.GetReferenceByID("corticalnametext").visible = false
			UI_CreateCorticalBar.GetReferenceByID("XYZ").visible = true
			UI_CreateCorticalBar.GetReferenceByID("WHD").visible = true
			$"..".FEAGICalls.GET_GE_corticalTypeOptions('IPU')
		"CUSTOM":
			UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton").disabled = true
			UI_CreateCorticalBar.GetReferenceByID("corticalnamedrop").visible = false
			UI_CreateCorticalBar.GetReferenceByID("corticalnametext").visible = true
			UI_CreateCorticalBar.GetReferenceByID("OPUIPU").visible = false
			UI_CreateCorticalBar.GetReferenceByID("XYZ").visible = false
			UI_CreateCorticalBar.GetReferenceByID("WHD").visible = false
		"POPUP_TOPBAR":
			$Brain_Visualizer._clear_single_cortical("example", Godot_list.godot_list)

############ Graph Edit ############

# Takes input from GraphEdit
#func GraphEditInput(data: Dictionary):
#	
#	if "CortexSelected" in data.keys():
#		# Cortex has been selected, pop up side bar
#		SpawnLeftBar(data["CortexSelected"])
#		DataUp.emit(data)
#	
#	# Redo this TODO
#	if "event" in data.keys():
#		var mappingdefinitiongenerated = HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO)
#		SpawnMappingDefinition(data["source"], data["destination"], mappingdefinitiongenerated)	
#	
#	pass

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
			if UI_MappingDefinition:
				var updated_list = []
				for i in data:
					updated_list.append($Brain_Visualizer.id_to_name(i))
				UI_MappingDefinition.SetData({"testlabel": {"SOURCECORTICALAREA":{"options": updated_list, "value": $Brain_Visualizer.id_to_name(src_global)}}})
				UI_MappingDefinition.SetData({"testlabel": {"DESTINATIONCORTICALAREA":{"options": updated_list, "value": $Brain_Visualizer.id_to_name(dst_global)}}})
		REF.FROM.genome_morphologyList:
#			if UI_Top_TopBar:
#				UI_Top_TopBar.SetData({"NEURONMORPHOLOGIESBOX": {"NEURONMORPHOLOGIES": {"options":data}}})
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
#		REF.FROM.genome_fileName:
#			UI_Top_TopBar.SetData({"GENOMEFILENAME": {"sideLabelText":data}})
#		REF.FROM.connectome_properties_mappings:
#			pass
		REF.FROM.OPULIST:
			if UI_CreateCorticalBar:
				UI_CreateCorticalBar.SetData({"corticalnamedrop": {"CORTICALAREADROPDOWNINBOX": {"options": data}}})
		REF.FROM.IPULIST:
			if UI_CreateCorticalBar:
				UI_CreateCorticalBar.SetData({"corticalnamedrop": {"CORTICALAREADROPDOWNINBOX": {"options": data}}})
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
				"CorticalPropertiesSection": {"CorticalName": {"value": data["cortical_name"]},
				"CorticalID": {"value": data["cortical_id"]},
				"CorticalArea": {"value": data["cortical_group"]},
				"XYZ": {"Pos_X": {"value": int(data["cortical_coordinates"][0])}, "Pos_Y": {"value": int(data["cortical_coordinates"][1])}, "Pos_Z": {"value": int(data["cortical_coordinates"][2])}},
				"WHD": {"W": {"value": int(data["cortical_dimensions"][0])}, "H": {"value": int(data["cortical_dimensions"][1])}, "D": {"value": int(data["cortical_dimensions"][2])}}}
			}
#			#print(inputVars)
			UI_LeftBar.SetData({"NeuronParametersSection": inputVars} )
			UI_LeftBar.SetData(cortical_properties)
			$"..".FEAGICalls.GET_GE_corticalMappings_afferents_corticalArea(data["cortical_id"])
		REF.FROM.burstEngine:
			UI_Top_TopBar.SetData({"REFRESH_RATE_BOX": {"REFRESH_RATE_FLOATFIELD": {"value": 1/data}}})
	pass


####################################
############# Internals ############
####################################

func FocusControl():
	print("Background now focused!")
	grab_focus()
	

func SpawnTUTORIAL():
	if UI_TUTORIAL != null:
		UI_TUTORIAL.queue_free() # We don't need this. We need to make it look prettier
	UI_TUTORIAL = Newnit_Popup.new()
	var TUTORIALDICT = HelperFuncs.GenerateDefinedUnitDict("TUTORIAL", currentLanguageISO)
	UI_TUTORIAL.DataUp.connect(TUTORIALINPUT)
	add_child(UI_TUTORIAL)
	UI_TUTORIAL.Activate(TUTORIALDICT)
	UI_holders.append(UI_TUTORIAL)
	var testbox = []
	for i in range(1, 10):
		testbox.append("t" + str(i+1) + ".png")
	for i in testbox:
		tutorial_holder.append(i)

#	print("tutorial: ", tutorial_holder) # WORST approach ever in history but it was urgent so....
#	for i in UI_TUTORIAL.get_children():
#		if "_box" in i.get_name():
#			for x in i.get_children():
#				print("x.ID: ", x.ID)
#				tutorial_holder.append(x.ID)

	
	
func SpawnTUTORIALdialogue():
	if UI_TUTORIAL_DIALOGUE != null:
		UI_TUTORIAL_DIALOGUE.queue_free() # We don't need this. We need to make it look prettier
	UI_TUTORIAL_DIALOGUE = Newnit_Popup.new()
	var TUTORIALDICT_dialogue = HelperFuncs.GenerateDefinedUnitDict("DIALOGUE", currentLanguageISO)
	UI_TUTORIAL_DIALOGUE.DataUp.connect(TUTORIALDIA_INPUT)
	add_child(UI_TUTORIAL_DIALOGUE)
	UI_TUTORIAL_DIALOGUE.Activate(TUTORIALDICT_dialogue)
	UI_holders.append(UI_TUTORIAL_DIALOGUE)


func SpawnLeftBar(cortexName: String):
	if UI_LeftBar != null:
		UI_LeftBar.queue_free() # We don't need this. We need to make it look prettier
	$"..".FEAGICalls.GET_GE_corticalArea(cortexName) # Tell core to update cortex Info
	UI_LeftBar = Newnit_Popup.new()
	add_child(UI_LeftBar)
	var activation = HelperFuncs.GenerateDefinedUnitDict("LEFTBAR", "eng")
	UI_LeftBar.Activate(activation)
	UI_holders.append(UI_LeftBar)

	# Please do not get_children on nodes due to panel abstraction
	var delete_button = UI_LeftBar.GetReferenceByID("UpdateButtonTop").get_node("sideButton_UpdateButtonTop")
	var update1 = UI_LeftBar.GetReferenceByID("UpdateButtonTop").get_node("button_UpdateButtonTop")
	var update=UI_LeftBar.GetReferenceByID("NeuronParametersSection").GetReferenceByID("UpdateButton").get_node("button_UpdateButton")
	var mem_button = UI_LeftBar.GetReferenceByID("Mem_potent").get_node("checkButton_Mem_potent")
	var syn_button = UI_LeftBar.GetReferenceByID("syn_potent").get_node("checkButton_syn_potent")
	var add_row_button = UI_LeftBar.GetReferenceByID("EFFERENTLABEL").get_node("sideButton_EFFERENTLABEL")
	delete_button.connect("pressed", Callable($Brain_Visualizer,"_on_remove_pressed").bind(UI_LeftBar.GetReferenceByID("CorticalID")))
	update.connect("pressed", Callable($Brain_Visualizer,"_on_Update_pressed").bind(UI_LeftBar))
	update1.connect("pressed", Callable($Brain_Visualizer,"_on_Update_pressed").bind(UI_LeftBar))
	add_row_button.connect("pressed", Callable($Brain_Visualizer,"_on_cortical_mapping_add_pressed").bind(cortexName))
	mem_button.connect("pressed", Callable($Brain_Visualizer,"_on_mem_pressed"))
	syn_button.connect("pressed", Callable($Brain_Visualizer,"_on_syn_pressed"))

func mapping_definition_button(node):
	var src_id = UI_LeftBar.GetReferenceByID("CorticalName").get_node("field_CorticalName").text
	var mappingdefinitiongenerated = HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO)
	SpawnMappingDefinition(src_id, node.text, mappingdefinitiongenerated)

func SpawnCreateMophology():
	var CMDict = HelperFuncs.GenerateDefinedUnitDict("CREATEMORPHOLOGY", currentLanguageISO)
	UI_CreateMorphology = Newnit_Popup.new()
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
	$"..".FEAGICalls.GET_GE_morphologyList()
	UI_CreateMorphology.DataUp.connect(CreateMorphologyInput)
	UI_holders.append(UI_CreateMorphology)
	morphology_creation_add_button = add_row
	morphology_creation_add_button.connect("pressed", Callable($Brain_Visualizer,"_morphology_button_pressed").bind(UI_CreateMorphology))
	create_button.connect("pressed", Callable($Brain_Visualizer,"_on_create_pressed").bind(UI_CreateMorphology))
	

func SpawnCorticalCreate():
	UI_CreateCorticalBar = Newnit_Popup.new()
	var createcorticalBar = HelperFuncs.GenerateDefinedUnitDict("CORTICAL_CREATE", currentLanguageISO)
	add_child(UI_CreateCorticalBar)
	UI_CreateCorticalBar.Activate(createcorticalBar)
	UI_CreateCorticalBar.DataUp.connect(CorticalCreateInput)
	UI_holders.append(UI_CreateCorticalBar)
	UI_CreateCorticalBar.GetReferenceByID("corticalnamedrop").visible = false
	UI_CreateCorticalBar.GetReferenceByID("OPUIPU").visible = false
	UI_CreateCorticalBar.GetReferenceByID("corticalnametext").visible = false
	UI_CreateCorticalBar.GetReferenceByID("XYZ").visible = false
	UI_CreateCorticalBar.GetReferenceByID("WHD").visible = false
	UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton").disabled = true
	var update = UI_CreateCorticalBar.GetReferenceByID("UpdateButton").get_node("button_UpdateButton")
	var whd = UI_CreateCorticalBar.GetReferenceByID("WHD")
	var xyz = UI_CreateCorticalBar.GetReferenceByID("XYZ")
	var name_input = UI_CreateCorticalBar.GetReferenceByID("corticalnametext").get_node("field_CORTICALAREAFIELD").get_node("field_CORTICALAREAFIELD")
	var checkbutton_node = UI_CreateCorticalBar.GetReferenceByID("CORTICALAREA")
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
	name_input.connect("text_changed", Callable($Brain_Visualizer,"_on_type_text_changed"))
	name_input.connect("text_changed",Callable($"../../Button_to_Autoload","_on_type_text_changed"))
	update.connect("pressed",Callable($Brain_Visualizer,"_on_add_pressed").bind([w,h,d,x,y,z, name_input, checkbutton_node, update]))

func SpawnIndicator(activation: Dictionary):
	UI_INDICATOR = Newnit_Box.new()
	add_child(UI_INDICATOR)
	UI_INDICATOR.Activate(activation)
	UI_holders.append(UI_INDICATOR)


func SpawnCircuitImport(activation: Dictionary):
	UI_CircuitImport = Newnit_Popup.new()
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
	$"..".FEAGICalls.GET_GE_morphologyList() # Renew morphology list
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
	var delete_button = UI_ManageNeuronMorphology.GetReferenceByID("SAVEDELETE").get_node("sideButton_SAVEDELETE")
	patterns_bar.visible = false
	vectors.visible = false
	composite.visible = false
	patterns.visible = false
	vectors_bar.visible = false
	add_button.connect("pressed", Callable($Brain_Visualizer,"_morphology_button_inside_red").bind(UI_ManageNeuronMorphology))
	save_button.connect("pressed", Callable($Brain_Visualizer,"_on_save_pressed").bind(UI_ManageNeuronMorphology))
	delete_button.connect("pressed", Callable($Brain_Visualizer,"_on_delete_pressed").bind(UI_ManageNeuronMorphology))
	print("TEST: ", optionbutton_holder)
	UI_ManageNeuronMorphology.SetData({"box_one": {"box_three": {"Composite": {"MAPPING_DROPDOWN": {"MAPPINGDROPDOWN": {"options": optionbutton_holder}}}}}})
	
	const ButtonItem := { "type": "button", "ID": "morphologyOption"}
	var morphologyOptions: Array = FeagiCache.morphologies.morphologiesStrArray
	var morphologyScroll: Newnit_Scroll = UI_ManageNeuronMorphology.GetReferenceByID("morphology_list")
	for i in morphologyOptions:
		var spawnedItem = morphologyScroll.SpawnItem(ButtonItem, {"text": i})
		spawnedItem.connect("DataUp", Callable(self,"button_rule"))
	

func button_rule(_data: Dictionary, _originatingID: StringName, originatingRef: Node):
	var rule_name = originatingRef.text
	var path_string = "res://brain_visualizer_source/menu_assets/image/" + str(rule_name) + ".png"
	UI_ManageNeuronMorphology.SetData({"box_one": {"MISCMORPRHOLOGYLIST": {"MORPHOLOGY_PICTURE": {"default_texture_path": path_string}}}})
	if rule_name != " ":
		if "+" in rule_name:
			rule_name = rule_name.replace("+", "%2B")
		if "[" in rule_name:
			rule_name = rule_name.replace("[", "%5B")
		if "]" in rule_name:
			rule_name = rule_name.replace("]", "%5D")
		if ", " in rule_name:
			rule_name = rule_name.replace(", ", "%2C%20")
		$"..".FEAGICalls.GET_GE_morphology(rule_name)
		$"..".FEAGICalls.GET_GE_morphologyUsage(rule_name)
		UI_ManageNeuronMorphology.GetReferenceByID("header_title").get_node("field_header_title").text = rule_name

func arrow_name_updater(data):
	UI_QUICKCONNECT.GetReferenceByID("ARROW").get_node("button_ARROW").text = data
	UI_morphologyLIST.queue_free()
func camera_focus(_data: Dictionary, _originatingID: StringName, originatingRef: Node):
	$Brain_Visualizer.camera_list_selected($Brain_Visualizer.name_to_id(originatingRef.text))
	UI_CORTICALLIST.queue_free()

func SpawnQuickConnect():
	var quickconnectdict = HelperFuncs.GenerateDefinedUnitDict("QUICKCONNECT", currentLanguageISO)
	UI_QUICKCONNECT = Newnit_Popup.new()
	add_child(UI_QUICKCONNECT)
	UI_QUICKCONNECT.Activate(quickconnectdict)
	UI_holders.append(UI_QUICKCONNECT)
	UI_QUICKCONNECT.DataUp.connect(QuickConnectINPUT)
	
	

func SpawnMappingDefinition(src: String, dst: String, activation):
	if is_instance_valid(UI_MappingDefinition):
		UI_MappingDefinition.queue_free()
		$Brain_Visualizer.plus_node.clear()
	UI_MappingDefinition = Newnit_Popup.new()
	add_child(UI_MappingDefinition)
	UI_MappingDefinition.Activate(activation)
	UI_holders.append(UI_MappingDefinition)
	$"..".FEAGICalls.GET_GE_corticalAreaIDList()
	$"..".FEAGICalls.GET_GE_morphologyList()
	var get_id_from_dst = $Brain_Visualizer.name_to_id(dst)
	src_global = $Brain_Visualizer.name_to_id(src)
	dst_global = get_id_from_dst
	Autoload_variable.BV_Core.FEAGICalls.GET_GE_mappingProperties(src_global, dst_global)
	# Link with BV buttons
	var add_morphology = UI_MappingDefinition.GetReferenceByID("ADDMAPPING").get_node("button_ADDMAPPING")
	var update_button = UI_MappingDefinition.GetReferenceByID("updatebutton").get_node("button_updatebutton")
	add_morphology.connect("pressed", Callable($Brain_Visualizer,"_on_plus_add_pressed"))
	update_button.connect("pressed", Callable($Brain_Visualizer,"_on_update_inside_map_pressed").bind(UI_MappingDefinition))
	
# proxys for properties
var _currentLanguageISO: String 


