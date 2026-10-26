extends RefCounted
## Pure logic of the modulator form: type table, strength control <-> magnitude_percent, effect sentence.
## Semantics follow feagi-core (genomic/modulator.rs): signal = magnitude_percent / 100 (times charge/full-scale
## when graded) while the trigger fires, else 0. Gain, learning rate, threshold, leak and firing probability
## scale their baseline by (1 + signal); leak and firing probability are then clamped to 0..1. Reward adds
## signal to the mapping's reward. Gate passes transmission * signal while open and 0 while closed.
## Memory formation (memory areas) scales new-memory formation by clamp(1 + signal, 0, 1): 0x stops new memory neurons.
## The server only requires magnitude_percent >= -100 (no upper bound).

## How the Strength control looks: "reward" (Reward | Punishment + %), "multiplier" (0x-3x slider),
## "gate" (% of signal passed while open), "adjust" (Lower | Raise + %).
const CONTROL_REWARD: String = "reward"
const CONTROL_MULTIPLIER: String = "multiplier"
const CONTROL_GATE: String = "gate"
const CONTROL_ADJUST: String = "adjust"

## Friendly label, name prefix, one-line [desc], long [hint] (tooltip), [scope] and [control] per FEAGI type.
## [default] is the magnitude_percent applied in create mode. The raw "type" string is what FEAGI receives.
const TYPES: Array[Dictionary] = [
	{"type": "synaptic.reward", "label": "Reward / punishment", "prefix": "reward", "scope": "mapping", "control": CONTROL_REWARD, "default": 10.0,
		"desc": "Teaches subscribed mappings: reward or punish.",
		"hint": "Adds a reward (positive %) or punishment (negative %) signal to the reward-based plasticity of subscribed mappings."},
	{"type": "synaptic.transmission_gain", "label": "Gain", "prefix": "gain", "scope": "mapping", "control": CONTROL_MULTIPLIER, "default": 50.0,
		"desc": "Makes subscribed mappings pass stronger or weaker signal.",
		"hint": "Scales how strongly subscribed mappings pass signal (multiplier on their synaptic strength)."},
	{"type": "synaptic.gate", "label": "Gate", "prefix": "gate", "scope": "mapping", "control": CONTROL_GATE, "default": 100.0,
		"desc": "Subscribed mappings pass signal only while open.",
		"hint": "Subscribed mappings are closed (no signal) unless the trigger fires; then they pass the chosen share of their signal."},
	{"type": "synaptic.learning_rate", "label": "Learning rate", "prefix": "learning_rate", "scope": "mapping", "control": CONTROL_MULTIPLIER, "default": 50.0,
		"desc": "Speeds up or slows down learning on subscribed mappings.",
		"hint": "Multiplies the plasticity rate (eta) of subscribed mappings."},
	{"type": "neuro.firing_threshold", "label": "Firing threshold", "prefix": "firing_threshold", "scope": "area", "control": CONTROL_ADJUST, "default": -20.0,
		"desc": "Makes subscribed areas fire more or less easily.",
		"hint": "Raises or lowers the firing threshold of subscribed areas (threshold x (1 + change))."},
	{"type": "neuro.leak", "label": "Leak", "prefix": "leak", "scope": "area", "control": CONTROL_ADJUST, "default": 20.0,
		"desc": "Changes the leak of subscribed areas.",
		"hint": "Scales the leak coefficient of subscribed areas (result is kept between 0 and 1)."},
	{"type": "neuro.firing_probability", "label": "Firing probability", "prefix": "firing_probability", "scope": "area", "control": CONTROL_ADJUST, "default": 20.0,
		"desc": "Changes how likely subscribed areas are to fire.",
		"hint": "Scales the firing probability of subscribed areas (result is kept between 0 and 1)."},
	{"type": "memory.formation", "label": "Memory formation", "prefix": "memory_formation", "scope": "area", "control": CONTROL_MULTIPLIER, "default": -100.0,
		"desc": "Stops subscribed memory areas from forming new memories.",
		"hint": "Subscribed memory areas form no new memory neurons while the trigger fires at 0x. Existing memories still fire and age."},
]


## Table row for a raw type string; unknown types show the raw string with an area-less, generic row.
static func type_info(raw_type: String) -> Dictionary:
	for info in TYPES:
		if info["type"] == raw_type:
			return info
	return {"type": raw_type, "label": raw_type, "prefix": "modulator", "scope": "", "control": CONTROL_ADJUST, "default": 0.0, "desc": "", "hint": ""}


static func control_kind(raw_type: String) -> String:
	return str(type_info(raw_type)["control"])


static func default_magnitude(raw_type: String) -> float:
	return float(type_info(raw_type)["default"])


## Strength control -> magnitude_percent. [param raising] is Reward / Raise (ignored for multiplier and gate);
## [param amount] is a percent, except for multipliers where it is the multiplier (1.5 = 1.5x).
static func control_to_magnitude(raw_type: String, raising: bool, amount: float) -> float:
	match control_kind(raw_type):
		CONTROL_MULTIPLIER:
			return snappedf((amount - 1.0) * 100.0, 0.0001)
		CONTROL_GATE:
			return amount
		_:
			return amount if raising else -amount


## magnitude_percent -> Strength control: {"raising": bool, "amount": float}. Inverse of [method control_to_magnitude].
static func magnitude_to_control(raw_type: String, magnitude_percent: float) -> Dictionary:
	match control_kind(raw_type):
		CONTROL_MULTIPLIER:
			return {"raising": true, "amount": snappedf(1.0 + magnitude_percent / 100.0, 0.000001)}
		CONTROL_GATE:
			return {"raising": true, "amount": magnitude_percent}
		_:
			return {"raising": magnitude_percent >= 0.0, "amount": absf(magnitude_percent)}


## "1 burst" / "3 bursts".
static func bursts(count: int) -> String:
	return "%d burst%s" % [count, "" if count == 1 else "s"]


static func _num(value: float) -> String:
	var text := "%.2f" % value
	return text.rstrip("0").rstrip(".")


## BBCode sentence saying what the modulator does. [param full_scale] is only used when [param graded].
static func effect_sentence(raw_type: String, magnitude_percent: float, duration: int, rest: int, graded: bool, full_scale: float) -> String:
	var info := type_info(raw_type)
	var subject := "subscribed areas" if str(info["scope"]) == "area" else "subscribed mappings"
	var change := ""
	var amount := absf(magnitude_percent)
	var multiplier := 1.0 + magnitude_percent / 100.0
	match raw_type:
		"synaptic.reward":
			if is_zero_approx(magnitude_percent):
				change = "get [b]no reward[/b]"
			elif magnitude_percent > 0.0:
				change = "get a [b]reward of %s%%[/b]" % _num(amount)
			else:
				change = "get a [b]punishment of %s%%[/b]" % _num(amount)
		"synaptic.transmission_gain":
			if is_zero_approx(multiplier):
				change = "are [b]silenced[/b]"
			else:
				change = "pass signal [b]%s× as strong[/b]" % _num(multiplier)
		"synaptic.learning_rate":
			if is_zero_approx(multiplier):
				change = "[b]stop learning[/b]"
			else:
				change = "learn [b]%s× as fast[/b]" % _num(multiplier)
		"synaptic.gate":
			if is_zero_approx(magnitude_percent):
				change = "stay [b]closed[/b]"
			elif is_equal_approx(magnitude_percent, 100.0):
				change = "are [b]open[/b] (pass signal)"
			else:
				change = "are [b]open at %s%%[/b] (pass %s%% of their signal)" % [_num(magnitude_percent), _num(magnitude_percent)]
		"memory.formation":
			if is_zero_approx(multiplier):
				change = "form [b]no new memories[/b]"
			else:
				change = "form new memories [b]as usual[/b]"
		"neuro.firing_threshold", "neuro.leak", "neuro.firing_probability":
			var what := "firing threshold" if raw_type == "neuro.firing_threshold" else ("leak" if raw_type == "neuro.leak" else "firing probability")
			if is_zero_approx(magnitude_percent):
				change = "%s is [b]unchanged[/b]" % what
			else:
				change = "%s is [b]%s by %s%%[/b]" % [what, "raised" if magnitude_percent > 0.0 else "lowered", _num(amount)]
			subject = "subscribed areas'"
		_:
			return "Effect depends on the modulator type."
	var rest_part := ", then rest %s" % bursts(rest) if rest > 0 else ""
	var text := "When its trigger fires, %s %s for [b]%s[/b]%s." % [subject, change, bursts(duration), rest_part]
	if raw_type == "synaptic.gate":
		text += " Otherwise they are closed."
	if graded:
		text += " Scaled by how strongly the trigger fires (full at charge %s)." % _num(full_scale)
	return text
