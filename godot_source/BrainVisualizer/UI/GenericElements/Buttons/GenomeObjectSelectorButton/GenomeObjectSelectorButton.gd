extends PanelContainerButton
class_name GenomeObjectSelectorButton

signal object_selected(object: GenomeObject)

const TEXTURE_CORTICAL_DEFAULT: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/top_bar_cortical_area.png")
const TEXTURE_INTERCONNECT: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/interconnected.png")
const TEXTURE_MEMORY: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/memory-game.png")
## System core areas (same assets as cortical icon pack / brain-monitor billboards).
const TEXTURE_CORE_POWER: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/_power.png")
const TEXTURE_CORE_DEATH: Texture2D = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/_death.png")

var current_selected: GenomeObject:
	get: return _current_selected

var _current_selected: GenomeObject
var _selection_allowed: GenomeObject.SINGLE_MAKEUP
var _explorer_start_region: BrainRegion
var _cortical_icon: TextureRect
var _region_icon: TextureRect
var _text: Label

func _ready() -> void:
	super()
	_cortical_icon = $MarginContainer/HBoxContainer/IconCortical
	_region_icon = $MarginContainer/HBoxContainer/IconRegion
	_text = $MarginContainer/HBoxContainer/Label

#NOTE: Yes you can init with a type not allowed for the user to select
func setup(genome_object: GenomeObject, restricted_to: GenomeObject.SINGLE_MAKEUP, custom_region_to_start_explorer_at: BrainRegion = null) -> void:
	_selection_allowed = restricted_to
	_current_selected = genome_object
	if custom_region_to_start_explorer_at != null:
		_explorer_start_region = custom_region_to_start_explorer_at
	else:
		_explorer_start_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	_switch_button_visuals(genome_object)
	pressed.connect(_button_pressed)

func update_selection_with_signal(genome_object: GenomeObject) -> void:
	if !GenomeObject.is_given_object_covered_by_makeup(genome_object, _selection_allowed):
		push_error("UI: Invalid GenomeObject type selected for button given restriction! Ignoring!")
		return
	update_selection_no_signal(genome_object)
	object_selected.emit(_current_selected)

func update_selection_no_signal(genome_object: GenomeObject) -> void:
	if !GenomeObject.is_given_object_covered_by_makeup(genome_object, _selection_allowed):
		push_error("UI: Invalid GenomeObject type selected for button given restriction! Ignoring!")
		return
	_current_selected = genome_object
	_switch_button_visuals(genome_object)

## Change at what region the explorer starts when the button is pressed
func change_starting_exploring_region(start_region: BrainRegion) -> void:
	_explorer_start_region = start_region

func _button_pressed() -> void:
	var config: SelectGenomeObjectSettings
	match(_selection_allowed):
		GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA:
			var current_area: AbstractCorticalArea = null
			if _current_selected is AbstractCorticalArea:
				current_area = _current_selected as AbstractCorticalArea
			config = SelectGenomeObjectSettings.config_for_single_cortical_area_selection(_explorer_start_region, current_area)
		
		GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION:
			var current_region: BrainRegion = null
			if _current_selected is BrainRegion:
				current_region = _current_selected as BrainRegion
			config = SelectGenomeObjectSettings.config_for_single_brain_region_selection(_explorer_start_region, current_region)
			
		_:
			config = SelectGenomeObjectSettings.config_for_selecting_anything(_explorer_start_region)
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	window.final_selection.connect(_update_selection)

func _switch_button_visuals(selected: GenomeObject) -> void:
	var type: GenomeObject.SINGLE_MAKEUP = GenomeObject.get_makeup_of_single_object(selected)
	_cortical_icon.visible = type == GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA
	_region_icon.visible = type == GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION
	if type == GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA and selected is AbstractCorticalArea:
		_apply_cortical_area_icon(selected as AbstractCorticalArea)
	elif type == GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA:
		_cortical_icon.texture = TEXTURE_CORTICAL_DEFAULT
	if type == GenomeObject.SINGLE_MAKEUP.UNKNOWN:
		_text.text = "None Selected"
	else:
		_text.text = selected.friendly_name
	_apply_cortical_name_label_style(type)


## Same [Label_Header] variation as cortical details section titles; default [Label] for regions / none.
func _apply_cortical_name_label_style(makeup: GenomeObject.SINGLE_MAKEUP) -> void:
	if _text == null:
		return
	if makeup == GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA:
		_text.theme_type_variation = &"Label_Header"
	else:
		_text.theme_type_variation = StringName()


## Icons match brain-monitor / create-area conventions: IPU/OPU use [UIManager.get_icon_texture_by_ID], interconnect uses the same asset as custom interconnect areas, memory uses the memory-game icon. Reserved cores (power/death/fatigue) use dedicated textures or [UIManager] lookup.
func _apply_cortical_area_icon(area: AbstractCorticalArea) -> void:
	if area is MemoryCorticalArea:
		_cortical_icon.texture = TEXTURE_MEMORY
		return
	if AbstractCorticalArea.is_power_area(area.cortical_ID):
		_cortical_icon.texture = TEXTURE_CORE_POWER
		return
	if AbstractCorticalArea.is_death_area(area.cortical_ID):
		_cortical_icon.texture = TEXTURE_CORE_DEATH
		return
	if AbstractCorticalArea.is_fatigue_area(area.cortical_ID):
		# No dedicated 2D fatigue asset in BV yet; [UIManager.get_icon_texture_by_ID] resolves per-ID or unknown-output.
		_cortical_icon.texture = UIManager.get_icon_texture_by_ID(area.cortical_ID, false) as Texture2D
		return
	match area.cortical_type:
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			_cortical_icon.texture = UIManager.get_icon_texture_by_ID(area.cortical_ID, true) as Texture2D
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			_cortical_icon.texture = UIManager.get_icon_texture_by_ID(area.cortical_ID, false) as Texture2D
		AbstractCorticalArea.CORTICAL_AREA_TYPE.INTERCONNECT, AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_cortical_icon.texture = TEXTURE_INTERCONNECT
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			_cortical_icon.texture = TEXTURE_MEMORY
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
			_cortical_icon.texture = UIManager.get_icon_texture_by_ID(area.cortical_ID, true) as Texture2D
		_:
			_cortical_icon.texture = TEXTURE_CORTICAL_DEFAULT

func _update_selection(genome_objects: Array[GenomeObject]) -> void:
	if len(genome_objects) == 0:
		return
	if len(genome_objects) > 1:
		push_error("UI: More than 1 genome object was somehow selected for the GenomeObjectSelectorButton! Using the first and discarding the rest!")
	update_selection_no_signal(genome_objects[0])
	object_selected.emit(_current_selected)
