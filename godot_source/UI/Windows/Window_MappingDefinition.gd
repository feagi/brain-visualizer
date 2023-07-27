extends WindowBase
class_name Window_MappingDefinition


var sourceCortexID: StringName:
	get: return newnit.data["testlabel"]["SOURCECORTICALAREA"]["value"]
	set(v): 
		# TODO check for validity
		newnit.SetData({"testlabel": {"SOURCECORTICALAREA":{"value": v}}})

var destinationCortexID: StringName:
	get: return newnit.data["testlabel"]["DESTINATIONCORTICALAREA"]["value"]
	set(v): 
		# TODO check for validity
		newnit.SetData({"testlabel": {"DESTINATIONCORTICALAREA":{"value": v}}})


func Open(activation: Dictionary = _NewnitActivation, srcCortexID: StringName = "", destCortexID: StringName = "") -> void:
	super()
	
	#newnit.GetReferenceByID("corticalnamedrop").visible = false
	#newnit.GetReferenceByID("OPUIPU").visible = false
	#newnit.GetReferenceByID("corticalnametext").visible = false
	#newnit.GetReferenceByID("XYZ").visible = false
	#newnit.GetReferenceByID("WHD").visible = false
	#newnit.GetReferenceByID("UpdateButton").get_node("button_UpdateButton").disabled = true # ??
	
	# BV integration, do l8r
#	w.connect("value_changed",Callable($Brain_Visualizer,"_on_W_Spinbox_value_changed").bind([w,h,d,x,y,z]))
#	h.connect("value_changed",Callable($Brain_Visualizer,"_on_H_Spinbox_value_changed").bind([w,h,d,x,y,z]))
#	d.connect("value_changed",Callable($Brain_Visualizer,"_on_D_Spinbox_value_changed").bind([w,h,d,x,y,z]))
#	x.connect("value_changed",Callable($Brain_Visualizer,"_on_X_SpinBox_value_changed").bind([w,h,d,x,y,z]))
#	y.connect("value_changed",Callable($Brain_Visualizer,"_on_Y_Spinbox_value_changed").bind([w,h,d,x,y,z]))
#	z.connect("value_changed",Callable($Brain_Visualizer,"_on_Z_Spinbox_value_changed").bind([w,h,d,x,y,z]))
#	name_input.connect("text_changed",Callable($"../../Button_to_Autoload","_on_type_text_changed"))
#	update.connect("pressed",Callable($Brain_Visualizer,"_on_add_pressed").bind([w,h,d,x,y,z, name_input, optionlist, update]))

func _DataFromNewnit(data: Dictionary):
	print(data)
	print("A")

func _ReturnNewnitType() -> Object:
	return Newnit_Popup.new()
