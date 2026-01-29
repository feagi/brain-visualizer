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
        schema_map(
            schema_string(),
            schema_array(schema_tuple(array_from_dicts(&[
                schema_json_unit_definition(),
                schema_json_encoder_properties(),
            ]))),
        ),
    );
    fields.set(
        "output_units_and_decoder_properties",
        schema_map(
            schema_string(),
            schema_array(schema_tuple(array_from_dicts(&[
                schema_json_unit_definition(),
                schema_json_decoder_properties(),
            ]))),
        ),
    );
    fields.set("feedbacks", schema_json_value());
    schema_object(fields)
}

fn schema_json_unit_definition() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("friendly_name", schema_optional(schema_string()));
    fields.set("cortical_unit_index", schema_int(0, 255));
    fields.set("io_configuration_flags", schema_map(schema_string(), schema_json_value()));
    fields.set("device_grouping", schema_array(schema_json_device_grouping()));
    schema_object(fields)
}

fn schema_json_device_grouping() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("friendly_name", schema_optional(schema_string()));
    fields.set("device_properties", schema_map(schema_string(), schema_json_device_property_value()));
    fields.set("channel_index_override", schema_optional(schema_int(0, 4294967295)));
    fields.set("pipeline_stages", schema_array(schema_pipeline_stage_properties()));
    schema_object(fields)
}

fn schema_json_device_property_value() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set("String", schema_string());
    variants.set("Integer", schema_int(i64::MIN, i64::MAX));
    variants.set("Float", schema_float(f64::MIN, f64::MAX));
    variants.set("Dictionary", schema_map(schema_string(), schema_json_value()));
    schema_tagged_union("type", "value", variants)
}

fn schema_json_encoder_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set("Boolean", schema_unit());
    variants.set("CartesianPlane", schema_image_frame_properties());
    variants.set("MiscData", schema_misc_data_dimensions());
    variants.set(
        "Percentage",
        schema_tuple(array_from_dicts(&[
            schema_neuron_depth(),
            schema_percentage_neuron_positioning(),
            schema_bool(),
            schema_percentage_channel_dimensionality(),
        ])),
    );
    variants.set("SegmentedImageFrame", schema_segmented_image_frame_properties());
    schema_externally_tagged_enum(variants)
}

fn schema_json_decoder_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set("CartesianPlane", schema_image_frame_properties());
    variants.set("MiscData", schema_misc_data_dimensions());
    variants.set(
        "Percentage",
        schema_tuple(array_from_dicts(&[
            schema_neuron_depth(),
            schema_percentage_neuron_positioning(),
            schema_bool(),
            schema_percentage_channel_dimensionality(),
        ])),
    );
    variants.set(
        "GazeProperties",
        schema_tuple(array_from_dicts(&[
            schema_neuron_depth(),
            schema_neuron_depth(),
            schema_percentage_neuron_positioning(),
        ])),
    );
    variants.set(
        "ImageFilteringSettings",
        schema_tuple(array_from_dicts(&[
            schema_neuron_depth(),
            schema_neuron_depth(),
            schema_neuron_depth(),
            schema_percentage_neuron_positioning(),
        ])),
    );
    schema_externally_tagged_enum(variants)
}

fn schema_pipeline_stage_properties() -> Dictionary {
    let mut variants = Dictionary::new();
    variants.set(
        "ImageFrameProcessor",
        schema_object(dictionary_from_pairs(&[
            ("transformer_definition", schema_image_frame_processor()),
        ])),
    );
    variants.set(
        "ImageFrameSegmentator",
        schema_object(dictionary_from_pairs(&[
            ("input_image_properties", schema_image_frame_properties()),
            ("output_image_properties", schema_segmented_image_frame_properties()),
            ("segmentation_gaze", schema_gaze_properties()),
        ])),
    );
    variants.set(
        "ImageQuickDiff",
        schema_object(dictionary_from_pairs(&[
            ("per_pixel_allowed_range", schema_range_u8()),
            ("acceptable_amount_of_activity_in_image", schema_range_percentage()),
            ("image_properties", schema_image_frame_properties()),
        ])),
    );
    variants.set(
        "ImagePixelValueCountThreshold",
        schema_object(dictionary_from_pairs(&[
            ("input_definition", schema_image_frame_properties()),
            ("inclusive_pixel_range", schema_range_u8()),
            ("acceptable_amount_of_activity_in_image", schema_range_percentage()),
        ])),
    );
    schema_externally_tagged_enum(variants)
}

fn schema_image_frame_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("image_resolution", schema_image_xy_resolution());
    fields.set("color_space", schema_enum(&["Linear", "Gamma"]));
    fields.set("color_channel_layout", schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]));
    schema_object(fields)
}

fn schema_segmented_image_frame_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("segment_xy_resolutions", schema_segmented_xy_resolutions());
    fields.set("center_color_channel", schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]));
    fields.set("peripheral_color_channels", schema_enum(&["GrayScale", "RG", "RGB", "RGBA"]));
    fields.set("color_space", schema_enum(&["Linear", "Gamma"]));
    schema_object(fields)
}

fn schema_gaze_properties() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("eccentricity_location_xy", schema_percentage_2d());
    fields.set("modulation_size", schema_percentage());
    schema_object(fields)
}

fn schema_image_filtering_settings() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("brightness", schema_percentage());
    fields.set("contrast", schema_percentage());
    fields.set("per_pixel_diff_threshold", schema_percentage_2d());
    fields.set("image_diff_threshold", schema_percentage_2d());
    schema_object(fields)
}

fn schema_image_frame_processor() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("input_image_properties", schema_image_frame_properties());
    fields.set("cropping_from", schema_optional(schema_corner_points()));
    fields.set("final_resize_xy_to", schema_optional(schema_image_xy_resolution()));
    fields.set("convert_color_space_to", schema_optional(schema_enum(&["Linear", "Gamma"])));
    fields.set("offset_brightness_by", schema_optional(schema_int(i64::MIN, i64::MAX)));
    fields.set("change_contrast_by", schema_optional(schema_float(f64::MIN, f64::MAX)));
    fields.set("convert_to_grayscale", schema_bool());
    schema_object(fields)
}

fn schema_corner_points() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("upper_left", schema_image_xy_point());
    fields.set("lower_right", schema_image_xy_point());
    schema_object(fields)
}

fn schema_segmented_xy_resolutions() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("lower_left", schema_image_xy_resolution());
    fields.set("lower_middle", schema_image_xy_resolution());
    fields.set("lower_right", schema_image_xy_resolution());
    fields.set("middle_left", schema_image_xy_resolution());
    fields.set("center", schema_image_xy_resolution());
    fields.set("middle_right", schema_image_xy_resolution());
    fields.set("upper_left", schema_image_xy_resolution());
    fields.set("upper_middle", schema_image_xy_resolution());
    fields.set("upper_right", schema_image_xy_resolution());
    schema_object(fields)
}

fn schema_image_xy_resolution() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("width", schema_int(1, i64::MAX));
    fields.set("height", schema_int(1, i64::MAX));
    schema_object(fields)
}

fn schema_image_xy_point() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("x", schema_int(0, i64::MAX));
    fields.set("y", schema_int(0, i64::MAX));
    schema_object(fields)
}

fn schema_misc_data_dimensions() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("width", schema_int(1, i64::MAX));
    fields.set("height", schema_int(1, i64::MAX));
    fields.set("depth", schema_int(1, i64::MAX));
    schema_object(fields)
}

fn schema_neuron_depth() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("value", schema_int(1, i64::MAX));
    schema_object(fields)
}

fn schema_percentage_neuron_positioning() -> Dictionary {
    schema_enum(&["Linear", "Fractional"])
}

fn schema_percentage_channel_dimensionality() -> Dictionary {
    schema_enum(&["D1", "D2", "D3", "D4"])
}

fn schema_percentage() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("value", schema_float(0.0, 1.0));
    schema_object(fields)
}

fn schema_percentage_2d() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("a", schema_percentage());
    fields.set("b", schema_percentage());
    schema_object(fields)
}

fn schema_range_u8() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("start", schema_int(0, 255));
    fields.set("end", schema_int(0, 255));
    schema_object(fields)
}

fn schema_range_percentage() -> Dictionary {
    let mut fields = Dictionary::new();
    fields.set("start", schema_percentage());
    fields.set("end", schema_percentage());
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
