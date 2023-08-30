extends Node
class_name LeftBarBottomMappingPrefab

var _ID_Label: Label_Element
var _Delete_Button: TextureButton_Element

func _ready():
	_ID_Label = $Cortical_ID
	_Delete_Button = $Delete_Button
