extends Node2D

func _ready():
	pass # Replace with function body.

func _on_leak_mouse_entered():
	print("LEAK MOUSE CALLED")
	Godot_list.Node_2D_control = true

func _on_leak_Vtext_mouse_entered():
	print("LEAK VTEXT CALLED")
	Godot_list.Node_2D_control = true

func _on_count_spinbox_mouse_entered():
	print("SPINBOX MOUSE CALLED")
	Godot_list.Node_2D_control = true

func _on_count_spinbox_mouse_exited():
	print("SPINBOX MOUSE EXITED CALLED")
	Godot_list.Node_2D_control = false

func _on_type_text_changed(_new_text):
	print("type text CALLED")
	Godot_list.Node_2D_control = true

func _on_TextEdit_text_entered(_new_text):
	print("textedit TEXT ENTER CALLED")
	Godot_list.Node_2D_control = false
