extends RefCounted
class_name TeamBranchText
## Text for the team experiment branch badge and live teammate notices.
##
## Inputs are the JSON messages feagi-desktop sends on its event socket
## (see feagi-desktop `commands/team_bv_events.rs`). Pure functions only, so
## they can be tested headless.

const MODE_COLLABORATIVE: String = "collaborative"
const MODE_FORK: String = "fork"
const MODE_PENDING: String = "pending"
## Person column. Bold light blue in the history table.
const ACTOR_COLOR: String = "8ab4f8"
## Target column. Bold amber in the history table.
const TARGET_COLOR: String = "f5bd6b"
## Keys that identify an area. They are not a change a person reads.
const _HIDDEN_CHANGE_KEYS: Array[String] = ["cortical_id", "cortical_id_list", "previous_cortical_id", "new_cortical_id"]


## True when the badge should be shown (a team experiment is running).
static func is_team_state(state: Dictionary) -> bool:
	return bool(state.get("team", false)) and typeof(state.get("branch")) == TYPE_DICTIONARY


## Branch mode of a team state: "collaborative", "fork", "pending" or "unknown".
static func mode_of(state: Dictionary) -> String:
	if not is_team_state(state):
		return ""
	return str((state["branch"] as Dictionary).get("mode", "unknown"))


## Badge label, e.g. "Collaborative genome (rev 12)" or "Independent fork (from rev 10)".
static func badge_label(state: Dictionary) -> String:
	if not is_team_state(state):
		return ""
	var branch: Dictionary = state["branch"]
	match mode_of(state):
		MODE_COLLABORATIVE:
			return "Collaborative genome (rev %d)" % int(branch.get("master_revision", 0))
		MODE_FORK:
			return "Independent fork (from rev %d)" % int(branch.get("diverged_from_revision", 0))
		MODE_PENDING:
			return "Checking branch..."
		_:
			return "Branch unknown"


## Tooltip explaining what saving means on this branch.
static func badge_tooltip(state: Dictionary) -> String:
	match mode_of(state):
		MODE_COLLABORATIVE:
			return "Your edits save to the team's shared genome. Teammates see them and are notified."
		MODE_FORK:
			return "Your edits save to your own fork. Teammates are not notified. A teammate can make it the collaborative genome from Neurorobotics Studio."
		MODE_PENDING:
			return "Neurorobotics Studio is checking whether this connectome keeps you on the collaborative genome."
		"":
			return ""
		_:
			return "This brain was not loaded from the collaborative genome or a team connectome; autosave is paused."


## Live notice for a teammate's change to the collaborative genome running here.
static func event_text(event: Dictionary) -> String:
	var actor: String = str(event.get("actor_display_name", ""))
	if actor.strip_edges() == "" or actor == "<null>":
		actor = "A teammate"
	var revision_value = event.get("revision")
	var revision: String = "a new revision" if revision_value == null else "revision %d" % int(revision_value)
	match str(event.get("kind", "")):
		"master_replaced":
			return "%s replaced the collaborative genome with a fork (%s)." % [actor, revision]
		"master_reverted":
			return "%s switched the collaborative genome back to an earlier version (%s)." % [actor, revision]
		"master_checkpoint_reverted":
			return "%s restored a checkpoint into the collaborative genome (%s)." % [actor, revision]
		"genome_change":
			return "%s changed %s (%s)." % [actor, str(event.get("target_id", "the genome")), str(event.get("operation", "change"))]
		"genome_change_rejected":
			return "Your change to %s was undone because a teammate changed it first." % str(event.get("target_id", "the genome"))
		"genome_change_gap":
			return "Some live genome changes were missed. Reload the collaborative genome to catch up."
		_:
			return "%s saved %s of the collaborative genome." % [actor, revision]


## One row in the change-history window.
static func history_line(event: Dictionary) -> String:
	var sentence := _history_sentence(event)
	var clock := _clock(event)
	if clock == "":
		return sentence
	return "%s  %s" % [clock, sentence]


## Rows for the history window from one `GET /v1/genome/changes` page.
## Local edits and edits with no author are this member. A replayed change keeps its author id.
static func events_from_ledger(changes: Array, self_agent_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for entry in changes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if entry.get("replayable", true) == false:
			continue
		var operation: Dictionary = entry.get("operation", {})
		if typeof(operation) != TYPE_DICTIONARY:
			operation = {}
		var agent := str(entry.get("agent_id", ""))
		if agent == "<null>":
			agent = ""
		var mine := str(entry.get("origin", "")) == "local" or agent == "" or (self_agent_id != "" and agent == self_agent_id)
		var actor := "You" if mine else agent
		events.append({
			"kind": "genome_change",
			"actor_display_name": actor,
			"operation": str(operation.get("kind", "change")),
			"target_id": _ledger_target_label(entry),
			"target_ids": _ledger_target_ids(entry),
			"detail": _change_detail(entry),
			"timestamp_ms": entry.get("timestamp_ms"),
			"mine": mine,
		})
	return events


## Table cells for one history row: time, who, action, target.
static func history_columns(event: Dictionary) -> Dictionary:
	var actor := str(event.get("actor_display_name", "")).strip_edges()
	if actor == "" or actor == "<null>":
		actor = "A teammate"
	var target := str(event.get("target_id", "")).strip_edges()
	if target == "":
		target = "the genome"
	var action := "updated"
	var detail := str(event.get("detail", "")).strip_edges()
	match str(event.get("kind", "")):
		"genome_change":
			action = detail if detail != "" else _verb(str(event.get("operation", "")))
		"genome_change_rejected":
			action = "undone"
			actor = "You"
		"genome_change_gap":
			action = "missed"
			actor = ""
			target = "live changes"
		_:
			action = "saved"
	return {
		"time": _clock(event),
		"who": actor,
		"action": action,
		"target": target,
	}


## Bold colored cell text. Names that contain brackets stay literal.
static func emphasized(text: String, color_hex: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [color_hex, text.replace("[", "[lb]")]


## True when `value` is a cortical id rather than a name a person would read.
static func looks_like_cortical_id(value: String) -> bool:
	var text := value.strip_edges()
	if text.length() < 8:
		return false
	if text.contains(" ") or text.contains("_") or text.contains("-"):
		return false
	if text.ends_with("="):
		return true
	if text.length() < 12:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var is_id_char := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 43 or code == 47
		if not is_id_char:
			return false
	return true


static func _ledger_target_ids(change: Dictionary) -> Array:
	var ids: Array = []
	var targets = change.get("targets", [])
	if typeof(targets) != TYPE_ARRAY:
		return ids
	for target in targets:
		if typeof(target) != TYPE_DICTIONARY:
			continue
		var target_id := str(target.get("id", "")).strip_edges()
		if target_id != "" and target_id != "<null>":
			ids.append(target_id)
		var related := str(target.get("related_id", "")).strip_edges()
		if related != "" and related != "<null>":
			ids.append(related)
	return ids


static func _ledger_target_label(change: Dictionary) -> String:
	var names := PackedStringArray()
	_append_names(names, change.get("after"))
	var operation = change.get("operation", {})
	var kind := ""
	if typeof(operation) == TYPE_DICTIONARY:
		kind = str(operation.get("kind", ""))
		_append_names(names, operation.get("changes"))
		_append_names(names, operation.get("properties"))
		var params = operation.get("params")
		if typeof(params) == TYPE_ARRAY:
			for item in params:
				_append_names(names, item)
		else:
			_append_names(names, params)
		_append_names(names, operation.get("morphology"))
		_append_names(names, operation.get("classifier"))
		if kind == "rename_morphology":
			_append_plain_name(names, str(operation.get("new_id", "")))
	_append_names(names, change.get("before"))
	if names.size() > 0:
		return ", ".join(names)
	if kind == "update_cortical_mapping" or kind == "rekey_memory_twin_source":
		return "a connection"
	if kind == "":
		return "the genome"
	return "a cortical area"


static func _append_names(names: PackedStringArray, value) -> void:
	var direct := _first_name(value)
	if direct != "":
		_append_plain_name(names, direct)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var area_name := _first_name(value.get("area"))
	if area_name != "":
		_append_plain_name(names, area_name)
		return
	for key in value.keys():
		if str(key) == "incoming_mappings":
			continue
		var child = value[key]
		if typeof(child) != TYPE_DICTIONARY:
			continue
		_append_plain_name(names, _first_name(child))


static func _first_name(value) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	for key in ["cortical_name", "name", "title", "friendly_name"]:
		var raw = value.get(key)
		if typeof(raw) != TYPE_STRING:
			continue
		var text: String = (raw as String).strip_edges()
		if text == "" or text == "<null>" or looks_like_cortical_id(text):
			continue
		return text
	return ""


static func _append_plain_name(names: PackedStringArray, text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned == "" or looks_like_cortical_id(cleaned):
		return
	if cleaned in names:
		return
	names.append(cleaned)


## Chip under the history icon. Empty when there is nothing new.
static func change_count_chip(count: int) -> String:
	if count <= 0:
		return ""
	if count > 99:
		return "99+"
	return str(count)


## Yellow when a teammate has unseen changes. Blue when every unseen change is yours.
static func change_chip_is_yellow(other_count: int) -> bool:
	return other_count > 0


## Hover text: your count, then one line per other person.
static func change_breakdown_tooltip(counts_by_actor: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append(_change_count_line("You", int(counts_by_actor.get("You", 0))))
	var names: Array = counts_by_actor.keys()
	names.sort()
	for name in names:
		var actor := str(name)
		if actor == "You":
			continue
		var count := int(counts_by_actor[name])
		if count <= 0:
			continue
		lines.append(_change_count_line(actor, count))
	return "\n".join(lines)


static func _change_count_line(actor: String, count: int) -> String:
	var noun := "change" if count == 1 else "changes"
	return "%s made %d %s" % [actor, count, noun]


static func _history_sentence(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	var actor := str(event.get("actor_display_name", ""))
	if actor.strip_edges() == "" or actor == "<null>":
		actor = "A teammate"
	var target := str(event.get("target_id", ""))
	if target.strip_edges() == "":
		target = "the genome"
	match kind:
		"genome_change":
			return "%s %s %s." % [actor, _verb(str(event.get("operation", ""))), target]
		"genome_change_rejected":
			return "Your change to %s was undone because a teammate changed it first." % target
		"genome_change_gap":
			return "Some live genome changes were missed. Reload the collaborative genome to catch up."
		_:
			return event_text(event)


## What an update actually wrote, using the ledger patch and the before snapshot.
static func _change_detail(change: Dictionary) -> String:
	var operation = change.get("operation", {})
	if typeof(operation) != TYPE_DICTIONARY:
		return ""
	var kind := str(operation.get("kind", ""))
	if kind != "update_cortical_area" and kind != "update_brain_region" and kind != "update_morphology":
		return ""
	var patch = operation.get("changes", null)
	if typeof(patch) != TYPE_DICTIONARY:
		patch = operation.get("properties", {})
	if typeof(patch) != TYPE_DICTIONARY or patch.is_empty():
		return ""
	var before = change.get("before")
	var lines: PackedStringArray = []
	var keys: Array = patch.keys()
	keys.sort()
	for key in keys:
		var field := str(key)
		if field in _HIDDEN_CHANGE_KEYS:
			continue
		var new_text := _format_change_value(patch[key])
		if new_text == "" or looks_like_cortical_id(new_text):
			continue
		var label := _property_label(field)
		var old_text := ""
		var previous_field := _previous_value_field(field)
		if not _has_previous(before, previous_field):
			previous_field = field
		if _has_previous(before, previous_field):
			old_text = _format_change_value(_lookup_previous(before, previous_field))
		if old_text != "" and not looks_like_cortical_id(old_text):
			if old_text == new_text:
				continue
			lines.append("%s %s → %s" % [label, old_text, new_text])
		else:
			lines.append("%s %s" % [label, new_text])
	var ordered: Array = Array(lines)
	ordered.sort()
	return ", ".join(ordered)


## A move writes `coordinates_3d`, but the snapshot keeps that copy at the original
## place. The coordinate that actually changes is `position`.
static func _previous_value_field(field: String) -> String:
	match field:
		"coordinates_3d", "coordinate_3d", "coordinates", "position":
			return "position"
		_:
			return field


static func _has_previous(before, field: String) -> bool:
	return _find_previous(before, field) != null


static func _lookup_previous(before, field: String):
	var found = _find_previous(before, field)
	if typeof(found) != TYPE_ARRAY or found.is_empty():
		return null
	return found[0]


static func _find_previous(before, field: String):
	if typeof(before) != TYPE_DICTIONARY:
		return null
	if before.has(field):
		return [before[field]]
	var area = before.get("area")
	if typeof(area) == TYPE_DICTIONARY and area.has(field):
		return [area[field]]
	for child_key in before.keys():
		if str(child_key) == "incoming_mappings":
			continue
		var child = before[child_key]
		if typeof(child) == TYPE_DICTIONARY and child.has(field):
			return [child[field]]
	return null


static func _property_label(field: String) -> String:
	match field:
		"cortical_name", "name", "title":
			return "Name"
		"coordinates_3d", "coordinate_3d", "coordinates", "position":
			return "Position"
		"coordinate_2d", "coordinates_2d":
			return "Position 2D"
		"cortical_dimensions", "dimensions":
			return "Dimensions"
		"visible":
			return "Visible"
		"neuron_fire_threshold":
			return "Fire threshold"
		"neuron_firing_threshold_limit", "firing_threshold_limit":
			return "Threshold limit"
		"neuron_excitability":
			return "Excitability"
		"neuron_refractory_period", "refractory_period":
			return "Refractory period"
		"neuron_leak_coefficient", "leak_coefficient":
			return "Leak"
		"neuron_consecutive_fire_count", "consecutive_fire_count":
			return "Consecutive fire count"
		"neuron_snooze_period", "snooze_period":
			return "Snooze period"
		"neuron_fire_threshold_increment", "firing_threshold_increment":
			return "Threshold increment"
		"neuron_mp_charge_accumulation":
			return "MP charge accumulation"
		"neuron_degeneracy_coefficient", "degeneration":
			return "Degeneracy"
		"neuron_post_synaptic_potential", "postsynaptic_current":
			return "Postsynaptic potential"
		"neuron_post_synaptic_potential_max":
			return "PSP max"
		"neuron_psp_uniform_distribution", "psp_uniform_distribution":
			return "PSP uniform distribution"
		"neuron_mp_driven_psp":
			return "MP-driven PSP"
		"plasticity_constant":
			return "Plasticity"
		"leak_variability":
			return "Leak variability"
		"burst_engine_active":
			return "Burst engine"
		"visualization_voxel_granularity":
			return "Voxel granularity"
		"neurons_per_voxel":
			return "Neurons per voxel"
		_:
			var words := field.replace("_", " ").strip_edges()
			if words == "":
				return field
			return words.substr(0, 1).to_upper() + words.substr(1)


static func _format_change_value(value) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "on" if bool(value) else "off"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return _format_number(float(value))
		TYPE_STRING:
			var text := (value as String).strip_edges()
			if text == "<null>":
				return ""
			return text
		TYPE_ARRAY:
			return _format_sequence(value)
		TYPE_DICTIONARY:
			if value.has("x") and value.has("y") and value.has("z"):
				return "(%s, %s, %s)" % [_format_change_value(value["x"]), _format_change_value(value["y"]), _format_change_value(value["z"])]
			return ""
		_:
			return ""


static func _format_sequence(values: Array) -> String:
	if values.is_empty():
		return ""
	var parts: PackedStringArray = []
	for item in values:
		var text := _format_change_value(item)
		if text == "":
			return ""
		parts.append(text)
	if parts.size() >= 2 and parts.size() <= 3:
		return "(%s)" % ", ".join(parts)
	return ", ".join(parts)


static func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	var text := "%.4f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _verb(operation: String) -> String:
	match operation:
		"create_cortical_areas", "create_brain_region", "create_morphology":
			return "created"
		"delete_cortical_area", "delete_brain_region", "delete_morphology", "delete_classifier":
			return "deleted"
		"rename_morphology":
			return "renamed"
		"update_cortical_mapping", "rekey_memory_twin_source":
			return "rewired"
		"upsert_classifier":
			return "updated classifier"
		_:
			return "updated"


## Local clock time. The ledger stores UTC unix milliseconds.
static func _clock(event: Dictionary) -> String:
	var stamp = event.get("timestamp_ms")
	if typeof(stamp) != TYPE_INT and typeof(stamp) != TYPE_FLOAT:
		return ""
	var unix_seconds := int(stamp) / 1000
	if unix_seconds <= 0:
		return ""
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var parts := Time.get_datetime_dict_from_unix_time(unix_seconds + bias_minutes * 60)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(parts["year"]), int(parts["month"]), int(parts["day"]),
		int(parts["hour"]), int(parts["minute"]), int(parts["second"]),
	]
