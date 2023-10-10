extends ItemList

func _on_ca_view_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		clear() # we need to fix this without clear. 
		for i in FeagiCache.cortical_areas_cache.cortical_areas:
			add_item(FeagiCache.cortical_areas_cache.cortical_areas[i].name)
