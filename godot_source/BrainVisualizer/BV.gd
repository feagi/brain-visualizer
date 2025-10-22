extends Node
## Autoload used to easily get referneces to various things
#NOTE: The tree needs to be settled on launch before these references become valid
#TODO: We can optimize this, instead of having live getters, once we are stable, lets have private vars BV sets via function on ready, just make sure ui_manager if first (go in tre order)

## The root node of the scene tree
var BV: BrainVisualizer:
	get: return get_node("/root/BrainVisualizer") as BrainVisualizer

## The root node of the scene tree
var UI: UIManager:
	get: return get_node("/root/BrainVisualizer/UIManager") as UIManager

var NOTIF: NotificationSystem:
	get: return get_node("/root/BrainVisualizer/UIManager/NotificationSystem") as NotificationSystem

var WM: WindowManager:
	get: return get_node("/root/BrainVisualizer/UIManager/WindowManager") as WindowManager
