extends RefCounted
class_name EditClassifierTunables
## Field contract for the Edit Classifier expandable tunable sections.
## Mirrors Cortical Area Details memory keys and associative mapping plasticity keys.
## Kept free of FeagiCore so headless `-s` tests can compile it.

const SECTION_KERNEL_MEMORY: String = "Kernel Memory Area"
const SECTION_CLASS_MEMORY: String = "Class Memory Area"
const SECTION_ASSOCIATIVE: String = "Associative Memory Parameters"

const MEMORY_FIELD_SPECS: Array[Dictionary] = [
	{"key": "neuron_init_lifespan", "label": "Initial Neuron Lifespan", "kind": "int", "min": 1, "default": 1, "property": "initial_neuron_lifespan"},
	{"key": "neuron_lifespan_growth_rate", "label": "Lifespan Growth Rate", "kind": "int", "min": 1, "default": 1, "property": "lifespan_growth_rate"},
	{"key": "neuron_longterm_mem_threshold", "label": "Longterm Memory Threshold", "kind": "int", "min": 1, "default": 1, "property": "longterm_memory_threshold"},
	{"key": "temporal_depth", "label": "Temporal Depth", "kind": "int", "min": 1, "default": 1, "property": "temporal_depth"},
	{"key": "mp_learning_enabled", "label": "MP Learning", "kind": "bool", "property": "mp_learning_enabled"},
]

const WINDOW_CONTENT_WIDTH: int = 640
const BOTTOM_HUD_CLEARANCE_PX: int = 8

const ASSOCIATIVE_FIELD_SPECS: Array[Dictionary] = [
	{"key": "plasticity_window", "label": "Plasticity Window", "kind": "int", "min": 1, "default": 1},
	{"key": "plasticity_constant", "label": "Plasticity Constant", "kind": "float", "default": 1},
	{"key": "ltp_multiplier", "label": "LTP Multiplier", "kind": "float", "default": 1},
	{"key": "ltd_multiplier", "label": "LTD Multiplier", "kind": "float", "default": 1},
]


static func section_titles() -> PackedStringArray:
	return PackedStringArray([SECTION_KERNEL_MEMORY, SECTION_CLASS_MEMORY, SECTION_ASSOCIATIVE])


static func memory_feagi_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for spec in MEMORY_FIELD_SPECS:
		keys.append(String(spec["key"]))
	return keys


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
