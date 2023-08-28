extends ItemList

func _on_ca_view_button_pressed():
	for i in FeagiCache.cortical_areas_cache.cortical_areas:
		add_item(FeagiCache.cortical_areas_cache.cortical_areas[i].name)
