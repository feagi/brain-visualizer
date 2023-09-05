extends VBoxContainer

# needs to make use of signals of when cortical areas are added or removed (same with morpholopgies)

## Mappings (should be stored as a copy and not be an in-use reference since actions in here are destructive)
var cached_mappings_copy_ref: MappingProperties

var _mappings_scroll: BaseScroll

func _ready() -> void:
	_mappings_scroll = $Mappings

func display_mapping_properties(mappings_copy: MappingProperties) -> void:
	cached_mappings_copy_ref = mappings_copy
	visible = true
	for mapping in cached_mappings_copy_ref.mappings:
		_mappings_scroll.spawn_list_item(
			{
				"morphologies": FeagiCache.morphology_cache.available_morphologies.keys(),
				"mapping": mapping,
				"mappings": cached_mappings_copy_ref
			})

func clear_mapping_properties():
	_mappings_scroll.remove_all_children()
	visible = false

func _add_mapping_pressed() -> void:
	if len(FeagiCache.morphology_cache.available_morphologies.keys) == 0:
		print("Unable to spawn a connection when no morphologies exist!")
		## TODO a user error may go well here
		return
	var new_mapping: MappingProperty = MappingProperty.create_default_mapping(FeagiCache.morphology_cache.available_morphologies[FeagiCache.morphology_cache.available_morphologies.keys()[0]])
	cached_mappings_copy_ref.add_mapping_manually(new_mapping)
	_mappings_scroll.spawn_list_item(
		{
			"morphologies": FeagiCache.morphology_cache.available_morphologies.keys(),
			"mapping": new_mapping,
			"mappings": cached_mappings_copy_ref
		}
	)
