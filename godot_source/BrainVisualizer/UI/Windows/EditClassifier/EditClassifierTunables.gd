extends RefCounted
class_name EditClassifierTunables
## Field contract for the Edit Classifier expandable tunable sections.
## Mirrors Cortical Area Details memory keys and associative mapping plasticity keys.
## Kept free of FeagiCore so headless `-s` tests can compile it.

const SECTION_KERNEL_MEMORY: String = "Sample Memory Area"
const SECTION_CLASS_MEMORY: String = "Class Memory Area"
const SECTION_ASSOCIATIVE: String = "Associative Memory Parameters"
const SECTION_REWARD: String = "Reward Training"

const MEMORY_FIELD_SPECS: Array[Dictionary] = [
	{"key": "neuron_init_lifespan", "label": "Initial Neuron Lifespan", "kind": "int", "min": 1, "default": 1, "property": "initial_neuron_lifespan", "tooltip": "Bursts a new memory neuron survives before it is removed, unless it is activated again. The same setting exists on sample memory and on class memory."},
	{"key": "neuron_lifespan_growth_rate", "label": "Lifespan Growth Rate", "kind": "int", "min": 1, "default": 1, "property": "lifespan_growth_rate", "tooltip": "Extra bursts added to a memory neuron's lifespan each time that pattern is seen again. A higher rate keeps a repeated pattern alive longer before long-term conversion."},
	{"key": "neuron_longterm_mem_threshold", "label": "Longterm Memory Threshold", "kind": "int", "min": 1, "default": 1, "property": "longterm_memory_threshold", "tooltip": "Lifespan, in bursts, at which a memory neuron becomes long-term. Recall replays long-term sample neurons onto the class outputs."},
	{"key": "temporal_depth", "label": "Temporal Depth", "kind": "int", "min": 1, "default": 1, "property": "temporal_depth", "tooltip": "How many bursts of the incoming pattern are stacked into one memory. This is the pattern's time depth, not the delay before an answer is graded. It must be no longer than the trainer's ticks per sample, or the hold ends before the stack is full."},
	{"key": "mp_learning_enabled", "label": "MP Learning", "kind": "bool", "property": "mp_learning_enabled", "tooltip": "Store the membrane potential that was present when the pattern was encoded, and restore it on replay. Off stores only which voxels fired."},
]

## Extra fields only the class memory area offers. They live in the area's firing parameters,
## not its memory parameters, and 0 is a valid stored value.
const CLASS_MEMORY_EXTRA_FIELD_SPECS: Array[Dictionary] = [
	{"key": "neuron_fire_threshold", "label": "Firing Threshold", "kind": "float", "min": 0.0, "default": 0, "allow_zero": true, "source": "firing", "property": "neuron_fire_threshold", "tooltip": "Membrane potential a class memory neuron must reach before it fires from learned associative input. Raise it so a class fires only after the sample-to-class synapse weight has built up, not on the first weak association."},
]

const WINDOW_CONTENT_WIDTH: int = 640
const AREA_EXPLORER_BUTTON_TOOLTIP: String = "Open Cortical Area Explorer and pick an area from any circuit."
const CLASSIFIER_GUIDE_FILE: String = "integrated_circuits.md"
const CLASSIFIER_GUIDE_HEADING: String = "Edit a Classifier"
const BOTTOM_HUD_CLEARANCE_PX: int = 8

const ASSOCIATIVE_FIELD_SPECS: Array[Dictionary] = [
	{"key": "plasticity_window", "label": "Plasticity Window", "kind": "int", "min": 1, "default": 1, "tooltip": "Bursts of co-activity used when reward learning is off and the associative mapping learns by spike timing. With reward learning on, FEAGI sets the eligibility window from the classifier's answer delay instead."},
	{"key": "plasticity_constant", "label": "Plasticity Constant", "kind": "float", "default": 1, "tooltip": "Base size of one weight step on the associative mapping. With reward learning on, a Reward modulator commits LTP steps and a Punishment modulator LTD steps."},
	{"key": "ltp_multiplier", "label": "LTP Multiplier", "kind": "float", "default": 1, "tooltip": "Scale of one strengthening step. With reward learning on, links active while a Reward modulator fires are strengthened by this step. With it off, it scales co-activation potentiation."},
	{"key": "ltd_multiplier", "label": "LTD Multiplier", "kind": "float", "default": 1, "tooltip": "Scale of one weakening step. With reward learning on, links active while a Punishment modulator fires are weakened by this step."},
	{"key": "synaptic_delay_bursts", "label": "Synaptic Delay", "kind": "int", "min": 1, "default": 1, "tooltip": "Bursts a spike waits on the sample-memory to class-memory mapping before it arrives. Minimum is 1. This does not choose which earlier decision an answer grades."},
]

## Labels and tooltips for classifier fields that are not memory or mapping keys.
const SETTING_TOOLTIPS: Dictionary = {
	"Classifier ID": "Stable id of this classifier in the genome. It is not a cortical area and cannot be edited.",
	"Classifier Name": "Name shown on the classifier stamp. Sample memory, class memory, the error and correct areas, and its answer modulators are named from this.",
	"Parent Circuit": "Brain region that contains this classifier. The classifier itself is not a region and is not exported as a circuit.",
	"3D Position": "Voxel position of the classifier stamp. Sample memory hosts the stamp. Class memory stays hidden at the same position.",
	"Sample Inputs": "Areas mapped to sample memory with Classifier Sample. Several inputs are hashed together as one pattern. Connect them with Quick Connect.",
	"Class Outputs": "One output per class input. FEAGI creates it when you map that input with Classifier Class, and its shape matches the class input.",
	"Error Area": "1x1x1 area owned by this classifier. It fires on the next burst when a class output disagrees with its class input from the classifier's answer delay earlier, or when one class output has more than one neuron firing. It drives the classifier's \"error\" Punishment modulator.",
	"Correct Area": "1x1x1 area owned by this classifier. It fires on the next burst when every class input that fired, the classifier's answer delay earlier, is answered by its class output with no error. It drives the classifier's \"correct answer\" Reward modulator.",
	"Sample Memory Neurons": "Memory neurons currently stored for samples. The count is short-term plus long-term.",
	"Class Memory Neurons": "Memory neurons currently stored for classes. The count is short-term plus long-term.",
	"Learn from right/wrong answers": "When on, the sample-to-class memory link learns with reward-modulated STDP from the Reward and Punishment modulators below. The classifier's own correct-answer and error modulators are selected when it is first turned on.",
	"Reward": "Reward modulators (positive strength) the classifier learns from. While one fires, the links that were active are strengthened. Its own correct-answer modulator fires when it answers right and is selected when reward learning is first turned on. Change a modulator's strength in the Modulators window.",
	"Punishment": "Reward modulators with negative strength the classifier learns from. While one fires, the links that were active are weakened. Its own error modulator fires when it answers wrong and is selected when reward learning is first turned on. Change a modulator's strength in the Modulators window.",
	"Correct answer from": "Area that fires the correct class during training. Pick an existing area. It is not created for you.",
	"Answer delay (bursts)": "Bursts between the decision and the correct answer that grades it. 0 grades the same burst. Set this to the number of synaptic hops from the image area to the classifier field. The trainer hold, in ticks per sample, must be longer than this or the answer lands on the next image.",
	"Learn only while this fires": "Optional training gate. Weights change only on bursts where this area fires. None learns on every graded burst. The trainer fires it on the train split and leaves it quiet for validation and test.",
	"Confidence output": "Optional. Receives one value per class showing how far each class link sits above the firing threshold. To read it in a trainer, map this area onward to an OPU and select that output as the trainer decoder.",
}


static func section_titles() -> PackedStringArray:
	return PackedStringArray([SECTION_KERNEL_MEMORY, SECTION_CLASS_MEMORY, SECTION_ASSOCIATIVE, SECTION_REWARD])


static func memory_feagi_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for spec in MEMORY_FIELD_SPECS:
		keys.append(String(spec["key"]))
	return keys


const SECTION_TOOLTIPS: Dictionary = {
	SECTION_KERNEL_MEMORY: "Lifecycle of the neurons that store sample patterns. Temporal depth is how many bursts of the pattern are stacked.",
	SECTION_CLASS_MEMORY: "Lifecycle of the neurons that store class patterns. A firing class-memory neuron replays its stored frame onto the paired class output.",
	SECTION_ASSOCIATIVE: "The sample-memory to class-memory mapping. The window, constant, and multipliers stay on this edge. Synaptic delay is the wait on this mapping.",
	SECTION_REWARD: "Grades each decision against the correct answer so right answers strengthen the class link and wrong ones weaken it. Applies separately from the associative mapping.",
}


static func section_tooltip(title: String) -> String:
	return wrap_tooltip(String(SECTION_TOOLTIPS.get(title, "")))


const TOOLTIP_COLUMNS: int = 52


## Default tooltips do not autowrap. Break on spaces so a description stays in a narrow column.
static func wrap_tooltip(text: String, columns: int = TOOLTIP_COLUMNS) -> String:
	var paragraphs: PackedStringArray = text.split("\n")
	var wrapped: PackedStringArray = PackedStringArray()
	for paragraph in paragraphs:
		wrapped.append(_wrap_tooltip_paragraph(paragraph.strip_edges(), columns))
	return "\n".join(wrapped)


static func _wrap_tooltip_paragraph(paragraph: String, columns: int) -> String:
	if paragraph.is_empty():
		return ""
	var words: PackedStringArray = paragraph.split(" ", false)
	var lines: PackedStringArray = PackedStringArray()
	var current := ""
	for word in words:
		if current.is_empty():
			current = word
		elif current.length() + 1 + word.length() <= columns:
			current += " " + word
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return "\n".join(lines)


static func setting_tooltip(label: String) -> String:
	return wrap_tooltip(String(SETTING_TOOLTIPS.get(label, "")))


static func associative_feagi_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for spec in ASSOCIATIVE_FIELD_SPECS:
		keys.append(String(spec["key"]))
	return keys


## Numeric tunables default to 1. Zero is treated as unset, not a valid stored default.
static func spec_numeric_default(spec: Dictionary) -> Variant:
	if String(spec.get("kind", "int")) == "float":
		return float(spec.get("default", 1))
	return int(spec.get("default", 1))


static func numeric_or_default(value: Variant, spec: Dictionary) -> Variant:
	var default_value: Variant = spec_numeric_default(spec)
	if value == null:
		return default_value
	if bool(spec.get("allow_zero", false)):
		return value
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		if is_zero_approx(float(value)):
			return default_value
	return value


## Specs shown for a memory section: sample memory gets the shared set, class memory adds the extras.
static func memory_specs_for_section(section: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = MEMORY_FIELD_SPECS.duplicate()
	if section == SECTION_CLASS_MEMORY:
		specs.append_array(CLASS_MEMORY_EXTRA_FIELD_SPECS)
	return specs


static func memory_update_payload(values: Dictionary, specs: Array[Dictionary] = MEMORY_FIELD_SPECS) -> Dictionary:
	var payload: Dictionary = {}
	for spec in specs:
		var key: String = String(spec["key"])
		if values.has(key):
			payload[key] = values[key]
	return payload


## Usable height under the top bar and above the bottom mouse-context HUD.
static func available_window_height(viewport_height: int, top_bar_bottom_y: int, mouse_context_height: int, mouse_context_margin: int) -> int:
	var reserved_bottom: int = mouse_context_height + (mouse_context_margin * 2) + BOTTOM_HUD_CLEARANCE_PX
	return maxi(0, viewport_height - top_bar_bottom_y - reserved_bottom)


## Content height when it fits; otherwise the usable BV height. No inner scroll.
static func fitted_window_height(content_height: int, available_height: int) -> int:
	return mini(maxi(content_height, 0), maxi(available_height, 0))


## Keep the fitted window inside the usable vertical band.
static func fitted_window_top(current_top: int, window_height: int, band_top: int, band_bottom: int) -> int:
	var top: int = maxi(current_top, band_top)
	if top + window_height > band_bottom:
		top = band_bottom - window_height
	if top < band_top:
		top = band_top
	return top


## Dropdown text for a cortical area: name plus voxel size, matching the classifier area menus.
static func cortical_area_choice_label(friendly_name: String, dimensions: Vector3i) -> String:
	return "%s %sx%sx%s" % [friendly_name, dimensions.x, dimensions.y, dimensions.z]


## Adds [param area_id] to every shared dropdown when it is not already listed.
## Returns the index in [param area_ids], or -1 when [param area_id] is empty.
static func ensure_shared_area_choice(area_ids: Array[StringName], area_id: StringName, label: String, options: Array) -> int:
	if area_id == &"":
		return -1
	var existing: int = area_ids.find(area_id)
	if existing >= 0:
		return existing
	area_ids.append(area_id)
	for option in options:
		if option is OptionButton:
			(option as OptionButton).add_item(label)
	return area_ids.size() - 1


## Match Cortical Area Details: source art is 486x256, so the control must ignore texture size.
## Splits applied reward sources by modulator sign: negative ones are Punishment, the rest Reward.
## [param magnitudes]: modulator id -> magnitude_percent. Unknown ids count as Reward.
static func split_sources_by_sign(ids: Array[String], magnitudes: Dictionary) -> Dictionary:
	var reward: Array[String] = []
	var punishment: Array[String] = []
	for id in ids:
		if float(magnitudes.get(id, 0.0)) < 0.0:
			punishment.append(id)
		else:
			reward.append(id)
	return {"reward": reward, "punishment": punishment}


## Reward sources shown when the classifier has none applied yet: its own correct-answer and
## error modulators from the answer-modulators response, which the server also falls back to.
static func default_sources(applied: Array[String], answer_modulators: Dictionary) -> Array[String]:
	if not applied.is_empty():
		return applied.duplicate()
	var ids: Array[String] = []
	for key in ["correct_answer", "error"]:
		var id: String = str(answer_modulators.get(key, ""))
		if not id.is_empty():
			ids.append(id)
	ids.sort()
	return ids


## True when the chips hold a different set of sources than [param applied]. Order is ignored.
static func sources_changed(selected: Array[String], applied: Array[String]) -> bool:
	var a: Array[String] = selected.duplicate()
	var b: Array[String] = applied.duplicate()
	a.sort()
	b.sort()
	return a != b


static func configure_theme_toggle(toggle: TextureButton) -> void:
	toggle.theme_type_variation = &"ToggleButton"
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_SCALE
	toggle.custom_minimum_size = Vector2(60, 0)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_FILL


## Active memory neurons are partitioned into short-term and long-term; total is ST + LT.
static func memory_neuron_total(short_term_count: int, long_term_count: int) -> int:
	return short_term_count + long_term_count


## Same neuron-count readout as Cortical Area Details for a memory area: "12 (ST: 4 | LT: 8)".
static func memory_count_display(total_count: int, short_term_count: int, long_term_count: int) -> String:
	return format_compact_count(total_count) + memory_count_suffix(short_term_count, long_term_count)


static func memory_count_suffix(short_term_count: int, long_term_count: int) -> String:
	return " (ST: %s | LT: %s)" % [format_compact_count(short_term_count), format_compact_count(long_term_count)]


static func memory_count_tooltip(total_count: int, short_term_count: int, long_term_count: int) -> String:
	return "Total neurons: %s\nShort-term neurons: %s\nLong-term neurons: %s" % [
		format_int_with_commas(total_count),
		format_int_with_commas(short_term_count),
		format_int_with_commas(long_term_count),
	]


static func format_compact_count(value: int) -> String:
	var abs_value: int = absi(value)
	if abs_value >= 1000000000:
		return _compact_with_unit(value, 1000000000.0, "B")
	if abs_value >= 1000000:
		return _compact_with_unit(value, 1000000.0, "M")
	if abs_value >= 1000:
		return _compact_with_unit(value, 1000.0, "K")
	return str(value)


static func format_int_with_commas(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var parts: PackedStringArray = PackedStringArray()
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	var joined: String = ",".join(parts)
	return "-" + joined if negative else joined


static func _compact_with_unit(value: int, divisor: float, unit: String) -> String:
	var scaled: float = float(value) / divisor
	var rounded_1: float = roundf(scaled * 10.0) / 10.0
	var rounded_0: int = int(roundf(rounded_1))
	if is_equal_approx(rounded_1, float(rounded_0)):
		return str(rounded_0) + unit
	return str(rounded_1) + unit


static func apply_associative_overrides(mapping_json: Dictionary, overrides: Dictionary) -> Dictionary:
	var patched: Dictionary = mapping_json.duplicate(true)
	for spec in ASSOCIATIVE_FIELD_SPECS:
		var key: String = String(spec["key"])
		if overrides.has(key):
			patched[key] = overrides[key]
	patched["plasticity_flag"] = true
	return patched
