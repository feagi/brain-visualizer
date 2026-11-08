extends RefCounted
class_name ExternalRegionIO
## Foreign cortical areas that connect across a brain-region boundary.
## Input partners feed areas inside the region. Output partners are fed by areas inside it.
## An area that does both is a conflict and is omitted from the pure input and output lists.

## Front-left corner of the external input plate, in FEAGI coordinates.
## The assembly is not a brain region and does not follow region relocation.
const ANCHOR_FEAGI: Vector3i = Vector3i(-100, 50, 0)


## Splits partner ids into pure inputs, pure outputs, and conflicts.
## [param inside_ids] are areas that belong to the host region, including nested regions.
## [param afferent_by_inside] maps an inside id to partner ids that feed it.
## [param efferent_by_inside] maps an inside id to partner ids it feeds.
## Partners that are themselves inside the host are ignored.
static func partition_partner_ids(
	inside_ids: Array,
	afferent_by_inside: Dictionary,
	efferent_by_inside: Dictionary,
) -> Dictionary:
	var inside_lookup: Dictionary = {}
	for inside_id in inside_ids:
		inside_lookup[inside_id] = true
	var raw_inputs: Array = []
	var raw_outputs: Array = []
	var seen_inputs: Dictionary = {}
	var seen_outputs: Dictionary = {}
	for inside_id in afferent_by_inside.keys():
		var afferent_partners: Variant = afferent_by_inside[inside_id]
		if not (afferent_partners is Array):
			continue
		for partner_id in afferent_partners:
			if inside_lookup.has(partner_id) or seen_inputs.has(partner_id):
				continue
			seen_inputs[partner_id] = true
			raw_inputs.append(partner_id)
	for inside_id in efferent_by_inside.keys():
		var efferent_partners: Variant = efferent_by_inside[inside_id]
		if not (efferent_partners is Array):
			continue
		for partner_id in efferent_partners:
			if inside_lookup.has(partner_id) or seen_outputs.has(partner_id):
				continue
			seen_outputs[partner_id] = true
			raw_outputs.append(partner_id)
	var conflicts: Array = []
	var conflict_lookup: Dictionary = {}
	for partner_id in raw_inputs:
		if seen_outputs.has(partner_id):
			conflicts.append(partner_id)
			conflict_lookup[partner_id] = true
	var inputs: Array = []
	for partner_id in raw_inputs:
		if not conflict_lookup.has(partner_id):
			inputs.append(partner_id)
	var outputs: Array = []
	for partner_id in raw_outputs:
		if not conflict_lookup.has(partner_id):
			outputs.append(partner_id)
	return {
		"inputs": inputs,
		"outputs": outputs,
		"conflicts": conflicts,
	}


## The top-level monitor is FEAGI's root, or a tab whose region has no parent after the cached root id drifts.
## [param viewing_feagi_root] is an id match against the live root region.
## [param parent_is_null] covers that same tab when [method BrainRegion.is_root_region] is still false.
static func monitor_is_root_scene(viewing_feagi_root: bool, parent_is_null: bool) -> bool:
	return viewing_feagi_root or parent_is_null


## External plates belong on a subcircuit tab. The root scene draws its own IPU and OPU volumes.
static func should_build_external_io_plates(is_root_scene: bool) -> bool:
	return not is_root_scene


## An IPU or OPU is a volume on the root scene even when its parent id drifted.
## A subcircuit draws one only when that area is a direct child of the open region.
static func should_draw_io_volume_on_monitor(is_root_scene: bool, is_direct_child: bool, is_ipu_or_opu: bool) -> bool:
	if not is_ipu_or_opu:
		return false
	return is_root_scene or is_direct_child
