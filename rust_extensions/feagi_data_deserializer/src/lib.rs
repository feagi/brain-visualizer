use godot::prelude::*;
use feagi_data_serialization::FeagiByteStructureType;
use feagi_data_structures::neurons::xyzp::CorticalMappedXYZPNeuronData;

struct FeagiDataDeserializerLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiDataDeserializerLib {}

/// Main GDExtension class for FEAGI data deserialization
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiDataDeserializer {
    #[base]
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for FeagiDataDeserializer {
    fn init(base: Base<RefCounted>) -> Self {
        godot_print!("🦀 FEAGI Rust Data Deserializer v0.0.50-beta.28 initialized!");
        Self { base }
    }
}

#[godot_api]
impl FeagiDataDeserializer {
    /// Decode Type 11 neuron data using FEAGI's official Rust library
    #[func]
    pub fn decode_type_11_data(&self, buffer: PackedByteArray) -> Dictionary {
        // Convert PackedByteArray to Vec<u8> for Rust processing
        let rust_buffer: Vec<u8> = buffer.to_vec();
        
        // Use official feagi_data_serialization library via the CorticalMappedXYZPNeuronData implementation
        match CorticalMappedXYZPNeuronData::new_from_bytes(&rust_buffer) {
            Ok(neuron_data) => {
                self.convert_neuron_data_to_godot(&neuron_data)
            }
            Err(e) => {
                godot_error!("🦀 Failed to deserialize Type 11 data: {:?}", e);
                self.create_error_dict(format!("Deserialization error: {:?}", e))
            }
        }
    }

    /// Get structure type from buffer
    #[func]
    pub fn get_structure_type(&self, buffer: PackedByteArray) -> i32 {
        if buffer.is_empty() {
            return -1;
        }
        buffer[0] as i32
    }
}

// Private helper methods
impl FeagiDataDeserializer {
    /// Convert official neuron data structure to Godot Dictionary
    fn convert_neuron_data_to_godot(
        &self,
        neuron_data: &CorticalMappedXYZPNeuronData,
    ) -> Dictionary {
        let mut result_dict = Dictionary::new();
        result_dict.set("success", true);
        result_dict.set("error", "");
        
        let mut areas_dict = Dictionary::new();
        let mut total_neurons: i32 = 0;

        // Iterate through each cortical area in the neuron data using 'mappings' field
        for (cortical_id, neuron_array) in neuron_data.mappings.iter() {
            let num_neurons = neuron_array.len();
            
            if num_neurons == 0 {
                continue;
            }

            total_neurons += num_neurons as i32;

            // Convert cortical_id to String
            let cortical_id_str = cortical_id.to_string();

            // Create area data dictionary
            let mut area_dict = Dictionary::new();
            
            // Convert arrays to Godot PackedArrays
            let mut x_array = PackedInt32Array::new();
            let mut y_array = PackedInt32Array::new();
            let mut z_array = PackedInt32Array::new();
            let mut p_array = PackedFloat32Array::new();

            // Use the iterator to access neurons
            for neuron in neuron_array.iter() {
                x_array.push(neuron.cortical_coordinate.x as i32);
                y_array.push(neuron.cortical_coordinate.y as i32);
                z_array.push(neuron.cortical_coordinate.z as i32);
                p_array.push(neuron.potential);
            }

            area_dict.set("x_array", x_array);
            area_dict.set("y_array", y_array);
            area_dict.set("z_array", z_array);
            area_dict.set("p_array", p_array);

            areas_dict.set(cortical_id_str, area_dict);
        }

        result_dict.set("areas", areas_dict);
        result_dict.set("total_neurons", total_neurons);
        
        result_dict
    }

    /// Create error dictionary
    fn create_error_dict(&self, error_msg: String) -> Dictionary {
        let mut error_dict = Dictionary::new();
        error_dict.set("success", false);
        error_dict.set("error", error_msg);
        error_dict.set("areas", Dictionary::new());
        error_dict.set("total_neurons", 0);
        error_dict
    }
}
