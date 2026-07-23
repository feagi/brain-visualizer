//! Derive IPU/OPU cortical IDs declared in `device_registrations` JSON.
//! Motor paths align with `feagi-api` `derive_motor_cortical_ids_from_device_registrations`
//! (`build_io_config_map_from_unit_def`); sensory uses the same defaults as that module.

use feagi_structures::genomic::cortical_area::descriptors::CorticalUnitIndex;
use feagi_structures::genomic::cortical_area::io_cortical_area_configuration_flag::{
    FrameChangeHandling, PercentageNeuronPositioning,
};
use feagi_structures::genomic::{MotorCorticalUnit, SensoryCorticalUnit};
use serde_json::{Map, Value};
use std::collections::HashSet;

fn build_io_config_map() -> Result<Map<String, serde_json::Value>, String> {
    let mut config = Map::new();
    config.insert(
        "frame_change_handling".to_string(),
        serde_json::to_value(FrameChangeHandling::Absolute)
            .map_err(|e| format!("Failed to serialize FrameChangeHandling: {}", e))?,
    );
    config.insert(
        "percentage_neuron_positioning".to_string(),
        serde_json::to_value(PercentageNeuronPositioning::Linear)
            .map_err(|e| format!("Failed to serialize PercentageNeuronPositioning: {}", e))?,
    );
    Ok(config)
}

/// Same rules as `feagi-api` `agent_registration::build_io_config_map_from_unit_def`.
fn build_io_config_map_from_unit_def(
    unit_def: &Value,
) -> Result<Map<String, serde_json::Value>, String> {
    let io_flags = unit_def
        .get("io_configuration_flags")
        .and_then(|v| v.as_object());

    let frame_value = io_flags
        .and_then(|flags| flags.get("frame_change_handling"))
        .cloned()
        .or_else(|| unit_def.get("frame_change_handling").cloned())
        .ok_or_else(|| "unit_def missing frame_change_handling".to_string())?;
    let positioning_value = io_flags
        .and_then(|flags| flags.get("percentage_neuron_positioning"))
        .cloned()
        .or_else(|| unit_def.get("percentage_neuron_positioning").cloned())
        .unwrap_or_else(|| serde_json::json!(PercentageNeuronPositioning::Linear));

    let frame: FrameChangeHandling = serde_json::from_value(frame_value)
        .map_err(|e| format!("Invalid frame_change_handling value: {}", e))?;
    let positioning: PercentageNeuronPositioning = serde_json::from_value(positioning_value)
        .map_err(|e| format!("Invalid percentage_neuron_positioning value: {}", e))?;

    let mut config = Map::new();
    config.insert(
        "frame_change_handling".to_string(),
        serde_json::to_value(frame)
            .map_err(|e| format!("Failed to serialize FrameChangeHandling: {}", e))?,
    );
    config.insert(
        "percentage_neuron_positioning".to_string(),
        serde_json::to_value(positioning)
            .map_err(|e| format!("Failed to serialize PercentageNeuronPositioning: {}", e))?,
    );
    Ok(config)
}

/// Motor IO cortical IDs: skip malformed entries (same spirit as FEAGI auto-create).
fn collect_motor_cortical_ids_lenient(device_registrations: &serde_json::Value) -> HashSet<String> {
    let mut out = HashSet::new();
    let Some(output_units) = device_registrations
        .get("output_units_and_decoder_properties")
        .and_then(|v| v.as_object())
    else {
        return out;
    };
    for (motor_unit_key, unit_defs) in output_units {
        let motor_unit: MotorCorticalUnit = match serde_json::from_value::<MotorCorticalUnit>(
            serde_json::Value::String(motor_unit_key.clone()),
        ) {
            Ok(v) => v,
            Err(_) => continue,
        };
        let Some(unit_defs_arr) = unit_defs.as_array() else {
            continue;
        };
        for entry in unit_defs_arr {
            let Some(pair) = entry.as_array() else {
                continue;
            };
            let Some(unit_def) = pair.first() else {
                continue;
            };
            let Some(group_u64) = unit_def.get("cortical_unit_index").and_then(|v| v.as_u64())
            else {
                continue;
            };
            let group_u8: u8 = match group_u64.try_into() {
                Ok(v) => v,
                Err(_) => continue,
            };
            let group: CorticalUnitIndex = group_u8.into();
            let device_count = unit_def
                .get("device_grouping")
                .and_then(|v| v.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            if device_count == 0 {
                continue;
            }
            let config = match build_io_config_map_from_unit_def(unit_def) {
                Ok(m) => m,
                Err(_) => match build_io_config_map() {
                    Ok(m) => m,
                    Err(_) => continue,
                },
            };
            if let Ok(ids) = motor_unit
                .get_cortical_id_vector_from_index_and_serde_io_configuration_flags(group, config)
            {
                for cortical_id in ids {
                    out.insert(cortical_id.as_base_64());
                }
            }
        }
    }
    out
}

/// Sensory IO cortical IDs: skip malformed entries (same spirit as FEAGI auto-create).
fn collect_sensory_cortical_ids_lenient(
    device_registrations: &serde_json::Value,
) -> HashSet<String> {
    let mut out = HashSet::new();
    let Some(input_units) = device_registrations
        .get("input_units_and_encoder_properties")
        .and_then(|v| v.as_object())
    else {
        return out;
    };
    for (sensory_unit_key, unit_defs) in input_units {
        let sensory_unit: SensoryCorticalUnit = match serde_json::from_value::<SensoryCorticalUnit>(
            serde_json::Value::String(sensory_unit_key.clone()),
        ) {
            Ok(v) => v,
            Err(_) => continue,
        };
        let Some(unit_defs_arr) = unit_defs.as_array() else {
            continue;
        };
        for entry in unit_defs_arr {
            let Some(pair) = entry.as_array() else {
                continue;
            };
            let Some(unit_def) = pair.first() else {
                continue;
            };
            let Some(group_u64) = unit_def.get("cortical_unit_index").and_then(|v| v.as_u64())
            else {
                continue;
            };
            let group_u8: u8 = match group_u64.try_into() {
                Ok(v) => v,
                Err(_) => continue,
            };
            let group: CorticalUnitIndex = group_u8.into();
            let device_count = unit_def
                .get("device_grouping")
                .and_then(|v| v.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            if device_count == 0 {
                continue;
            }
            let Ok(config) = build_io_config_map() else {
                continue;
            };
            if let Ok(ids) = sensory_unit
                .get_cortical_id_vector_from_index_and_serde_io_configuration_flags(group, config)
            {
                for cortical_id in ids {
                    out.insert(cortical_id.as_base_64());
                }
            }
        }
    }
    out
}

/// Union of motor + sensory cortical IDs referenced by `device_registrations`.
pub fn collect_io_cortical_ids_from_device_registrations(
    device_registrations: &serde_json::Value,
) -> HashSet<String> {
    let mut out = HashSet::new();
    out.extend(collect_motor_cortical_ids_lenient(device_registrations));
    out.extend(collect_sensory_cortical_ids_lenient(device_registrations));
    out
}
