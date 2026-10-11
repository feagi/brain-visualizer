extends RefCounted
class_name GlobalSearchCatalog
## Names the user can jump to from genome search.
##
## Areas, circuits, and modulator areas move the camera the same way a top-bar
## list click does. A connectivity rule opens that rule in the rule manager.
## A classifier opens its editor.


const KIND_CORE: StringName = &"core"
const KIND_IPU: StringName = &"ipu"
const KIND_OPU: StringName = &"opu"
const KIND_MEMORY: StringName = &"memory"
const KIND_INTERCONNECT: StringName = &"interconnect"
const KIND_MODULATOR: StringName = &"modulator"
const KIND_AREA: StringName = &"area"
const KIND_CIRCUIT: StringName = &"circuit"
const KIND_RULE: StringName = &"connectivity_rule"
const KIND_CLASSIFIER: StringName = &"classifier"

const ACTION_FOCUS_AREA: StringName = &"focus_area"
const ACTION_FOCUS_REGION: StringName = &"focus_region"
const ACTION_OPEN_RULE: StringName = &"open_rule"
const ACTION_OPEN_CLASSIFIER: StringName = &"open_classifier"

const KEY_LABEL := "label"
const KEY_KIND := "kind"
const KEY_ACTION := "action"
const KEY_PAYLOAD := "payload"


## Ctrl/Cmd+S. Shift and Alt stay free. Echoes are ignored so a held key does not toggle.
static func is_search_shortcut(keycode: Key, with_command: bool, shift_pressed: bool, alt_pressed: bool, pressed: bool, echo: bool) -> bool:
	if keycode != KEY_S or not with_command or shift_pressed or alt_pressed or not pressed or echo:
		return false
	return true


## Category used in the result list for a cortical area.
static func kind_for_cortical_type(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> StringName:
	match cortical_type:
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
			return KIND_CORE
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			return KIND_IPU
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			return KIND_OPU
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			return KIND_MEMORY
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM, AbstractCorticalArea.CORTICAL_AREA_TYPE.INTERCONNECT:
			return KIND_INTERCONNECT
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR:
			return KIND_MODULATOR
		_:
			return KIND_AREA


## What a click on this kind does.
static func action_for_kind(kind: StringName) -> StringName:
	match kind:
		KIND_CIRCUIT:
			return ACTION_FOCUS_REGION
		KIND_RULE:
			return ACTION_OPEN_RULE
		KIND_CLASSIFIER:
			return ACTION_OPEN_CLASSIFIER
		_:
			return ACTION_FOCUS_AREA


## Short label shown beside the name.
static func kind_title(kind: StringName) -> String:
	match kind:
		KIND_CORE:
			return "Core"
		KIND_IPU:
			return "IPU"
		KIND_OPU:
			return "OPU"
		KIND_MEMORY:
			return "Memory"
		KIND_INTERCONNECT:
			return "Interconnect"
		KIND_MODULATOR:
			return "Modulator"
		KIND_CIRCUIT:
			return "Circuit"
		KIND_RULE:
			return "Connectivity rule"
		KIND_CLASSIFIER:
			return "Classifier"
		_:
			return "Area"


## Extra words so "input" finds IPUs and "rule" finds connectivity rules.
static func kind_aliases(kind: StringName) -> String:
	match kind:
		KIND_IPU:
			return "input inputs"
		KIND_OPU:
			return "output outputs"
		KIND_MEMORY:
			return "memory"
		KIND_INTERCONNECT:
			return "interconnect custom"
		KIND_MODULATOR:
			return "modulator modulators"
		KIND_CIRCUIT:
			return "circuit circuits region"
		KIND_RULE:
			return "connectivity rule rules morphology"
		KIND_CLASSIFIER:
			return "classifier"
		KIND_CORE:
			return "core"
		_:
			return ""


## One result line: name, then its kind.
static func result_text(label: String, kind: StringName) -> String:
	return "%s    %s" % [label, kind_title(kind)]


## True when the name or the kind words contain [param needle_lower].
static func matches_entry(entry: Dictionary, needle_lower: String) -> bool:
	if needle_lower.is_empty():
		return false
	var label := String(entry.get(KEY_LABEL, "")).to_lower()
	if label.find(needle_lower) >= 0:
		return true
	var kind: StringName = entry.get(KEY_KIND, &"")
	var kind_text := ("%s %s" % [kind_title(kind), kind_aliases(kind)]).to_lower()
	return kind_text.find(needle_lower) >= 0


## Entries whose name or kind matches [param query]. An empty query matches nothing.
static func filter_entries(entries: Array, query: String) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	var needle := query.strip_edges().to_lower()
	if needle.is_empty():
		return matched
	for entry in entries:
		if entry is Dictionary and matches_entry(entry, needle):
			matched.append(entry)
	matched.sort_custom(_sort_entries)
	return matched


## Builds the searchable list from the genome cache the top bar already uses.
static func entries_from_cache(cache: FEAGILocalCache) -> Array[Dictionary]:
	if cache == null:
		return []
	var areas: Array = []
	var regions: Array = []
	var morphologies: Array = []
	var classifiers: Array = []
	if cache.cortical_areas != null:
		areas.assign(cache.cortical_areas.available_cortical_areas.values())
	if cache.brain_regions != null:
		regions.assign(cache.brain_regions.available_brain_regions.values())
	if cache.morphologies != null:
		morphologies.assign(cache.morphologies.available_morphologies.values())
	classifiers.assign(cache.classifiers.values())
	return entries_from_parts(areas, regions, morphologies, classifiers)


## Builds entries from already loaded genome objects. Empty names are left out.
static func entries_from_parts(areas: Array, regions: Array, morphologies: Array, classifiers: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for area in areas:
		if area is AbstractCorticalArea:
			var area_entry := _entry_for_area(area)
			if not area_entry.is_empty():
				entries.append(area_entry)
	for region in regions:
		if region is BrainRegion:
			var region_entry := _entry_for_region(region)
			if not region_entry.is_empty():
				entries.append(region_entry)
	for morphology in morphologies:
		if morphology is BaseMorphology:
			var rule_entry := _entry_for_rule(morphology)
			if not rule_entry.is_empty():
				entries.append(rule_entry)
	for classifier in classifiers:
		if classifier is GenomeClassifier:
			var classifier_entry := _entry_for_classifier(classifier)
			if not classifier_entry.is_empty():
				entries.append(classifier_entry)
	return entries


static func _entry_for_area(area: AbstractCorticalArea) -> Dictionary:
	var label := String(area.friendly_name).strip_edges()
	if label.is_empty():
		return {}
	return _entry(label, kind_for_cortical_type(area.cortical_type), area)


static func _entry_for_region(region: BrainRegion) -> Dictionary:
	var label := String(region.friendly_name).strip_edges()
	if label.is_empty():
		return {}
	return _entry(label, KIND_CIRCUIT, region)


static func _entry_for_rule(morphology: BaseMorphology) -> Dictionary:
	if morphology is NullMorphology:
		return {}
	var label := String(morphology.name).strip_edges()
	if label.is_empty():
		return {}
	return _entry(label, KIND_RULE, morphology)


static func _entry_for_classifier(classifier: GenomeClassifier) -> Dictionary:
	var label := String(classifier.friendly_name).strip_edges()
	if label.is_empty():
		return {}
	return _entry(label, KIND_CLASSIFIER, classifier)


static func _entry(label: String, kind: StringName, payload: Variant) -> Dictionary:
	return {
		KEY_LABEL: label,
		KEY_KIND: kind,
		KEY_ACTION: action_for_kind(kind),
		KEY_PAYLOAD: payload,
	}


static func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_label := String(a.get(KEY_LABEL, "")).to_lower()
	var b_label := String(b.get(KEY_LABEL, "")).to_lower()
	if a_label == b_label:
		return kind_title(a.get(KEY_KIND, &"")) < kind_title(b.get(KEY_KIND, &""))
	return a_label < b_label
