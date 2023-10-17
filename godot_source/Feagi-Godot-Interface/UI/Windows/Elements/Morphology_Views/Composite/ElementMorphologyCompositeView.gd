extends VBoxContainer
class_name ElementMorphologyCompositeView



var composite_seed: Vector3i:
	get: return _seed.current_vector
	set(v): _seed.current_vector = v

var patternX: Vector2i:
	get: return _patternX.current_vector
	set(v): _patternX.current_vector = v

var patternY: Vector2i:
	get: return _patternY.current_vector
	set(v): _patternY.current_vector = v

var patternZ: Vector2i:
	get: return _patternZ.current_vector
	set(v): _patternZ.current_vector = v

var mapped_morphology: Morphology:
	get: return _mapped_morphology.get_selected_morphology()
	set(v): _mapped_morphology.set_selected_morphology(v)

var _seed: Vector3iField
var _patternX: Vector2iField
var _patternY: Vector2iField
var _patternZ: Vector2iField
var _mapped_morphology: MorphologyDropDown

func _ready() -> void:
	_seed = $Seed/Seed_Vector
	_patternX = $Patterns/X/X
	_patternY = $Patterns/Y/Y
	_patternZ = $Patterns/Z/Z
	_mapped_morphology = $mapper/MorphologyDropDown

## Return current UI view as a [CompositeMorphology] object
func get_as_composite_morphology(morphology_name: StringName, is_placeholder: bool = false) -> CompositeMorphology:
	var XYZ: Array[Vector2i] = [patternX, patternY, patternZ]
	return CompositeMorphology.new(morphology_name, is_placeholder, composite_seed, XYZ, mapped_morphology.name)

## Overwrite the current UI view with a [CompositeMorphology] object
func set_from_composite_morphology(composite: CompositeMorphology) -> void:
	composite_seed = composite.source_seed
	patternX = composite.source_pattern[0]
	patternY = composite.source_pattern[1]
	patternZ = composite.source_pattern[2]
	if composite.is_placeholder_data:
		# Placeholder data implies that the mapped morphology is invalid. set dropdown to blank
		_mapped_morphology.deselect_all()
		return
	_mapped_morphology.set_selected_morphology_by_name(composite.mapper_morphology_name)

## Defines if UI view is editable. NOTE: ONLY WORKS ON '_ready' OR AFTER A UI CLEAR
func set_editable(is_editable: bool) -> void:
	_seed.editable = is_editable
	_patternX.editable = is_editable
	_patternY.editable = is_editable
	_patternZ.editable = is_editable
	_mapped_morphology.disabled = !is_editable
	
