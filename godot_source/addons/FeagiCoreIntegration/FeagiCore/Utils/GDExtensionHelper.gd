## Helper class to check GDExtension availability
## Web builds don't support GDExtensions, so this provides graceful fallbacks
class_name GDExtensionHelper

## Check if FeagiCorticalType is available (from feagi_type_system GDExtension)
static func is_feagi_cortical_type_available() -> bool:
	if OS.has_feature("web"):
		return false  # Web builds don't support GDExtensions
	return ClassDB.class_exists("FeagiCorticalType")

## Check if FeagiCorticalTypeFactory is available
static func is_feagi_cortical_type_factory_available() -> bool:
	if OS.has_feature("web"):
		return false  # Web builds don't support GDExtensions
	return ClassDB.class_exists("FeagiCorticalTypeFactory")

## Check if any GDExtension types are available
static func are_gdextensions_available() -> bool:
	if OS.has_feature("web"):
		return false  # Web builds don't support GDExtensions
	return is_feagi_cortical_type_available() or is_feagi_cortical_type_factory_available()

