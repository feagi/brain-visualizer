extends VBoxContainer
class_name LeftBarBottom

var _scroll_afferent: BaseScroll
var _scroll_efferent: BaseScroll

func _ready() -> void:
	_scroll_afferent = $Afferent
	_scroll_efferent = $Efferent

