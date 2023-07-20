extends Object
class_name WindowManager

var UIMan: UI_Manager
var MappingDefinition: Window_MappingDefinition
var currentLanguageISO: StringName


func _init(UIManager: UI_Manager, languageCode: StringName):
	
	UIMan = UIManager
	currentLanguageISO = languageCode
	# Prep Mapping Definition
	
	MappingDefinition = Window_MappingDefinition.new("Newnit_Popup", HelperFuncs.GenerateDefinedUnitDict("MAPPING_DEFINITION", currentLanguageISO), UIMan)

