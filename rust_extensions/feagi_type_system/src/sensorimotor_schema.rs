/*!
FeagiSensorimotorSchema - Parse device registrations with FEAGI core types.

Uses feagi-sensorimotor JSONInputOutputDefinition to validate registration
payloads and returns a Godot Dictionary with integer values preserved.
*/

use godot::prelude::*;
use godot::builtin::{Dictionary, Variant, GString, Array};
use serde_json::Value;
use serde_json::Deserializer;
use serde_path_to_error;
use feagi_sensorimotor::configuration::jsonable::JSONInputOutputDefinition;

#[derive(GodotClass)]
#[class(base=Object)]
pub struct FeagiSensorimotorSchema {
    #[base]
    base: Base<Object>,
}

#[godot_api]
impl IObject for FeagiSensorimotorSchema {
    fn init(base: Base<Object>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl FeagiSensorimotorSchema {
    /// Parse agent capabilities JSON and preserve integer values.
    #[func]
    pub fn parse_agent_capabilities(&self, json_text: GString) -> Dictionary {
        let raw = json_text.to_string();
        let parsed: Value = match serde_json::from_str(&raw) {
            Ok(value) => value,
            Err(_) => return Dictionary::new(),
        };
        let dict = match parsed {
            Value::Object(_) => parsed,
            _ => return Dictionary::new(),
        };
        self.validate_device_registrations(&dict);
        json_to_dictionary(&dict)
    }

    /// Parse device_registrations JSON and preserve integer values.
    #[func]
    pub fn parse_device_registrations(&self, json_text: GString) -> Dictionary {
        let raw = json_text.to_string();
        let parsed: Value = match serde_json::from_str(&raw) {
            Ok(value) => value,
            Err(_) => return Dictionary::new(),
        };
        let dict = match parsed {
            Value::Object(_) => parsed,
            _ => return Dictionary::new(),
        };
        self.validate_device_registrations(&dict);
        json_to_dictionary(&dict)
    }

    /// Validate agent capabilities against sensorimotor schema.
    #[func]
    pub fn validate_agent_capabilities(&self, json_text: GString) -> Dictionary {
        let raw = json_text.to_string();
        let parsed: Value = match serde_json::from_str(&raw) {
            Ok(value) => value,
            Err(_) => return Dictionary::new(),
        };
        let mut output = Dictionary::new();
        if let Value::Object(map) = parsed {
            for (agent_id, agent_entry) in map {
                let mut errors = Array::<Variant>::new();
                if let Value::Object(agent_obj) = agent_entry {
                    if let Some(registrations) = agent_obj.get("device_registrations") {
                        if let Ok(serialized) = serde_json::to_string(registrations) {
                            let mut deserializer = Deserializer::from_str(&serialized);
                            let result = serde_path_to_error::deserialize::<_, JSONInputOutputDefinition>(
                                &mut deserializer,
                            );
                            if let Err(err) = result {
                                let path = err.path().to_string();
                                let location = if path.is_empty() {
                                    "device_registrations".to_string()
                                } else {
                                    format!("device_registrations.{}", path)
                                };
                                let message = format!("{}: {}", location, err.inner());
                                let message_variant = Variant::from(message.as_str());
                                errors.push(&message_variant);
                            }
                        }
                    }
                }
                if errors.len() > 0 {
                    output.set(GString::from(agent_id.as_str()), Variant::from(errors));
                }
            }
        }
        output
    }

    /// Return the full sensorimotor schema for UI typing.
    #[func]
    pub fn get_schema(&self) -> Dictionary {
        let mut schema = Dictionary::new();
        schema.set("json_input_output_definition", schema_json_input_output_definition());
        schema.set("json_unit_definition", schema_json_unit_definition());
        schema.set("json_device_grouping", schema_json_device_grouping());
        schema.set("json_device_property_value", schema_json_device_property_value());
        schema.set("json_encoder_properties", schema_json_encoder_properties());
        schema.set("json_decoder_properties", schema_json_decoder_properties());
        schema.set("pipeline_stage_properties", schema_pipeline_stage_properties());
        schema.set("image_frame_properties", schema_image_frame_properties());
        schema.set("segmented_image_frame_properties", schema_segmented_image_frame_properties());
        schema.set("gaze_properties", schema_gaze_properties());
        schema.set("image_filtering_settings", schema_image_filtering_settings());
        schema.set("image_frame_processor", schema_image_frame_processor());
        schema
    }

    fn validate_device_registrations(&self, root: &Value) {
        if let Value::Object(map) = root {
            for (_agent_id, agent_entry) in map {
                if let Value::Object(agent_obj) = agent_entry {
                    if let Some(registrations) = agent_obj.get("device_registrations") {
                        let _ = serde_json::from_value::<JSONInputOutputDefinition>(registrations.clone());
                    }
                }
            }
        }
    }
}

fn schema_json_input_output_definition() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "input_units_and_encoder_properties",
        with_description(
            schema_map(
            schema_string(),
            schema_array(schema_tuple(array_from_dicts(&[
                schema_json_unit_definition(),
                schema_json_encoder_properties(),
            ]))),
        ),
            "Map of sensory unit keys to [unit_definition, encoder_properties].",
        ),
    );
    fields.set(
        "output_units_and_decoder_properties",
        with_description(
            schema_map(
            schema_string(),
            schema_array(schema_tuple(array_from_dicts(&[
                schema_json_unit_definition(),
                schema_json_decoder_properties(),
            ]))),
        ),
            "Map of motor unit keys to [unit_definition, decoder_properties].",
        ),
    );
    fields.set(
        "feedbacks",
        with_description(schema_json_value(), "Feedback channels registered by agents."),
    );
    schema_object(fields)
}

fn schema_json_unit_definition() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "friendly_name",
        with_description(
            schema_optional(schema_string()),
            "Optional display name for this unit definition.",
        ),
    );
    fields.set(
        "cortical_unit_index",
        with_description(
            schema_int(0, 255),
            "Unit instance index for the device type.",
        ),
    );
    fields.set(
        "io_configuration_flags",
        with_description(
            schema_map(schema_string(), schema_json_value()),
            "I/O configuration flags used to derive encoding behavior.",
        ),
    );
    fields.set(
        "device_grouping",
        with_description(
            schema_array(schema_json_device_grouping()),
            "Per-channel device definitions for this unit.",
        ),
    );
    schema_object(fields)
}

fn schema_json_device_grouping() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "friendly_name",
        with_description(
            schema_optional(schema_string()),
            "Optional display name for this channel.",
        ),
    );
    fields.set(
        "device_properties",
        with_description(
            schema_map(schema_string(), schema_json_device_property_value()),
            "Device-specific properties used by encoders/decoders.",
        ),
    );
    fields.set(
        "channel_index_override",
        with_description(
            schema_optional(schema_int(0, 4294967295)),
            "Override the generated channel index for this device group.",
        ),
    );
    fields.set(
        "pipeline_stages",
        with_description(
            schema_array(schema_pipeline_stage_properties()),
            "Preprocessing stages applied before encoding/decoding.",
        ),
    );
    schema_object(fields)
}

fn schema_json_device_property_value() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set("String", with_description(schema_string(), "String value."));
    variants.set(
        "Integer",
        with_description(schema_int(i64::MIN, i64::MAX), "Integer value."),
    );
    variants.set(
        "Float",
        with_description(schema_float(f64::MIN, f64::MAX), "Float value."),
    );
    variants.set(
        "Dictionary",
        with_description(
            schema_map(schema_string(), schema_json_value()),
            "Dictionary value.",
        ),
    );
    with_description(
        schema_tagged_union("type", "value", variants),
        "Typed device property value.",
    )
}

fn schema_json_encoder_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set(
        "Boolean",
        with_description(schema_unit(), "Boolean encoder (on/off)."),
    );
    variants.set(
        "CartesianPlane",
        with_description(
            schema_image_frame_properties(),
            "Image frame encoder using cartesian plane encoding.",
        ),
    );
    variants.set(
        "MiscData",
        with_description(
            schema_misc_data_dimensions(),
            "Misc data encoder with explicit dimensions.",
        ),
    );
    variants.set(
        "Percentage",
        with_description(
            schema_tuple(array_from_dicts(&[
                with_description(
                    schema_neuron_depth(),
                    "Neuron depth (z layers) used by the percentage encoder.",
                ),
                with_description(
                    schema_percentage_neuron_positioning(),
                    "How percentage values map to neuron positions.",
                ),
                with_description(schema_bool(), "Enable signed percentage values."),
                with_description(
                    schema_percentage_channel_dimensionality(),
                    "Channel dimensionality for percentage encoding.",
                ),
            ])),
            "Tuple: [neuron_depth, positioning, signed, dimensionality].",
        ),
    );
    variants.set(
        "SegmentedImageFrame",
        with_description(
            schema_segmented_image_frame_properties(),
            "Segmented image frame encoder for multi-region vision.",
        ),
    );
    with_description(
        schema_externally_tagged_enum(variants),
        "Encoder property configuration for this unit.",
    )
}

fn schema_json_decoder_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set(
        "CartesianPlane",
        with_description(
            schema_image_frame_properties(),
            "Image frame decoder using cartesian plane encoding.",
        ),
    );
    variants.set(
        "MiscData",
        with_description(
            schema_misc_data_dimensions(),
            "Misc data decoder with explicit dimensions.",
        ),
    );
    variants.set(
        "Percentage",
        with_description(
            schema_tuple(array_from_dicts(&[
                with_description(
                    schema_neuron_depth(),
                    "Neuron depth (z layers) used by the percentage decoder.",
                ),
                with_description(
                    schema_percentage_neuron_positioning(),
                    "How percentage values map to neuron positions.",
                ),
                with_description(schema_bool(), "Enable signed percentage values."),
                with_description(
                    schema_percentage_channel_dimensionality(),
                    "Channel dimensionality for percentage decoding.",
                ),
            ])),
            "Tuple: [neuron_depth, positioning, signed, dimensionality].",
        ),
    );
    variants.set(
        "GazeProperties",
        with_description(
            schema_tuple(array_from_dicts(&[
                with_description(schema_neuron_depth(), "Neuron depth for gaze X."),
                with_description(schema_neuron_depth(), "Neuron depth for gaze Y."),
                with_description(
                    schema_percentage_neuron_positioning(),
                    "How gaze values map to neuron positions.",
                ),
            ])),
            "Tuple: [x_depth, y_depth, positioning].",
        ),
    );
    variants.set(
        "ImageFilteringSettings",
        with_description(
            schema_tuple(array_from_dicts(&[
                with_description(schema_neuron_depth(), "Neuron depth for brightness."),
                with_description(schema_neuron_depth(), "Neuron depth for contrast."),
                with_description(schema_neuron_depth(), "Neuron depth for diff thresholds."),
                with_description(
                    schema_percentage_neuron_positioning(),
                    "How filter values map to neuron positions.",
                ),
            ])),
            "Tuple: [brightness_depth, contrast_depth, diff_depth, positioning].",
        ),
    );
    with_description(
        schema_externally_tagged_enum(variants),
        "Decoder property configuration for this unit.",
    )
}

fn schema_pipeline_stage_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set(
        "ImageFrameProcessor",
        with_description(
            schema_object(dictionary_from_pairs(&[(
                "transformer_definition",
                with_description(
                    schema_image_frame_processor(),
                    "Image transform pipeline definition.",
                ),
            )])),
            "Image processing stage for frames.",
        ),
    );
    variants.set(
        "ImageFrameSegmentator",
        with_description(
            schema_object(dictionary_from_pairs(&[
                (
                    "input_image_properties",
                    with_description(
                        schema_image_frame_properties(),
                        "Input image properties before segmentation.",
                    ),
                ),
                (
                    "output_image_properties",
                    with_description(
                        schema_segmented_image_frame_properties(),
                        "Output segmented image properties.",
                    ),
                ),
                (
                    "segmentation_gaze",
                    with_description(
                        schema_gaze_properties(),
                        "Gaze settings used to segment the image.",
                    ),
                ),
            ])),
            "Stage that segments image frames into regions.",
        ),
    );
    variants.set(
        "ImageQuickDiff",
        with_description(
            schema_object(dictionary_from_pairs(&[
                (
                    "per_pixel_allowed_range",
                    with_description(
                        schema_range_u8(),
                        "Allowed per-pixel difference range.",
                    ),
                ),
                (
                    "acceptable_amount_of_activity_in_image",
                    with_description(
                        schema_range_percentage(),
                        "Acceptable activity range for the image.",
                    ),
                ),
                (
                    "image_properties",
                    with_description(
                        schema_image_frame_properties(),
                        "Image properties used for diffing.",
                    ),
                ),
            ])),
            "Stage that computes quick image differences.",
        ),
    );
    variants.set(
        "ImagePixelValueCountThreshold",
        with_description(
            schema_object(dictionary_from_pairs(&[
                (
                    "input_definition",
                    with_description(
                        schema_image_frame_properties(),
                        "Input image properties.",
                    ),
                ),
                (
                    "inclusive_pixel_range",
                    with_description(
                        schema_range_u8(),
                        "Pixel value range to count (inclusive).",
                    ),
                ),
                (
                    "acceptable_amount_of_activity_in_image",
                    with_description(
                        schema_range_percentage(),
                        "Acceptable activity range for the image.",
                    ),
                ),
            ])),
            "Stage that thresholds based on pixel value counts.",
        ),
    );
    with_description(
        schema_externally_tagged_enum(variants),
        "Pipeline stage configuration.",
    )
}

fn schema_image_frame_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "image_resolution",
        with_description(
            schema_image_xy_resolution(),
            "Width and height of the image in pixels.",
        ),
    );
    fields.set(
        "color_space",
        with_description(schema_enum(&["Linear", "Gamma"]), "Color space for the image."),
    );
    fields.set(
        "color_channel_layout",
        with_description(
            schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]),
            "Color channel layout for the image.",
        ),
    );
    schema_object(fields)
}

fn schema_segmented_image_frame_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "segment_xy_resolutions",
        with_description(
            schema_segmented_xy_resolutions(),
            "Resolution per segmentation tile.",
        ),
    );
    fields.set(
        "center_color_channel",
        with_description(
            schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]),
            "Color layout for the center segment.",
        ),
    );
    fields.set(
        "peripheral_color_channels",
        with_description(
            schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]),
            "Color layout for peripheral segments.",
        ),
    );
    fields.set(
        "color_space",
        with_description(schema_enum(&["Linear", "Gamma"]), "Color space for segments."),
    );
    schema_object(fields)
}

fn schema_gaze_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "eccentricity_location_xy",
        with_description(
            schema_percentage_2d(),
            "Normalized gaze location in the image (0..1).",
        ),
    );
    fields.set(
        "modulation_size",
        with_description(schema_percentage(), "Normalized size of gaze modulation."),
    );
    schema_object(fields)
}

fn schema_image_filtering_settings() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "brightness",
        with_description(schema_percentage(), "Brightness adjustment (0..1)."),
    );
    fields.set(
        "contrast",
        with_description(schema_percentage(), "Contrast adjustment (0..1)."),
    );
    fields.set(
        "per_pixel_diff_threshold",
        with_description(
            schema_percentage_2d(),
            "Per-pixel difference threshold (0..1).",
        ),
    );
    fields.set(
        "image_diff_threshold",
        with_description(
            schema_percentage_2d(),
            "Global image difference threshold (0..1).",
        ),
    );
    schema_object(fields)
}

fn schema_image_frame_processor() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "input_image_properties",
        with_description(
            schema_image_frame_properties(),
            "Input image properties before processing.",
        ),
    );
    fields.set(
        "cropping_from",
        with_description(
            schema_optional(schema_corner_points()),
            "Optional crop region (upper_left, lower_right).",
        ),
    );
    fields.set(
        "final_resize_xy_to",
        with_description(
            schema_optional(schema_image_xy_resolution()),
            "Optional output resolution after processing.",
        ),
    );
    fields.set(
        "convert_color_space_to",
        with_description(
            schema_optional(schema_enum(&["Linear", "Gamma"])),
            "Optional color space conversion.",
        ),
    );
    fields.set(
        "offset_brightness_by",
        with_description(
            schema_optional(schema_int(i64::MIN, i64::MAX)),
            "Optional brightness offset (signed).",
        ),
    );
    fields.set(
        "change_contrast_by",
        with_description(
            schema_optional(schema_float(f64::MIN, f64::MAX)),
            "Optional contrast change factor.",
        ),
    );
    fields.set(
        "convert_to_grayscale",
        with_description(schema_bool(), "Convert to grayscale if true."),
    );
    schema_object(fields)
}

fn schema_corner_points() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "upper_left",
        with_description(schema_image_xy_point(), "Upper-left crop corner."),
    );
    fields.set(
        "lower_right",
        with_description(schema_image_xy_point(), "Lower-right crop corner."),
    );
    schema_object(fields)
}

fn schema_segmented_xy_resolutions() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "lower_left",
        with_description(schema_image_xy_resolution(), "Lower-left segment resolution."),
    );
    fields.set(
        "lower_middle",
        with_description(schema_image_xy_resolution(), "Lower-middle segment resolution."),
    );
    fields.set(
        "lower_right",
        with_description(schema_image_xy_resolution(), "Lower-right segment resolution."),
    );
    fields.set(
        "middle_left",
        with_description(schema_image_xy_resolution(), "Middle-left segment resolution."),
    );
    fields.set(
        "center",
        with_description(schema_image_xy_resolution(), "Center segment resolution."),
    );
    fields.set(
        "middle_right",
        with_description(schema_image_xy_resolution(), "Middle-right segment resolution."),
    );
    fields.set(
        "upper_left",
        with_description(schema_image_xy_resolution(), "Upper-left segment resolution."),
    );
    fields.set(
        "upper_middle",
        with_description(schema_image_xy_resolution(), "Upper-middle segment resolution."),
    );
    fields.set(
        "upper_right",
        with_description(schema_image_xy_resolution(), "Upper-right segment resolution."),
    );
    schema_object(fields)
}

fn schema_image_xy_resolution() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "width",
        with_description(schema_int(1, i64::MAX), "Image width in pixels."),
    );
    fields.set(
        "height",
        with_description(schema_int(1, i64::MAX), "Image height in pixels."),
    );
    schema_object(fields)
}

fn schema_image_xy_point() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("x", with_description(schema_int(0, i64::MAX), "X coordinate."));
    fields.set("y", with_description(schema_int(0, i64::MAX), "Y coordinate."));
    schema_object(fields)
}

fn schema_misc_data_dimensions() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "width",
        with_description(schema_int(1, i64::MAX), "Width dimension."),
    );
    fields.set(
        "height",
        with_description(schema_int(1, i64::MAX), "Height dimension."),
    );
    fields.set(
        "depth",
        with_description(schema_int(1, i64::MAX), "Depth dimension."),
    );
    schema_object(fields)
}

fn schema_neuron_depth() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "value",
        with_description(schema_int(1, i64::MAX), "Neuron depth (z layers)."),
    );
    schema_object(fields)
}

fn schema_percentage_neuron_positioning() -> Dictionary {
    with_description(
        schema_enum(&["Linear", "Fractional"]),
        "Positioning strategy for percentage channels.",
    )
}

fn schema_percentage_channel_dimensionality() -> Dictionary {
    with_description(
        schema_enum(&["D1", "D2", "D3", "D4"]),
        "Dimensionality of the percentage channel.",
    )
}

fn schema_percentage() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "value",
        with_description(schema_float(0.0, 1.0), "Normalized value (0..1)."),
    );
    schema_object(fields)
}

fn schema_percentage_2d() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "a",
        with_description(schema_percentage(), "Normalized value A (0..1)."),
    );
    fields.set(
        "b",
        with_description(schema_percentage(), "Normalized value B (0..1)."),
    );
    schema_object(fields)
}

fn schema_range_u8() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "start",
        with_description(schema_int(0, 255), "Range start (0..255)."),
    );
    fields.set(
        "end",
        with_description(schema_int(0, 255), "Range end (0..255)."),
    );
    schema_object(fields)
}

fn schema_range_percentage() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set(
        "start",
        with_description(schema_percentage(), "Range start (0..1)."),
    );
    fields.set(
        "end",
        with_description(schema_percentage(), "Range end (0..1)."),
    );
    schema_object(fields)
}

fn schema_object(fields: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "object");
    schema.set("fields", fields);
    schema
}

fn schema_array(items: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "array");
    schema.set("items", items);
    schema
}

fn schema_tuple(items: Array<Variant>) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "tuple");
    schema.set("items", items);
    schema
}

fn schema_map(key: Dictionary, value: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "map");
    schema.set("key", key);
    schema.set("value", value);
    schema
}

fn schema_externally_tagged_enum(variants: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "externally_tagged_enum");
    schema.set("variants", variants);
    schema
}

fn schema_tagged_union(tag: &str, value_key: &str, variants: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "tagged_union");
    schema.set("tag", tag);
    schema.set("value", value_key);
    schema.set("variants", variants);
    schema.set(
        "tag_description",
        "Selects the variant type for this value.",
    );
    schema.set(
        "value_description",
        "Properties for the selected variant type.",
    );
    schema
}

fn schema_optional(item: Dictionary) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "optional");
    schema.set("item", item);
    schema
}

fn schema_unit() -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "unit");
    schema
}

fn schema_string() -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "string");
    schema
}

fn schema_bool() -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "bool");
    schema
}

fn schema_int(min: i64, max: i64) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "int");
    schema.set("min", min);
    schema.set("max", max);
    schema
}

fn schema_float(min: f64, max: f64) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "float");
    schema.set("min", min);
    schema.set("max", max);
    schema
}

fn schema_enum(options: &[&str]) -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "enum");
    schema.set("options", string_array(options));
    schema
}

fn schema_json_value() -> Dictionary {
    let mut schema = Dictionary::new();
    schema.set("kind", "json_value");
    schema
}

fn with_description(mut schema: Dictionary, description: &str) -> Dictionary {
    schema.set("description", description);
    schema
}

fn string_array(values: &[&str]) -> Array<Variant> {
    let mut array = Array::<Variant>::new();
    for value in values {
        let entry = Variant::from(*value);
        array.push(&entry);
    }
    array
}

fn array_from_dicts(dicts: &[Dictionary]) -> Array<Variant> {
    let mut array = Array::<Variant>::new();
    for dict in dicts {
        let entry = Variant::from(dict.clone());
        array.push(&entry);
    }
    array
}

fn dictionary_from_pairs(pairs: &[(&str, Dictionary)]) -> Dictionary {
    let mut dict = Dictionary::new();
    for (key, value) in pairs {
        dict.set(*key, value.clone());
    }
    dict
}

fn json_to_dictionary(value: &Value) -> Dictionary {
    let mut dict = Dictionary::new();
    if let Value::Object(map) = value {
        for (key, val) in map {
            dict.set(GString::from(key.as_str()), json_to_variant(val));
        }
    }
    dict
}

fn push_json_value(out: &mut Array<Variant>, value: &Value) {
    match value {
        Value::Null => {
            let entry = Variant::nil();
            out.push(&entry);
        }
        Value::Bool(v) => {
            let entry = Variant::from(*v);
            out.push(&entry);
        }
        Value::Number(num) => {
            if let Some(i) = num.as_i64() {
                let entry = Variant::from(i);
                out.push(&entry);
            } else if let Some(u) = num.as_u64() {
                let entry = Variant::from(u as i64);
                out.push(&entry);
            } else if let Some(f) = num.as_f64() {
                let entry = Variant::from(f);
                out.push(&entry);
            } else {
                let entry = Variant::nil();
                out.push(&entry);
            }
        }
        Value::String(s) => {
            let entry = Variant::from(s.as_str());
            out.push(&entry);
        }
        Value::Array(arr) => {
            let mut nested = Array::<Variant>::new();
            for item in arr {
                push_json_value(&mut nested, item);
            }
            let entry = Variant::from(nested);
            out.push(&entry);
        }
        Value::Object(map) => {
            let mut dict = Dictionary::new();
            for (key, val) in map {
                dict.set(GString::from(key.as_str()), json_to_variant(val));
            }
            let entry = Variant::from(dict);
            out.push(&entry);
        }
    }
}

fn json_to_variant(value: &Value) -> Variant {
    match value {
        Value::Null => Variant::nil(),
        Value::Bool(v) => Variant::from(*v),
        Value::Number(num) => {
            if let Some(i) = num.as_i64() {
                Variant::from(i)
            } else if let Some(u) = num.as_u64() {
                Variant::from(u as i64)
            } else if let Some(f) = num.as_f64() {
                Variant::from(f)
            } else {
                Variant::nil()
            }
        }
        Value::String(s) => Variant::from(GString::from(s.as_str())),
        Value::Array(arr) => {
            let mut out = Array::<Variant>::new();
            for item in arr {
                push_json_value(&mut out, item);
            }
            Variant::from(out)
        }
        Value::Object(map) => {
            let mut dict = Dictionary::new();
            for (key, val) in map {
                dict.set(GString::from(key.as_str()), json_to_variant(val));
            }
            Variant::from(dict)
        }
    }
}
