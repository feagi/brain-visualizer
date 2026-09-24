extends RefCounted
class_name VoxelInspectorSummary
## Summary text shared by the voxel inspector panel and the live hover box.


## Placeholder shown when a summary metric has no neurons to aggregate.
const EMPTY_METRIC: String = "—"


static func variant_to_float(v: Variant) -> float:
	if v == null:
		return 0.0
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		return v as float
	if t == TYPE_INT:
		return float(v as int)
	return 0.0


static func format_membrane_for_display(v: float) -> String:
	return String.num(v, 4)


## Maps API `neuron` dict fields to a float for threshold (key `threshold`).
static func neuron_firing_threshold(nd: Dictionary) -> float:
	return variant_to_float(nd.get("threshold", 0.0))


## Integer runtime fields: `refractory_countdown`, `consecutive_fire_count`.
static func neuron_int_metric(nd: Dictionary, key: StringName) -> int:
	return int(round(variant_to_float(nd.get(key, 0))))


## Summary labels and values for one `voxel_neurons` payload. Several neurons in one voxel are averaged.
static func summarize_voxel_neurons(d: Dictionary) -> Dictionary:
	var neurons: Array = []
	var neurons_raw: Variant = d.get("neurons", [])
	if neurons_raw is Array:
		neurons = neurons_raw
	var n: int = neurons.size()
	var reported: int = int(d.get("neuron_count", n))
	var summary := {
		"neuron_count": str(reported),
		"membrane_label": "Membrane Potential",
		"incoming_label": "Incoming Synapse Count",
		"outgoing_label": "Outgoing Synapse Count",
		"firing_label": "Firing Threshold",
		"refractory_label": "Refractory Countdown",
		"consecutive_label": "Consecutive Fires",
		"membrane": EMPTY_METRIC,
		"incoming": EMPTY_METRIC,
		"outgoing": EMPTY_METRIC,
		"firing": EMPTY_METRIC,
		"refractory": EMPTY_METRIC,
		"consecutive": EMPTY_METRIC,
	}
	if n == 0:
		return summary
	if n == 1:
		var nd: Dictionary = {}
		if neurons[0] is Dictionary:
			nd = neurons[0]
		summary["membrane"] = format_membrane_for_display(variant_to_float(nd.get("membrane_potential", 0.0)))
		summary["incoming"] = str(int(round(variant_to_float(nd.get("incoming_synapse_count", 0)))))
		summary["outgoing"] = str(int(round(variant_to_float(nd.get("outgoing_synapse_count", 0)))))
		summary["firing"] = format_membrane_for_display(neuron_firing_threshold(nd))
		summary["refractory"] = str(neuron_int_metric(nd, &"refractory_countdown"))
		summary["consecutive"] = str(neuron_int_metric(nd, &"consecutive_fire_count"))
		return summary
	summary["membrane_label"] = "Average Membrane Potential"
	summary["incoming_label"] = "Average Incoming Synapse Count"
	summary["outgoing_label"] = "Average Outgoing Synapse Count"
	summary["firing_label"] = "Average Firing Threshold"
	summary["refractory_label"] = "Average Refractory Countdown"
	summary["consecutive_label"] = "Average Consecutive Fires"
	var sum_mp: float = 0.0
	var sum_in: float = 0.0
	var sum_out: float = 0.0
	var sum_thr: float = 0.0
	var sum_refr: float = 0.0
	var sum_consec: float = 0.0
	for item in neurons:
		if item is Dictionary:
			var nd2: Dictionary = item
			sum_mp += variant_to_float(nd2.get("membrane_potential", 0.0))
			sum_in += variant_to_float(nd2.get("incoming_synapse_count", 0))
			sum_out += variant_to_float(nd2.get("outgoing_synapse_count", 0))
			sum_thr += neuron_firing_threshold(nd2)
			sum_refr += float(neuron_int_metric(nd2, &"refractory_countdown"))
			sum_consec += float(neuron_int_metric(nd2, &"consecutive_fire_count"))
	var nf: float = float(n)
	summary["membrane"] = format_membrane_for_display(sum_mp / nf)
	summary["incoming"] = str(int(round(sum_in / nf)))
	summary["outgoing"] = str(int(round(sum_out / nf)))
	summary["firing"] = format_membrane_for_display(sum_thr / nf)
	summary["refractory"] = str(int(round(sum_refr / nf)))
	summary["consecutive"] = str(int(round(sum_consec / nf)))
	return summary


## Average fire-time membrane potential for [param coord] in one visualization frame.
## `found` is false when that voxel did not fire in the frame.
static func firing_membrane_at_coordinate(
	x_array: PackedInt32Array,
	y_array: PackedInt32Array,
	z_array: PackedInt32Array,
	p_array: PackedFloat32Array,
	coord: Vector3i
) -> Dictionary:
	var n: int = x_array.size()
	if y_array.size() != n or z_array.size() != n or p_array.size() != n:
		return {"found": false, "value": 0.0, "count": 0}
	var total: float = 0.0
	var count: int = 0
	for i in n:
		if x_array[i] == coord.x and y_array[i] == coord.y and z_array[i] == coord.z:
			total += p_array[i]
			count += 1
	if count == 0:
		return {"found": false, "value": 0.0, "count": 0}
	return {"found": true, "value": total / float(count), "count": count}


## Multi-line hover box. Same metrics as the inspector Summary block.
## [param firing_sample] replaces membrane potential with the fire-time value from the
## visualization frame. After a spike the live neuron state is reset to 0.
static func format_live_inspector_text(area_name: String, coord: Vector3i, d: Dictionary, firing_sample: Variant = null) -> String:
	var summary: Dictionary = summarize_voxel_neurons(d)
	if firing_sample is Dictionary and bool((firing_sample as Dictionary).get("found", false)):
		var sample: Dictionary = firing_sample
		summary["membrane"] = format_membrane_for_display(float(sample.get("value", 0.0)))
		if int(sample.get("count", 1)) > 1:
			summary["membrane_label"] = "Average Membrane Potential"
		else:
			summary["membrane_label"] = "Membrane Potential"
	return "%s %s\nNeuron Count: %s\n%s: %s\n%s: %s\n%s: %s\n%s: %s\n%s: %s\n%s: %s" % [
		area_name,
		str(coord),
		summary["neuron_count"],
		summary["membrane_label"],
		summary["membrane"],
		summary["incoming_label"],
		summary["incoming"],
		summary["outgoing_label"],
		summary["outgoing"],
		summary["firing_label"],
		summary["firing"],
		summary["refractory_label"],
		summary["refractory"],
		summary["consecutive_label"],
		summary["consecutive"],
	]


## Hover box while a voxel fetch is in flight, or when the fetch cannot run.
static func format_live_inspector_status(area_name: String, coord: Vector3i, status: String) -> String:
	return "%s %s\n%s" % [area_name, str(coord), status]


## Live neuron inspector shows the summary box. Live synapse inspector draws Inspect-style arcs.
static func live_hover_shows_summary(neuron_on: bool) -> bool:
	return neuron_on


static func live_hover_shows_synapses(synapse_on: bool) -> bool:
	return synapse_on


## Area-to-area mapping curves compete with voxel synapse arcs.
static func suppress_cortical_mapping(live_synapse_on: bool) -> bool:
	return live_synapse_on


## A neuron on a brain-region plate is still the live-inspector target.
## Plate and region-title hover apply only when the ray misses every cortical renderer.
static func plate_hover_defers_to_neuron(has_cortical_hit: bool) -> bool:
	return has_cortical_hit


## Synapse arcs must be drawn in the view under the cursor when that view hosts the area.
## A region monitor can own the area record without hosting the outside area the mapping connects to.
static func prefer_hovered_monitor_for_synapses(hovered_hosts_area: bool) -> bool:
	return hovered_hosts_area


static func live_hover_should_fetch(neuron_on: bool, synapse_on: bool) -> bool:
	return neuron_on or synapse_on


## Tooltip for the shared bottom-right Stop Inspector button.
static func live_stop_tooltip(neuron_on: bool, synapse_on: bool, overlay_for_live: bool) -> String:
	if not overlay_for_live:
		return "Turn off connection inspector"
	if neuron_on and synapse_on:
		return "Turn off live inspectors"
	if synapse_on:
		return "Turn off live synapse inspector"
	return "Turn off live neuron inspector"
