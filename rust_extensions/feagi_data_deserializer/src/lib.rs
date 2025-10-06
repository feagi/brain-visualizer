use godot::prelude::*;
use feagi_data_serialization::{FeagiByteStructure, FeagiByteStructureCompatible};
use feagi_data_structures::neurons::xyzp::CorticalMappedXYZPNeuronData;
use rayon::prelude::*;
use std::sync::Mutex;

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
        
        // First, create a FeagiByteStructure from the raw bytes
        let byte_structure = match FeagiByteStructure::create_from_bytes(rust_buffer) {
            Ok(bs) => bs,
            Err(e) => {
                godot_error!("🦀 Failed to create FeagiByteStructure: {:?}", e);
                return self.create_error_dict(format!("Byte structure error: {:?}", e));
            }
        };
        
        // Then, deserialize into CorticalMappedXYZPNeuronData
        match CorticalMappedXYZPNeuronData::new_from_feagi_byte_structure(&byte_structure) {
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

    /// High-performance neuron visualization processor
    /// Processes neuron data and pre-calculates transforms and colors in parallel
    /// 
    /// Args:
    ///   - buffer: Raw Type 11 neuron data
    ///   - dimensions: Cortical area dimensions (Vector3)
    ///   - max_neurons: Maximum neurons to process (0 = unlimited)
    /// 
    /// Returns: Dictionary with:
    ///   - success: bool
    ///   - transforms: PackedFloat32Array (12 floats per transform: 3x4 matrix)
    ///   - colors: PackedFloat32Array (4 floats per color: RGBA)
    ///   - neuron_count: i32
    ///   - processing_time_us: i64 (microseconds)
    ///   - error: String
    #[func]
    pub fn process_neuron_visualization(
        &self,
        buffer: PackedByteArray,
        dimensions: Vector3,
        max_neurons: i32,
    ) -> Dictionary {
        let start_time = std::time::Instant::now();
        
        // Convert PackedByteArray to Vec<u8>
        let rust_buffer: Vec<u8> = buffer.to_vec();
        
        // Deserialize neuron data
        let byte_structure = match FeagiByteStructure::create_from_bytes(rust_buffer) {
            Ok(bs) => bs,
            Err(e) => {
                godot_error!("🦀 Failed to create FeagiByteStructure: {:?}", e);
                return self.create_visualization_error_dict(
                    format!("Byte structure error: {:?}", e),
                    start_time.elapsed().as_micros() as i64
                );
            }
        };
        
        let neuron_data = match CorticalMappedXYZPNeuronData::new_from_feagi_byte_structure(&byte_structure) {
            Ok(data) => data,
            Err(e) => {
                godot_error!("🦀 Failed to deserialize neuron data: {:?}", e);
                return self.create_visualization_error_dict(
                    format!("Deserialization error: {:?}", e),
                    start_time.elapsed().as_micros() as i64
                );
            }
        };
        
        // Count total neurons
        let total_neurons: usize = neuron_data.mappings.values()
            .map(|arr| arr.len())
            .sum();
        
        // Apply limit if specified
        let process_count = if max_neurons > 0 {
            std::cmp::min(total_neurons, max_neurons as usize)
        } else {
            total_neurons
        };
        
        // Pre-calculate constants
        let half_dimensions = Vector3::new(
            dimensions.x / 2.0,
            dimensions.y / 2.0,
            dimensions.z / 2.0,
        );
        let offset = Vector3::new(0.5, 0.5, 0.5);
        let scale = Vector3::new(
            1.0 / dimensions.x,
            1.0 / dimensions.y,
            1.0 / -dimensions.z,  // Note: negative Z
        );
        
        // Process neurons in parallel
        let transforms_mutex = Mutex::new(Vec::with_capacity(process_count * 12));
        let colors_mutex = Mutex::new(Vec::with_capacity(process_count * 4));
        let processed_mutex = Mutex::new(0usize);
        
        // Collect all neurons into a flat vector for parallel processing
        let mut all_neurons = Vec::with_capacity(process_count);
        for (_, neuron_array) in neuron_data.mappings.iter() {
            for neuron in neuron_array.iter() {
                if all_neurons.len() >= process_count {
                    break;
                }
                all_neurons.push((
                    neuron.cortical_coordinate.x,
                    neuron.cortical_coordinate.y,
                    neuron.cortical_coordinate.z,
                    neuron.potential,
                ));
            }
            if all_neurons.len() >= process_count {
                break;
            }
        }
        
        // Parallel processing using Rayon
        all_neurons.par_iter().for_each(|(x, y, z, _potential)| {
            // Check if we've hit the limit
            let mut processed = processed_mutex.lock().unwrap();
            if *processed >= process_count {
                return;
            }
            *processed += 1;
            drop(processed);
            
            // Calculate transform
            let feagi_pos = Vector3::new(*x as f32, *y as f32, *z as f32);
            let centered_pos = Vector3::new(
                (feagi_pos.x - half_dimensions.x + offset.x) * scale.x,
                (feagi_pos.y - half_dimensions.y + offset.y) * scale.y,
                (feagi_pos.z - half_dimensions.z + offset.z) * scale.z,
            );
            
            // Transform3D as 3x4 matrix (row-major): [basis.x, basis.y, basis.z, origin]
            // Identity basis (no rotation) + translation
            let transform_data = [
                1.0, 0.0, 0.0, centered_pos.x,  // Row 0: X basis + origin.x
                0.0, 1.0, 0.0, centered_pos.y,  // Row 1: Y basis + origin.y
                0.0, 0.0, 1.0, centered_pos.z,  // Row 2: Z basis + origin.z
            ];
            
            // Calculate z-depth color
            let z_normalized = (*z as f32 / dimensions.z).clamp(0.0, 1.0);
            let red_intensity = (1.0 - z_normalized).max(0.2);  // Front bright, back dark
            let color_data = [red_intensity, 0.0, 0.0, 1.0];  // Red gradient with full alpha
            
            // Store results (thread-safe)
            transforms_mutex.lock().unwrap().extend_from_slice(&transform_data);
            colors_mutex.lock().unwrap().extend_from_slice(&color_data);
        });
        
        // Convert to Godot PackedArrays
        let transforms = transforms_mutex.into_inner().unwrap();
        let colors = colors_mutex.into_inner().unwrap();
        let actual_count = transforms.len() / 12;
        
        let mut transforms_array = PackedFloat32Array::new();
        for &val in &transforms {
            transforms_array.push(val);
        }
        
        let mut colors_array = PackedFloat32Array::new();
        for &val in &colors {
            colors_array.push(val);
        }
        
        let processing_time = start_time.elapsed().as_micros() as i64;
        
        godot_print!(
            "🦀 [RUST-VIZ] Processed {} neurons in {} µs ({:.2} ms) - {:.1}x faster than 10k GDScript limit",
            actual_count,
            processing_time,
            processing_time as f64 / 1000.0,
            (actual_count as f64 * 8.0) / processing_time as f64  // Estimate speedup
        );
        
        // Return result dictionary
        let mut result = Dictionary::new();
        result.set("success", true);
        result.set("transforms", transforms_array);
        result.set("colors", colors_array);
        result.set("neuron_count", actual_count as i32);
        result.set("processing_time_us", processing_time);
        result.set("error", "");
        
        result
    }

    /// Process pre-deserialized neuron arrays for visualization (optimized path)
    /// This is used when arrays are already deserialized and we just need transforms/colors
    /// 
    /// Args:
    ///   - x_array, y_array, z_array: Neuron coordinates
    ///   - dimensions: Cortical area dimensions
    ///   - max_neurons: Maximum neurons to process (0 = unlimited)
    /// 
    /// Returns: Same dictionary format as process_neuron_visualization
    #[func]
    pub fn process_arrays_for_visualization(
        &self,
        x_array: PackedInt32Array,
        y_array: PackedInt32Array,
        z_array: PackedInt32Array,
        dimensions: Vector3,
        max_neurons: i32,
    ) -> Dictionary {
        let start_time = std::time::Instant::now();
        
        // Validate array sizes
        let array_len = x_array.len();
        if array_len != y_array.len() || array_len != z_array.len() {
            godot_error!("🦀 Array size mismatch: x={}, y={}, z={}", array_len, y_array.len(), z_array.len());
            return self.create_visualization_error_dict(
                "Array size mismatch".to_string(),
                start_time.elapsed().as_micros() as i64
            );
        }
        
        if array_len == 0 {
            return self.create_visualization_error_dict(
                "Empty arrays".to_string(),
                start_time.elapsed().as_micros() as i64
            );
        }
        
        // Apply limit if specified
        let process_count = if max_neurons > 0 {
            std::cmp::min(array_len, max_neurons as usize)
        } else {
            array_len
        };
        
        // Pre-calculate constants
        let half_dimensions = Vector3::new(
            dimensions.x / 2.0,
            dimensions.y / 2.0,
            dimensions.z / 2.0,
        );
        let offset = Vector3::new(0.5, 0.5, 0.5);
        let scale = Vector3::new(
            1.0 / dimensions.x,
            1.0 / dimensions.y,
            1.0 / -dimensions.z,
        );
        
        // Pre-allocate result vectors
        let mut transforms = Vec::with_capacity(process_count * 12);
        let mut colors = Vec::with_capacity(process_count * 4);
        
        // Collect coordinates for parallel processing
        let coords: Vec<(i32, i32, i32)> = (0..process_count)
            .map(|i| (x_array[i], y_array[i], z_array[i]))
            .collect();
        
        // Parallel processing using Rayon
        let results: Vec<([f32; 12], [f32; 4])> = coords
            .par_iter()
            .map(|(x, y, z)| {
                // Calculate transform
                let feagi_pos = Vector3::new(*x as f32, *y as f32, *z as f32);
                let centered_pos = Vector3::new(
                    (feagi_pos.x - half_dimensions.x + offset.x) * scale.x,
                    (feagi_pos.y - half_dimensions.y + offset.y) * scale.y,
                    (feagi_pos.z - half_dimensions.z + offset.z) * scale.z,
                );
                
                // Transform as 3x4 matrix
                let transform_data = [
                    1.0, 0.0, 0.0, centered_pos.x,
                    0.0, 1.0, 0.0, centered_pos.y,
                    0.0, 0.0, 1.0, centered_pos.z,
                ];
                
                // Calculate z-depth color
                let z_normalized = (*z as f32 / dimensions.z).clamp(0.0, 1.0);
                let red_intensity = (1.0 - z_normalized).max(0.2);
                let color_data = [red_intensity, 0.0, 0.0, 1.0];
                
                (transform_data, color_data)
            })
            .collect();
        
        // Flatten results into output vectors
        for (transform, color) in results {
            transforms.extend_from_slice(&transform);
            colors.extend_from_slice(&color);
        }
        
        // Convert to Godot PackedArrays
        let mut transforms_array = PackedFloat32Array::new();
        for &val in &transforms {
            transforms_array.push(val);
        }
        
        let mut colors_array = PackedFloat32Array::new();
        for &val in &colors {
            colors_array.push(val);
        }
        
        let processing_time = start_time.elapsed().as_micros() as i64;
        
        godot_print!(
            "🦀 [RUST-ARRAYS] Processed {} neurons in {} µs ({:.2} ms)",
            process_count,
            processing_time,
            processing_time as f64 / 1000.0
        );
        
        // Return result dictionary
        let mut result = Dictionary::new();
        result.set("success", true);
        result.set("transforms", transforms_array);
        result.set("colors", colors_array);
        result.set("neuron_count", process_count as i32);
        result.set("processing_time_us", processing_time);
        result.set("error", "");
        
        result
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

    /// Create error dictionary for visualization processing
    fn create_visualization_error_dict(&self, error_msg: String, processing_time_us: i64) -> Dictionary {
        let mut error_dict = Dictionary::new();
        error_dict.set("success", false);
        error_dict.set("error", error_msg);
        error_dict.set("transforms", PackedFloat32Array::new());
        error_dict.set("colors", PackedFloat32Array::new());
        error_dict.set("neuron_count", 0);
        error_dict.set("processing_time_us", processing_time_us);
        error_dict
    }
}
