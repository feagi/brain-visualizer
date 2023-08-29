extends ItemList

func _on_ca_view_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		for i in FeagiCache.cortical_areas_cache.cortical_areas:
			clear() # we need to fix this without clear. 
			add_item(FeagiCache.cortical_areas_cache.cortical_areas[i].name)
