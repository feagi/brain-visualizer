extends SceneTree
## Headless test of the modulator form's pure logic (sentence + strength control round trip).
## Run (from godot_source): Godot --headless --path . --script res://tests/modulator_effect/ModulatorEffectTest.gd
## Exits non-zero on any failure.

const Effect = preload("res://BrainVisualizer/UI/Windows/CreateModulator/ModulatorEffect.gd")

var _passed: int = 0
var _failed: int = 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL %s %s" % [name, detail])


func _expect_sentence(raw_type: String, magnitude: float, duration: int, rest: int, graded: bool, full_scale: float, expected_parts: Array[String]) -> void:
	var text := Effect.effect_sentence(raw_type, magnitude, duration, rest, graded, full_scale)
	for part in expected_parts:
		_check("%s %s has '%s'" % [raw_type, magnitude, part], text.contains(part), text)


func _init() -> void:
	_expect_sentence("synaptic.reward", 10, 1, 0, false, 1, ["[b]reward of 10%[/b]", "for [b]1 burst[/b]."])
	_expect_sentence("synaptic.reward", -25, 2, 3, false, 1, ["[b]punishment of 25%[/b]", "for [b]2 bursts[/b]", ", then rest 3 bursts."])
	_expect_sentence("synaptic.transmission_gain", 50, 1, 0, false, 1, ["[b]1.5× as strong[/b]"])
	_expect_sentence("synaptic.transmission_gain", -100, 1, 0, false, 1, ["[b]silenced[/b]"])
	_expect_sentence("synaptic.learning_rate", 50, 1, 1, false, 1, ["[b]1.5× as fast[/b]", ", then rest 1 burst."])
	_expect_sentence("synaptic.gate", 100, 1, 0, false, 1, ["[b]open[/b] (pass signal)", "Otherwise they are closed."])
	_expect_sentence("synaptic.gate", 40, 1, 0, false, 1, ["[b]open at 40%[/b]"])
	_expect_sentence("neuro.firing_threshold", -30, 1, 0, false, 1, ["subscribed areas' firing threshold is [b]lowered by 30%[/b]"])
	_expect_sentence("neuro.leak", 20, 1, 0, false, 1, ["leak is [b]raised by 20%[/b]"])
	_expect_sentence("neuro.firing_probability", 20, 1, 0, true, 2.5, ["firing probability is [b]raised by 20%[/b]", "Scaled by how strongly the trigger fires (full at charge 2.5)."])
	_expect_sentence("memory.formation", -100, 1, 0, false, 1, ["subscribed areas form [b]no new memories[/b]"])
	_check("no rest text at cooldown 0", not Effect.effect_sentence("synaptic.reward", 10, 1, 0, false, 1).contains("rest"))
	_check("unknown type", Effect.effect_sentence("x.y", 1, 1, 0, false, 1) == "Effect depends on the modulator type.")
	for info in Effect.TYPES:
		var raw_type := str(info["type"])
		for magnitude in [-100.0, -37.5, 0.0, 10.0, 50.0, 123.45, 300.0]:
			var control := Effect.magnitude_to_control(raw_type, magnitude)
			var back := Effect.control_to_magnitude(raw_type, bool(control["raising"]), float(control["amount"]))
			_check("round trip %s %s" % [raw_type, magnitude], is_equal_approx(back, magnitude), str(back))
		var default_control := Effect.magnitude_to_control(raw_type, Effect.default_magnitude(raw_type))
		_check("default %s sentence" % raw_type, not Effect.effect_sentence(raw_type, Effect.default_magnitude(raw_type), 1, 0, false, 1).is_empty())
		_check("default %s amount" % raw_type, float(default_control["amount"]) >= 0.0)
	_check("gain 1.5x -> 50", Effect.control_to_magnitude("synaptic.transmission_gain", true, 1.5) == 50.0)
	_check("threshold lower 20 -> -20", Effect.control_to_magnitude("neuro.firing_threshold", false, 20.0) == -20.0)
	_check("reward punishment 10 -> -10", Effect.control_to_magnitude("synaptic.reward", false, 10.0) == -10.0)
	_check("list label positive reward", Effect.list_type_label("synaptic.reward", 10.0) == "Reward")
	_check("list label zero reward", Effect.list_type_label("synaptic.reward", 0.0) == "Reward")
	_check("list label negative reward", Effect.list_type_label("synaptic.reward", -25.0) == "Punishment")
	_check("list label other type keeps raw", Effect.list_type_label("synaptic.transmission_gain", -50.0) == "synaptic.transmission_gain")
	print("modulator_effect: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
