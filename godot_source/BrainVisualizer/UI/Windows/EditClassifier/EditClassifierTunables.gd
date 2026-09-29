extends RefCounted
class_name EditClassifierTunables
## Field contract for the Edit Classifier expandable tunable sections.
## Mirrors Cortical Area Details memory keys and associative mapping plasticity keys.
## Kept free of FeagiCore so headless `-s` tests can compile it.

const SECTION_KERNEL_MEMORY: String = "Kernel Memory Area"
const SECTION_CLASS_MEMORY: String = "Class Memory Area"
const SECTION_ASSOCIATIVE: String = "Associative Memory Parameters"

const MEMORY_FIELD_SPECS: Array[Dictionary] = [
	{"key": "neuron_init_lifespan", "label": "Initial Neuron Lifespan", "kind": "int", "min": 1, "default": 1, "property": "initial_neuron_lifespan", "tooltip": "Bursts a new memory neuron survives before it is removed, unless it is activated again. The same setting exists on kernel memory and on class memory."},
	{"key": "neuron_lifespan_growth_rate", "label": "Lifespan Growth Rate", "kind": "int", "min": 1, "default": 1, "property": "lifespan_growth_rate", "tooltip": "Extra bursts added to a memory neuron's lifespan each time that pattern is seen again. A higher rate keeps a repeated pattern alive longer before long-term conversion."},
	{"key": "neuron_longterm_mem_threshold", "label": "Longterm Memory Threshold", "kind": "int", "min": 1, "default": 1, "property": "longterm_memory_threshold", "tooltip": "Lifespan, in bursts, at which a memory neuron becomes long-term. Only long-term kernel neurons are recalled by a scan. Short-term neurons are not."},
	{"key": "temporal_depth", "label": "Temporal Depth", "kind": "int", "min": 1, "default": 1, "property": "temporal_depth", "tooltip": "How many bursts of the incoming pattern are stacked into one memory. This is the pattern's time depth, not the delay before an answer is graded. It must be no longer than the trainer's ticks per sample, or the hold ends before the stack is full."},
	{"key": "mp_learning_enabled", "label": "MP Learning", "kind": "bool", "property": "mp_learning_enabled", "tooltip": "Store the membrane potential that was present when the pattern was encoded, and restore it on replay. Off stores only which voxels fired."},
]

const WINDOW_CONTENT_WIDTH: int = 640
const CLASSIFIER_GUIDE_FILE: String = "integrated_circuits.md"
const CLASSIFIER_GUIDE_HEADING: String = "Edit a Classifier"
const BOTTOM_HUD_CLEARANCE_PX: int = 8

const ASSOCIATIVE_FIELD_SPECS: Array[Dictionary] = [
	{"key": "plasticity_window", "label": "Plasticity Window", "kind": "int", "min": 1, "default": 1, "tooltip": "Bursts of co-activity used when reward training is off and the associative mapping learns by spike timing. It does not hold a decision until a late answer arrives. Use Answer Latency for that."},
	{"key": "plasticity_constant", "label": "Plasticity Constant", "kind": "float", "default": 1, "tooltip": "Base size of one weight step on the associative mapping. The pleasure step is this value times the LTP multiplier. The pain step is this value times the LTD multiplier."},
	{"key": "ltp_multiplier", "label": "LTP Multiplier", "kind": "float", "default": 1, "tooltip": "Scale of one strengthening step. With reward training on, this is the pleasure step for a class channel that matches the answer. With reward training off, it scales co-activation potentiation."},
	{"key": "ltd_multiplier", "label": "LTD Multiplier", "kind": "float", "default": 1, "tooltip": "Scale of one weakening step. With reward training on, this is the pain step for a class channel that does not match the answer, and for every channel of an ambiguous decision when no answer area is connected."},
	{"key": "synaptic_delay_bursts", "label": "Synaptic Delay", "kind": "int", "min": 1, "default": 1, "tooltip": "Bursts a spike waits on the kernel-memory to class-memory mapping before it arrives. Minimum is 1. This does not choose which earlier decision an answer grades. Count this delay on each hop from the image area to the classifier field, and put that total in Answer Latency."},
]

## Labels and tooltips for classifier fields that are not memory or mapping keys.
const SETTING_TOOLTIPS: Dictionary = {
	"Classifier ID": "Stable id of this classifier in the genome. It is not a cortical area and cannot be edited.",
	"Classifier Name": "Name shown on the classifier stamp. Kernel memory, class memory, pain, and pleasure areas are named from this.",
	"Parent Circuit": "Brain region that contains this classifier. The classifier itself is not a region and is not exported as a circuit.",
	"3D Position": "Voxel position of the classifier stamp. Kernel memory hosts the stamp. Class memory stays hidden at the same position.",
	"Training Mode": "Kernel training encodes one kernel sample and one class sample per burst. Scanner training slides the kernel across each connected image field and takes the class from the mask depth under that window.",
	"Kernel Area": "Cortical area encoded into kernel memory. One firing pattern here becomes one kernel memory neuron. Hidden in scanner training, which learns from image-field windows instead.",
	"Class Area": "Cortical area encoded into class memory. Its active voxels are the class channels bound to the kernel. In kernel mode the answer area must have this same shape.",
	"Mask Area": "Scanner label volume. Width and height match each image field. Depth is the class count. An active voxel in that depth is the class of the window that covers it.",
	"Kernel Size": "Scanner window in voxels. Depth must equal the image field depth, and the window must fit inside the field. Changing it drops patterns learned under the previous window.",
	"Kernel Memory Neurons": "Memory neurons currently stored for kernels. The count is short-term plus long-term. Only long-term neurons are recalled when a field is scanned.",
	"Class Memory Neurons": "Memory neurons currently stored for classes. The count is short-term plus long-term.",
	"Reward Training": "Grade each scanning instance on its own. Off keeps ordinary co-activation learning. On, an ambiguous decision (more than one class channel, and no answer area) is pain. With an answer area, a matching channel is pleasure and any other channel is pain. Each pattern is corrected once, then waits until the field pattern changes. A quiet field drops the open decision so the next image is not trained with the previous answer.",
	"Answer Area": "Cortical area that carries the correct class for the instance being graded. It is not a peripheral input. A quiet area is not scored, so a gap before the answer arrives is not pain. Kernel mode must match the class area. Scanner mode must match each detection twin, or be one class for the whole image: the class count on a single axis and 1 on the other two.",
	"Answer Latency": "Bursts between a decision and the answer that grades it. Zero grades the same burst. Set this to the number of synaptic hops from the image area to the classifier field. The trainer hold, in ticks per sample, must be longer than this or the answer lands on the next image.",
	"Learn Area": "Cortical area that must fire before pain or pleasure can change weights. It is not a peripheral input. The trainer stimulates it on the train split and leaves it quiet for validation and test. Empty allows a correction on any burst where reward training has an answer or an ambiguous decision.",
	"Confidence Area": "Cortical area that receives one value per class channel: how far that channel's associative weight sits above the class-memory firing threshold. It is not a peripheral output. To let a trainer read the values, map this area onward to a peripheral output and select that output as the trainer decoder.",
}


static func section_titles() -> PackedStringArray:
	return PackedStringArray([SECTION_KERNEL_MEMORY, SECTION_CLASS_MEMORY, SECTION_ASSOCIATIVE])


static func memory_feagi_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for spec in MEMORY_FIELD_SPECS:
		keys.append(String(spec["key"]))
	return keys


const SECTION_TOOLTIPS: Dictionary = {
	SECTION_KERNEL_MEMORY: "Lifecycle of the neurons that store kernel patterns. A scan recalls only long-term neurons here. Temporal depth is how many bursts of the pattern are stacked, and it must fit inside the trainer sample hold.",
	SECTION_CLASS_MEMORY: "Lifecycle of the neurons that store class patterns. Class channels bound from this memory are what a kernel recall lights.",
	SECTION_ASSOCIATIVE: "The kernel-memory to class-memory mapping. Reward training grades each scanning instance on its own. The window, constant, and multipliers stay in effect either way. Synaptic delay is the wait on this mapping, not the wait before an answer is graded.",
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
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		if is_zero_approx(float(value)):
			return default_value
	return value


static func memory_update_payload(values: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	for spec in MEMORY_FIELD_SPECS:
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


## Match Cortical Area Details: source art is 486x256, so the control must ignore texture size.
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
