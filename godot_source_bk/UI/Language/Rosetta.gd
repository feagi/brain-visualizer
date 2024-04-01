extends Object
class_name Rosetta
## Language Translator and lookup

signal language_changed(new_ISO_code: StringName)

const JSON_DIRECTORY: StringName = "res://Feagi-Godot-Interface/UI/Language/JSON/"
const SEARCH_SPECIAL_CHARACTER_IDENTIFIER: StringName = "$"

var available_language_ISOs: PackedStringArray
var eng_json: Dictionary
var foreign_json: Dictionary
var current_language_ISO: StringName

func _init() -> void:
	available_language_ISOs = _get_available_languages_from_JSONs(JSON_DIRECTORY)
	eng_json = _load_language_dictionary_ISO("EN")

## Looks up a key in the current loaded language json, and replaces terms in the located entry according to the dictionary
func get_text(key: StringName, replacements: Dictionary = {}) -> StringName:
	if current_language_ISO != "EN":
		if key in foreign_json.keys():
			return _replace_texts_from_dictionary(foreign_json[key], replacements)
		push_warning("Unable to find translation for key %s for language %s! Falling back to English..." % key)
	
	if key in eng_json.keys():
		return _replace_texts_from_dictionary(eng_json[key], replacements)
	
	push_error("Unable to find translation for key %s in English! Falling back to returning the key..." % key)
	return key

## Sets current loaded language
func set_current_language(lang_ISO: StringName) -> void:
	if lang_ISO not in available_language_ISOs:
		push_error("Unable to find language %s! Ignoring language change request!" % lang_ISO)
		return
	
	current_language_ISO = lang_ISO
	language_changed.emit(lang_ISO)
	print("Set language to %s!" % lang_ISO)
	
	if lang_ISO == "EN":
		foreign_json = {}
		return
	
	foreign_json = _load_language_dictionary_ISO(lang_ISO)

func _load_language_dictionary_ISO(lang_ISO: StringName) -> Dictionary:
	if lang_ISO not in available_language_ISOs:
		push_error("Unable to find language ISO in the filesystem%s! Language dictionary set to blank!" % lang_ISO)
		return {}
	
	var file = FileAccess.open(JSON_DIRECTORY + lang_ISO + ".json", FileAccess.READ)
	var dict: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	return dict

func _get_available_languages_from_JSONs(directory: StringName) -> PackedStringArray:
	var file_list: PackedStringArray = DirAccess.get_files_at(directory)
	var output: PackedStringArray = []
	for file: StringName in file_list:
		output.append(file.left(-5))
	return output

func _replace_texts_from_dictionary(source: StringName, replacements: Dictionary) -> StringName:
	for replacement_target: String in replacements.keys():
		source = _replace_text(source, replacement_target, replacements[replacement_target])
	return source

func _replace_text(source: String, search_term: String, replacement: String) -> String:
	search_term = SEARCH_SPECIAL_CHARACTER_IDENTIFIER + search_term
	return source.replace(search_term, replacement)
