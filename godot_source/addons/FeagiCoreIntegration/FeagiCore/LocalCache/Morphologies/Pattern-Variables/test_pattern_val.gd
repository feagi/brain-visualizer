extends SceneTree
## PatternVal must keep N..M and refuse unknown tokens instead of writing 0.

const PatternValScript = preload("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Morphologies/Pattern-Variables/PatternVal.gd")
const PatternVector3Script = preload("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Morphologies/Pattern-Variables/PatternVector3.gd")
const PatternVector3PairsScript = preload("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Morphologies/Pattern-Variables/PatternVector3Pairs.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_absolute_range_stays_range()
	failures += _test_exact_int_stays_int()
	failures += _test_unknown_string_is_invalid_not_zero()
	failures += _test_empty_string_is_invalid()
	failures += _test_array_is_invalid_not_zero()
	failures += _test_feagi_token_range_is_string()
	failures += _test_reject_reason_on_invalid_pair()
	if failures == 0:
		print("PatternVal tests: PASS")
		quit(0)
	else:
		push_error("PatternVal tests: FAIL (%d)" % failures)
		quit(1)


func _test_absolute_range_stays_range() -> int:
	var pv: Variant = PatternValScript.new("10..33")
	if !pv.is_parse_valid:
		push_error("10..33 must parse")
		return 1
	if pv.isInt:
		push_error("10..33 must not become an int")
		return 1
	if str(pv.data) != "10..33":
		push_error("10..33 data lost, got %s" % str(pv.data))
		return 1
	return 0


func _test_exact_int_stays_int() -> int:
	var pv: Variant = PatternValScript.new(241)
	if !pv.is_parse_valid or !pv.isInt or int(pv.data) != 241:
		push_error("241 must stay exact int")
		return 1
	return 0


func _test_unknown_string_is_invalid_not_zero() -> int:
	var pv: Variant = PatternValScript.new("not-a-token")
	if pv.is_parse_valid:
		push_error("unknown token must be invalid")
		return 1
	if pv.to_feagi_token() != null:
		push_error("invalid token must not emit a FEAGI value")
		return 1
	return 0


func _test_empty_string_is_invalid() -> int:
	var pv: Variant = PatternValScript.new("")
	if pv.is_parse_valid:
		push_error("empty string must be invalid")
		return 1
	return 0


func _test_array_is_invalid_not_zero() -> int:
	var pv: Variant = PatternValScript.new([0, 7])
	if pv.is_parse_valid:
		push_error("array token must be invalid")
		return 1
	return 0


func _test_feagi_token_range_is_string() -> int:
	var pv: Variant = PatternValScript.new("0..7")
	var token: Variant = pv.to_feagi_token()
	if typeof(token) != TYPE_STRING or String(token) != "0..7":
		push_error("0..7 FEAGI token must be a String, got %s" % str(token))
		return 1
	return 0


func _test_reject_reason_on_invalid_pair() -> int:
	var src: Variant = PatternVector3Script.new(
		PatternValScript.new("0..7"),
		PatternValScript.new("*"),
		PatternValScript.new("*"),
	)
	var dst: Variant = PatternVector3Script.new(
		PatternValScript.new("?"),
		PatternValScript.new("?"),
		PatternValScript.create_invalid(),
	)
	var pair: Variant = PatternVector3PairsScript.new(src, dst)
	var patterns: Array = [pair]
	var reason: StringName = PatternVector3PairsScript.reject_reason_if_any_token_invalid(patterns)
	if reason != &"INVALID_PATTERN_TOKEN":
		push_error("invalid dest token must reject the save")
		return 1
	var good_dst: Variant = PatternVector3Script.new(
		PatternValScript.new("?"),
		PatternValScript.new("?"),
		PatternValScript.new(0),
	)
	var good_pair: Variant = PatternVector3PairsScript.new(src, good_dst)
	if PatternVector3PairsScript.reject_reason_if_any_token_invalid([good_pair]) != &"":
		push_error("valid N..M row must be allowed")
		return 1
	return 0
