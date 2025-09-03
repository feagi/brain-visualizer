use godot::prelude::*;
use std::collections::HashMap;

// Import the FEAGI data serialization library
// Note: We'll need to check the actual API once we can access the crate
// For now, I'll create the structure based on what we expect

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
        godot_print!("🦀 FEAGI Rust Data Deserializer initialized!");
        Self { base }
    }
}

#[godot_api]
impl FeagiDataDeserializer {
    /// Decode Type 11 neuron data using FEAGI's Rust deserialization
    /// This replaces the _decode_type_11_optimized method in GDScript
    #[func]
    pub fn decode_type_11_data(&self, buffer: PackedByteArray) -> Dictionary {
        // Convert PackedByteArray to Vec<u8> for Rust processing
        let rust_buffer: Vec<u8> = buffer.to_vec();
        
        // TODO: Use feagi_data_serialization once we have access to the actual API
        // For now, we'll implement a compatible decoder based on the GDScript version
        match self.decode_type_11_rust(&rust_buffer) {
            Ok(result) => {
                self.convert_rust_result_to_godot_dict(result)
            }
            Err(error) => {
                godot_error!("🦀 Rust: Decode error: {}", error);
                let mut error_dict = Dictionary::new();
                error_dict.set("success", false);
                error_dict.set("error", error);
                error_dict.set("areas", Dictionary::new());
                error_dict.set("total_neurons", 0);
                error_dict
            }
        }
    }

    /// Process wrapped byte structure - handles different message types
    /// This replaces the _process_wrapped_byte_structure method logic
    #[func]
    pub fn get_structure_type(&self, buffer: PackedByteArray) -> i32 {
        if buffer.is_empty() {
            return -1;
        }
        buffer[0] as i32
    }

    /// High-performance bulk array conversion from Rust to Godot
    #[func]
    pub fn convert_bulk_arrays_to_godot(
        &self,
        x_data: PackedByteArray,
        y_data: PackedByteArray,
        z_data: PackedByteArray,
        p_data: PackedByteArray,
    ) -> Dictionary {
        let mut result = Dictionary::new();
        
        // Convert byte arrays to typed arrays using Rust's efficient conversion
        let x_array = self.bytes_to_int32_array(x_data);
        let y_array = self.bytes_to_int32_array(y_data);
        let z_array = self.bytes_to_int32_array(z_data);
        let p_array = self.bytes_to_float32_array(p_data);
        
        result.set("x_array", x_array);
        result.set("y_array", y_array);
        result.set("z_array", z_array);
        result.set("p_array", p_array);
        
        result
    }
}

// Private implementation methods
impl FeagiDataDeserializer {
    /// Internal Rust implementation of Type 11 decoding
    /// This will be replaced with feagi_data_serialization calls
    fn decode_type_11_rust(&self, buffer: &[u8]) -> Result<DecodedResult, String> {
        if buffer.len() < 4 {
            return Err("Buffer too small for global header".to_string());
        }

        // Read global header
        let structure_type = buffer[0];
        let version = buffer[1];
        let num_areas = u16::from_le_bytes([buffer[2], buffer[3]]);

        // Validate header
        if structure_type != 11 {
            return Err(format!("Invalid structure type: {} (expected 11)", structure_type));
        }

        if version != 1 {
            return Err(format!("Unsupported version: {} (expected 1)", version));
        }

        if num_areas == 0 {
            return Err("No cortical areas in data".to_string());
        }

        let mut pos = 4;
        let area_headers_size = (num_areas as usize) * 14; // 6 + 4 + 4 bytes per area

        if pos + area_headers_size > buffer.len() {
            return Err("Buffer too small for area headers".to_string());
        }

        // Read area headers
        let mut area_headers = Vec::new();
        for _ in 0..num_areas {
            // Read cortical ID (6 bytes)
            let cortical_id = String::from_utf8_lossy(&buffer[pos..pos + 6])
                .trim_end_matches('\0')
                .to_string();
            pos += 6;

            // Read data offset and length
            let data_offset = u32::from_le_bytes([
                buffer[pos], buffer[pos + 1], buffer[pos + 2], buffer[pos + 3]
            ]) as usize;
            pos += 4;

            let data_length = u32::from_le_bytes([
                buffer[pos], buffer[pos + 1], buffer[pos + 2], buffer[pos + 3]
            ]) as usize;
            pos += 4;

            area_headers.push(AreaHeader {
                cortical_id,
                data_offset,
                data_length,
            });
        }

        // Process each area's neuron data
        let mut areas = HashMap::new();
        let mut total_neurons = 0;

        for header in area_headers {
            if header.data_offset + header.data_length > buffer.len() {
                return Err(format!(
                    "Area {} data range exceeds buffer",
                    header.cortical_id
                ));
            }

            if header.data_length % 16 != 0 {
                return Err(format!(
                    "Area {} data length {} not divisible by 16",
                    header.cortical_id, header.data_length
                ));
            }

            let num_neurons = header.data_length / 16;
            if num_neurons == 0 {
                // Empty area
                areas.insert(header.cortical_id, AreaData {
                    x_array: Vec::new(),
                    y_array: Vec::new(),
                    z_array: Vec::new(),
                    p_array: Vec::new(),
                });
                continue;
            }

            // Extract arrays using efficient bulk operations
            let array_byte_size = num_neurons * 4;
            let mut data_pos = header.data_offset;

            // X array
            let x_bytes = &buffer[data_pos..data_pos + array_byte_size];
            let x_array = self.convert_bytes_to_i32_vec(x_bytes);
            data_pos += array_byte_size;

            // Y array
            let y_bytes = &buffer[data_pos..data_pos + array_byte_size];
            let y_array = self.convert_bytes_to_i32_vec(y_bytes);
            data_pos += array_byte_size;

            // Z array
            let z_bytes = &buffer[data_pos..data_pos + array_byte_size];
            let z_array = self.convert_bytes_to_i32_vec(z_bytes);
            data_pos += array_byte_size;

            // P array
            let p_bytes = &buffer[data_pos..data_pos + array_byte_size];
            let p_array = self.convert_bytes_to_f32_vec(p_bytes);

            areas.insert(header.cortical_id, AreaData {
                x_array,
                y_array,
                z_array,
                p_array,
            });

            total_neurons += num_neurons;
        }

        Ok(DecodedResult {
            success: true,
            areas,
            total_neurons,
        })
    }

    /// Convert bytes to i32 vector using efficient unsafe operations
    fn convert_bytes_to_i32_vec(&self, bytes: &[u8]) -> Vec<i32> {
        let mut result = Vec::with_capacity(bytes.len() / 4);
        for chunk in bytes.chunks_exact(4) {
            let value = i32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            result.push(value);
        }
        result
    }

    /// Convert bytes to f32 vector using efficient unsafe operations
    fn convert_bytes_to_f32_vec(&self, bytes: &[u8]) -> Vec<f32> {
        let mut result = Vec::with_capacity(bytes.len() / 4);
        for chunk in bytes.chunks_exact(4) {
            let value = f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            result.push(value);
        }
        result
    }

    /// Convert Rust result to Godot Dictionary format
    fn convert_rust_result_to_godot_dict(&self, result: DecodedResult) -> Dictionary {
        let mut dict = Dictionary::new();
        dict.set("success", result.success);
        dict.set("total_neurons", result.total_neurons as i32);

        let mut areas_dict = Dictionary::new();
        for (cortical_id, area_data) in result.areas {
            let mut area_dict = Dictionary::new();
            
            // Convert Rust vectors to Godot PackedArrays
            let x_array = PackedInt32Array::from(&area_data.x_array[..]);
            let y_array = PackedInt32Array::from(&area_data.y_array[..]);
            let z_array = PackedInt32Array::from(&area_data.z_array[..]);
            let p_array = PackedFloat32Array::from(&area_data.p_array[..]);

            area_dict.set("x_array", x_array);
            area_dict.set("y_array", y_array);
            area_dict.set("z_array", z_array);
            area_dict.set("p_array", p_array);

            areas_dict.set(cortical_id.as_str(), area_dict);
        }

        dict.set("areas", areas_dict);
        dict
    }

    /// Helper method to convert bytes to PackedInt32Array
    fn bytes_to_int32_array(&self, bytes: PackedByteArray) -> PackedInt32Array {
        let rust_bytes: Vec<u8> = bytes.to_vec();
        let int32_vec = self.convert_bytes_to_i32_vec(&rust_bytes);
        PackedInt32Array::from(&int32_vec[..])
    }

    /// Helper method to convert bytes to PackedFloat32Array
    fn bytes_to_float32_array(&self, bytes: PackedByteArray) -> PackedFloat32Array {
        let rust_bytes: Vec<u8> = bytes.to_vec();
        let float32_vec = self.convert_bytes_to_f32_vec(&rust_bytes);
        PackedFloat32Array::from(&float32_vec[..])
    }
}

// Data structures for internal processing
#[derive(Debug)]
struct AreaHeader {
    cortical_id: String,
    data_offset: usize,
    data_length: usize,
}

#[derive(Debug)]
struct AreaData {
    x_array: Vec<i32>,
    y_array: Vec<i32>,
    z_array: Vec<i32>,
    p_array: Vec<f32>,
}

#[derive(Debug)]
struct DecodedResult {
    success: bool,
    areas: HashMap<String, AreaData>,
    total_neurons: usize,
}

// Extension library struct
struct FeagiDataDeserializerLib;