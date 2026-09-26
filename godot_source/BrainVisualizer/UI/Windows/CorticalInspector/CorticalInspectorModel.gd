extends RefCounted
class_name CorticalInspectorModel
## Pure rules for the cortical inspector: slider spans, FEAGI payloads, and live-send coalescing.
##
## Wire values match Advanced Cortical Properties: leak and excitability are 0-100 in the UI
## and 0-1 on the wire. Threshold increment is one [x, y, z] array.


const KEY_FIRE_THRESHOLD: StringName = &"neuron_fire_threshold"
const KEY_THRESHOLD_LIMIT: StringName = &"neuron_firing_threshold_limit"
const KEY_EXCITABILITY: StringName = &"neuron_excitability"
const KEY_REFRACTORY: StringName = &"neuron_refractory_period"
const KEY_LEAK: StringName = &"neuron_leak_coefficient"
const KEY_CONSECUTIVE: StringName = &"neuron_consecutive_fire_count"
const KEY_SNOOZE: StringName = &"neuron_snooze_period"
const KEY_THRESHOLD_INCREMENT: StringName = &"neuron_fire_threshold_increment"
const KEY_MP_ACCUMULATION: StringName = &"neuron_mp_charge_accumulation"
const KEY_DEGENERACY: StringName = &"neuron_degeneracy_coefficient"
const KEY_PSP: StringName = &"neuron_post_synaptic_potential"
const KEY_PSP_MAX: StringName = &"neuron_post_synaptic_potential_max"
const KEY_PSP_UNIFORM: StringName = &"neuron_psp_uniform_distribution"
const KEY_MP_DRIVEN_PSP: StringName = &"neuron_mp_driven_psp"

const SECTION_FIRING: StringName = &"firing"
const SECTION_PSP: StringName = &"psp"
const CACHE_FIRING: StringName = &"firing"
const CACHE_PSP: StringName = &"psp"
## Ordinals of AbstractCorticalArea.CORTICAL_AREA_TYPE: IPU, CORE, MEMORY, CUSTOM, INTERCONNECT, OPU, UNKNOWN.
const CORTICAL_TYPE_CORE: int = 1
const CORTICAL_TYPE_MEMORY: int = 2
const CORTICAL_TYPE_CUSTOM: int = 3


## Slider and toggle definitions in display order.
static func parameter_specs() -> Array[Dictionary]:
	return [
		_bool_spec(&"neuron_mp_charge_accumulation", KEY_MP_ACCUMULATION, "MP charge accumulation", SECTION_FIRING, CACHE_FIRING, "neuron_mp_charge_accumulation", true, "Add incoming charge onto the current membrane potential."),
		_number_spec(&"neuron_fire_threshold", KEY_FIRE_THRESHOLD, "Fire threshold", SECTION_FIRING, CACHE_FIRING, "neuron_fire_threshold", "float", 0.0, 20.0, 0.01, 3, false, "Membrane potential required for a neuron to fire."),
		_number_spec(&"neuron_firing_threshold_limit", KEY_THRESHOLD_LIMIT, "Threshold limit", SECTION_FIRING, CACHE_FIRING, "neuron_firing_threshold_limit", "int", 0.0, 100.0, 1.0, 0, false, "Upper cap on the firing threshold."),
		_number_spec(&"neuron_excitability", KEY_EXCITABILITY, "Excitability", SECTION_FIRING, CACHE_FIRING, "neuron_excitability", "percent", 0.0, 100.0, 1.0, 0, false, "Excitability from 0 to 100. Sent to FEAGI as 0 to 1."),
		_number_spec(&"neuron_refractory_period", KEY_REFRACTORY, "Refractory period", SECTION_FIRING, CACHE_FIRING, "neuron_refractory_period", "int", 0.0, 64.0, 1.0, 0, false, "Bursts a neuron stays silent after it fires."),
		_number_spec(&"neuron_leak_coefficient", KEY_LEAK, "Leak", SECTION_FIRING, CACHE_FIRING, "neuron_leak_coefficient", "percent", 0.0, 100.0, 1.0, 0, true, "Percent of membrane potential removed each burst."),
		_number_spec(&"neuron_consecutive_fire_count", KEY_CONSECUTIVE, "Consecutive fire count", SECTION_FIRING, CACHE_FIRING, "neuron_consecutive_fire_count", "int", 0.0, 64.0, 1.0, 0, false, "How many bursts a neuron may fire in a row."),
		_number_spec(&"neuron_snooze_period", KEY_SNOOZE, "Snooze period", SECTION_FIRING, CACHE_FIRING, "neuron_snooze_period", "int", 0.0, 64.0, 1.0, 0, false, "Bursts a neuron waits after hitting the consecutive-fire limit."),
		_vector_spec(&"neuron_fire_threshold_increment_x", 0, "Threshold increment X"),
		_vector_spec(&"neuron_fire_threshold_increment_y", 1, "Threshold increment Y"),
		_vector_spec(&"neuron_fire_threshold_increment_z", 2, "Threshold increment Z"),
		_number_spec(&"neuron_degeneracy_coefficient", KEY_DEGENERACY, "Degeneracy", SECTION_FIRING, CACHE_PSP, "neuron_degeneracy_coefficient", "float", 0.0, 1.0, 0.01, 3, false, "Degeneracy coefficient for this area."),
		_bool_spec(&"neuron_psp_uniform_distribution", KEY_PSP_UNIFORM, "PSP uniform distribution", SECTION_PSP, CACHE_PSP, "neuron_psp_uniform_distribution", false, "Spread postsynaptic potential uniformly."),
		_bool_spec(&"neuron_mp_driven_psp", KEY_MP_DRIVEN_PSP, "MP-driven PSP", SECTION_PSP, CACHE_PSP, "neuron_mp_driven_psp", false, "Use membrane potential as the postsynaptic potential."),
		_number_spec(&"neuron_post_synaptic_potential", KEY_PSP, "Postsynaptic potential", SECTION_PSP, CACHE_PSP, "neuron_post_synaptic_potential", "float", -5.0, 5.0, 0.01, 3, false, "Membrane potential added to downstream neurons per spike."),
		_number_spec(&"neuron_post_synaptic_potential_max", KEY_PSP_MAX, "PSP max", SECTION_PSP, CACHE_PSP, "neuron_post_synaptic_potential_max", "float", 0.0, 10000.0, 0.01, 3, false, "Maximum postsynaptic potential."),
	]


static func spec_by_id(row_id: String) -> Dictionary:
	for spec in parameter_specs():
		if str(spec["id"]) == row_id:
			return spec
	return {}


## Core areas stay read-only, matching Advanced Cortical Properties.
static func is_read_only(cortical_type: int) -> bool:
	return cortical_type == CORTICAL_TYPE_CORE


## Memory areas omit dense-LIF fields that do not apply to associative neurons.
static func row_visible(spec: Dictionary, is_memory: bool, has_firing: bool) -> bool:
	if str(spec["section"]) == str(SECTION_FIRING) and not has_firing:
		return false
	if is_memory and bool(spec["memory_hidden"]):
		return false
	return true


## The PSP constant is unused while MP-driven PSP is on. Core areas lock every value control.
static func value_entry_locked(row_id: String, mp_driven_psp: bool, read_only: bool) -> bool:
	if read_only:
		return true
	if row_id == str(KEY_PSP) and mp_driven_psp:
		return true
	return false


## Percent rows stay inside their default span. Unbounded rows are left unchanged.
static func clamp_ui_value(spec: Dictionary, value: float) -> float:
	if bool(spec.get("editable_bounds", false)):
		return value
	return clampf(value, float(spec["default_min"]), float(spec["default_max"]))


## Widen a stored span so the current value can sit on the slider.
static func span_including_value(span_min: float, span_max: float, value: float) -> Vector2:
	var lo := span_min
	var hi := span_max
	if value < lo:
		lo = value
	if value > hi:
		hi = value
	if lo > hi:
		hi = lo
	return Vector2(lo, hi)


## Min/max edits never exclude the live value and never write FEAGI.
static func edit_bound(span_min: float, span_max: float, live_value: float, editing_min: bool, typed: float) -> Vector2:
	var lo := span_min
	var hi := span_max
	if editing_min:
		lo = typed
	else:
		hi = typed
	if lo > live_value:
		lo = live_value
	if hi < live_value:
		hi = live_value
	if lo > hi:
		if editing_min:
			lo = hi
		else:
			hi = lo
	return Vector2(lo, hi)


## Convert one UI value into the body FEAGI expects for [param key].
static func ui_to_wire(key: String, ui_value: Variant) -> Variant:
	if key == str(KEY_LEAK) or key == str(KEY_EXCITABILITY):
		return clampf(float(ui_value), 0.0, 100.0) / 100.0
	if key == str(KEY_THRESHOLD_INCREMENT):
		return _vector_components(ui_value)
	if key == str(KEY_MP_ACCUMULATION) or key == str(KEY_PSP_UNIFORM) or key == str(KEY_MP_DRIVEN_PSP):
		return bool(ui_value)
	if key == str(KEY_THRESHOLD_LIMIT) or key == str(KEY_REFRACTORY) or key == str(KEY_CONSECUTIVE) or key == str(KEY_SNOOZE):
		return int(round(float(ui_value)))
	return float(ui_value)


## Area-name menu rows. Duplicate names keep the cortical id so the filter can tell them apart.
static func build_area_menu_entries(named_ids: Array) -> Array[Dictionary]:
	var counts: Dictionary = {}
	for item in named_ids:
		var area_name := str(item.get("name", ""))
		counts[area_name] = int(counts.get(area_name, 0)) + 1
	var entries: Array[Dictionary] = []
	for item in named_ids:
		var area_name := str(item.get("name", ""))
		var area_id := str(item.get("id", ""))
		var label := area_name
		if int(counts.get(area_name, 0)) > 1:
			label = "%s (%s)" % [area_name, area_id]
		entries.append({"label": label, "id": area_id})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["label"]).to_lower() < str(b["label"]).to_lower()
	)
	return entries


## Pick the cortical id a 3D click should focus.
## A one-area selection focuses that area. A larger selection focuses the id that was just added.
static func pick_focus_id(current_focus_id: String, previous_selection_ids: Array, selected_ids: Array) -> String:
	if selected_ids.is_empty():
		return ""
	if selected_ids.size() == 1:
		return str(selected_ids[0])
	var previous := _string_set(previous_selection_ids)
	var added: Array[String] = []
	for raw_id in selected_ids:
		var area_id := str(raw_id)
		if not previous.has(area_id):
			added.append(area_id)
	if not added.is_empty():
		return added[added.size() - 1]
	var selected := _string_set(selected_ids)
	if current_focus_id != "" and selected.has(current_focus_id):
		return current_focus_id
	return str(selected_ids[selected_ids.size() - 1])


## One in-flight update per parameter. Later drag samples replace the pending value.
static func new_send_state() -> Dictionary:
	return {
		"in_flight": false,
		"pending": null,
		"has_pending": false,
		"last_sent": null,
		"has_last_sent": false,
		"last_accepted": null,
		"has_accepted": false,
	}


## Returns true when the caller should start the HTTP send for [param value].
static func offer_value(state: Dictionary, value: Variant) -> bool:
	var stored: Variant = _copy_value(value)
	if bool(state["in_flight"]):
		state["pending"] = stored
		state["has_pending"] = true
		return false
	if bool(state["has_last_sent"]) and values_equal(state["last_sent"], stored):
		return false
	state["in_flight"] = true
	state["last_sent"] = stored
	state["has_last_sent"] = true
	state["has_pending"] = false
	state["pending"] = null
	return true


## Clear the in-flight flag after FEAGI accepts [param sent]. [code]has_next[/code] carries the latest queued sample.
static func finish_success(state: Dictionary, sent: Variant) -> Dictionary:
	state["in_flight"] = false
	state["last_accepted"] = _copy_value(sent)
	state["has_accepted"] = true
	if not bool(state["has_pending"]):
		return {"has_next": false, "value": null}
	var nxt: Variant = state["pending"]
	state["has_pending"] = false
	state["pending"] = null
	if values_equal(nxt, sent):
		return {"has_next": false, "value": null}
	return {"has_next": true, "value": nxt}


## Drop the in-flight sample. [code]has_restore[/code] is the last value FEAGI accepted.
static func finish_failure(state: Dictionary) -> Dictionary:
	state["in_flight"] = false
	state["has_pending"] = false
	state["pending"] = null
	if bool(state["has_accepted"]):
		state["last_sent"] = _copy_value(state["last_accepted"])
		state["has_last_sent"] = true
	else:
		state["last_sent"] = null
		state["has_last_sent"] = false
	return {"has_restore": bool(state["has_accepted"]), "value": state["last_accepted"]}


## Ignore a response for an area the window has already left.
static func abandon(state: Dictionary) -> void:
	state["in_flight"] = false
	state["has_pending"] = false
	state["pending"] = null


static func values_equal(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == null and b == null
	if a is Array and b is Array:
		var left: Array = a
		var right: Array = b
		if left.size() != right.size():
			return false
		for i in left.size():
			if not is_equal_approx(float(left[i]), float(right[i])):
				return false
		return true
	if typeof(a) == TYPE_BOOL or typeof(b) == TYPE_BOOL:
		return bool(a) == bool(b)
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT or typeof(a) == TYPE_INT or typeof(b) == TYPE_INT:
		return is_equal_approx(float(a), float(b))
	return a == b


static func _number_spec(row_id: StringName, key: StringName, label: String, section: StringName, cache: StringName, property: String, kind: String, span_min: float, span_max: float, step: float, decimals: int, memory_hidden: bool, tooltip: String) -> Dictionary:
	return {
		"id": row_id,
		"key": key,
		"label": label,
		"section": section,
		"cache": cache,
		"property": property,
		"kind": kind,
		"axis": -1,
		"default_min": span_min,
		"default_max": span_max,
		"step": step,
		"decimals": decimals,
		"memory_hidden": memory_hidden,
		"editable_bounds": kind != "percent",
		"tooltip": tooltip,
	}


static func _bool_spec(row_id: StringName, key: StringName, label: String, section: StringName, cache: StringName, property: String, memory_hidden: bool, tooltip: String) -> Dictionary:
	return {
		"id": row_id,
		"key": key,
		"label": label,
		"section": section,
		"cache": cache,
		"property": property,
		"kind": "bool",
		"axis": -1,
		"default_min": 0.0,
		"default_max": 1.0,
		"step": 1.0,
		"decimals": 0,
		"memory_hidden": memory_hidden,
		"editable_bounds": false,
		"tooltip": tooltip,
	}


static func _vector_spec(row_id: StringName, axis: int, label: String) -> Dictionary:
	return {
		"id": row_id,
		"key": KEY_THRESHOLD_INCREMENT,
		"label": label,
		"section": SECTION_FIRING,
		"cache": CACHE_FIRING,
		"property": "neuron_fire_threshold_increment",
		"kind": "vector",
		"axis": axis,
		"default_min": -1.0,
		"default_max": 1.0,
		"step": 0.01,
		"decimals": 3,
		"memory_hidden": true,
		"editable_bounds": true,
		"tooltip": "Per-axis addition to the firing threshold.",
	}


static func _vector_components(ui_value: Variant) -> Array:
	if ui_value is Vector3:
		var vec := ui_value as Vector3
		return [vec.x, vec.y, vec.z]
	var parts: Array = ui_value as Array
	return [float(parts[0]), float(parts[1]), float(parts[2])]


static func _string_set(raw_ids: Array) -> Dictionary:
	var found: Dictionary = {}
	for raw_id in raw_ids:
		found[str(raw_id)] = true
	return found


static func _copy_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate()
	return value
