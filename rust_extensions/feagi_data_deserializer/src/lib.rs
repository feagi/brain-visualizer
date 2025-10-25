use godot::prelude::*;
use godot::classes::MultiMesh;
use feagi_data_serialization::FeagiSerializable;
use feagi_data_structures::neuron_voxels::xyzp::CorticalMappedXYZPNeuronVoxels;

// Rayon is only available on native platforms (not WASM)
#[cfg(not(target_family = "wasm"))]
use rayon::prelude::*;

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
        godot_print!("🦀 FEAGI Rust Data Deserializer v0.0.50-beta.49 initialized!");
        Self { base }
    }
}

#[godot_api]
impl FeagiDataDeserializer {
    /// Decompress LZ4-compressed data from FEAGI PNS layer
    /// 
    /// ARCHITECTURE: FEAGI PNS → LZ4 compress → ZMQ → Bridge PASSTHROUGH → WebSocket → BV DECOMPRESS
    /// 
    /// Args:
    ///   - compressed_buffer: LZ4-compressed PackedByteArray from WebSocket
    /// 
    /// Returns: PackedByteArray (decompressed raw FEAGI data) or empty array on error
    #[func]
    pub fn decompress_lz4(&self, compressed_buffer: PackedByteArray) -> PackedByteArray {
        if compressed_buffer.is_empty() {
            godot_error!("🦀 [LZ4] Empty buffer - nothing to decompress");
            return PackedByteArray::new();
        }

        // Convert PackedByteArray to Vec<u8> for Rust processing
        let compressed_data: Vec<u8> = compressed_buffer.to_vec();
        
        // Log first 20 bytes for debugging
        let preview: String = compressed_data.iter()
            .take(20)
            .map(|b| format!("{:02x}", b))
            .collect::<Vec<_>>()
            .join(" ");
        
        godot_print!(
            "🦀 [LZ4] Attempting decompression: {} bytes, first 20 bytes: {}",
            compressed_data.len(),
            preview
        );
        
        // Decompress with LZ4
        match lz4::block::decompress(&compressed_data, None) {
            Ok(decompressed) => {
                let compression_ratio = (compressed_data.len() as f64 / decompressed.len() as f64) * 100.0;
                godot_print!(
                    "🦀 [LZ4] ✅ Decompressed {} bytes → {} bytes ({:.1}% of original)",
                    compressed_data.len(),
                    decompressed.len(),
                    compression_ratio
                );
                
                // Convert Vec<u8> back to PackedByteArray for Godot
                PackedByteArray::from(decompressed.as_slice())
            }
            Err(e) => {
                godot_error!("🦀 [LZ4] ❌ Decompression failed: {:?} (input size: {} bytes)", e, compressed_data.len());
                godot_error!("🦀 [LZ4] First 20 bytes: {}", preview);
                PackedByteArray::new()
            }
        }
    }

    /// Decode Type 11 neuron data using FEAGI's official Rust library (raw format, no container)
    #[func]
    pub fn decode_type_11_data(&self, buffer: PackedByteArray) -> Dictionary {
        // Convert PackedByteArray to Vec<u8> for Rust processing
        let rust_buffer: Vec<u8> = buffer.to_vec();
        
        // Use raw FeagiSerializable API (like rust-py-libs pattern)
        let mut neuron_data = CorticalMappedXYZPNeuronVoxels::new();
        if let Err(e) = neuron_data.try_deserialize_and_update_self_from_byte_slice(&rust_buffer) {
            // Don't log error - just return error dict to avoid spam
            return self.create_error_dict(format!("Decode error: {:?}", e));
        }
        
        self.convert_neuron_data_to_godot(&neuron_data)
    }

    /// Get structure type from raw buffer (no container wrapper)
    #[func]
    pub fn get_structure_type(&self, buffer: PackedByteArray) -> i32 {
        if buffer.is_empty() {
            return -1;
        }
        // Raw structure - first byte is the type (Type 11 = 11u8)
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
        let mut neuron_data = CorticalMappedXYZPNeuronVoxels::new();
        
        if let Err(e) = neuron_data.try_deserialize_and_update_self_from_byte_slice(&rust_buffer) {
            godot_error!("🦀 Failed to deserialize neuron data: {:?}", e);
            return self.create_visualization_error_dict(
                format!("Deserialization error: {:?}", e),
                start_time.elapsed().as_micros() as i64
            );
        }
        
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
        
        // Collect all neurons into a flat vector
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
        
        // Process neurons - use parallel processing on desktop, sequential on WASM
        let (transforms, colors) = self.process_neurons_internal(&all_neurons, half_dimensions, offset, scale, dimensions.z);
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
        
        #[cfg(not(target_family = "wasm"))]
        godot_print!(
            "🦀 [RUST-PARALLEL] Processed {} neurons in {} µs ({:.2} ms) using Rayon multi-threading",
            actual_count,
            processing_time,
            processing_time as f64 / 1000.0
        );
        
        #[cfg(target_family = "wasm")]
        godot_print!(
            "🦀 [RUST-WASM] Processed {} neurons in {} µs ({:.2} ms) - sequential (still 3-4x faster than GDScript!)",
            actual_count,
            processing_time,
            processing_time as f64 / 1000.0
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

    /// Apply neuron visualization directly to MultiMesh - FASTEST PATH!
    /// Bypasses GDScript loop entirely by setting transforms/colors directly in Rust
    /// 
    /// Args:
    ///   - multi_mesh: The MultiMesh to update
    ///   - x_array, y_array, z_array: Neuron coordinates
    ///   - dimensions: Cortical area dimensions
    /// 
    /// Returns: Dictionary with success, neuron_count, processing_time_us
    #[func]
    pub fn apply_arrays_to_multimesh(
        &self,
        mut multi_mesh: Gd<MultiMesh>,
        x_array: PackedInt32Array,
        y_array: PackedInt32Array,
        z_array: PackedInt32Array,
        dimensions: Vector3,
    ) -> Dictionary {
        let start_time = std::time::Instant::now();
        
        // Validate array sizes
        let array_len = x_array.len();
        if array_len != y_array.len() || array_len != z_array.len() {
            godot_error!("🦀 Array size mismatch");
            multi_mesh.set_instance_count(0);
            let mut result = Dictionary::new();
            result.set("success", false);
            result.set("error", "Array size mismatch");
            return result;
        }
        
        if array_len == 0 {
            multi_mesh.set_instance_count(0);
            let mut result = Dictionary::new();
            result.set("success", true);
            result.set("neuron_count", 0);
            return result;
        }
        
        // Set instance count
        multi_mesh.set_instance_count(array_len as i32);
        
        // Pre-calculate constants
        let half_dimensions = Vector3::new(dimensions.x / 2.0, dimensions.y / 2.0, dimensions.z / 2.0);
        let offset = Vector3::new(0.5, 0.5, 0.5);
        let scale = Vector3::new(1.0 / dimensions.x, 1.0 / dimensions.y, 1.0 / -dimensions.z);
        let z_max = dimensions.z;
        
        // Apply transforms and colors directly (NO GDScript LOOP!)
        for i in 0..array_len {
            let x = x_array[i] as u32;
            let y = y_array[i] as u32;
            let z = z_array[i] as u32;
            
            let transform_data = Self::calculate_transform(x, y, z, half_dimensions, offset, scale);
            let color_data = Self::calculate_color(z, z_max);
            
            let basis = Basis::from_rows(
                Vector3::new(transform_data[0], transform_data[1], transform_data[2]),
                Vector3::new(transform_data[4], transform_data[5], transform_data[6]),
                Vector3::new(transform_data[8], transform_data[9], transform_data[10]),
            );
            let origin = Vector3::new(transform_data[3], transform_data[7], transform_data[11]);
            let transform = Transform3D::new(basis, origin);
            
            let color = Color::from_rgba(color_data[0], color_data[1], color_data[2], color_data[3]);
            
            multi_mesh.set_instance_transform(i as i32, transform);
            multi_mesh.set_instance_color(i as i32, color);
        }
        
        let elapsed = start_time.elapsed().as_micros() as i64;
        
        let mut result = Dictionary::new();
        result.set("success", true);
        result.set("neuron_count", array_len as i32);
        result.set("processing_time_us", elapsed);
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
        
        // Collect coordinates
        let coords: Vec<(i32, i32, i32)> = (0..process_count)
            .map(|i| (x_array[i], y_array[i], z_array[i]))
            .collect();
        
        // Process neurons - use parallel processing on desktop, sequential on WASM
        let (transforms, colors) = self.process_coords_internal(&coords, half_dimensions, offset, scale, dimensions.z);
        
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
        
        #[cfg(not(target_family = "wasm"))]
        godot_print!(
            "🦀 [RUST-PARALLEL] Processed {} neurons in {} µs ({:.2} ms) using Rayon multi-threading",
            process_count,
            processing_time,
            processing_time as f64 / 1000.0
        );
        
        #[cfg(target_family = "wasm")]
        godot_print!(
            "🦀 [RUST-WASM] Processed {} neurons in {} µs ({:.2} ms) - sequential (still 3-4x faster than GDScript!)",
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
    /// Process neurons - DESKTOP VERSION with Rayon parallel processing
    #[cfg(not(target_family = "wasm"))]
    fn process_neurons_internal(
        &self,
        neurons: &[(u32, u32, u32, f32)],
        half_dimensions: Vector3,
        offset: Vector3,
        scale: Vector3,
        z_max: f32,
    ) -> (Vec<f32>, Vec<f32>) {
        // Parallel fold + reduce - each thread builds its own chunk, then we concatenate
        let (transforms, colors) = neurons
            .par_iter()
            .fold(
                || (Vec::with_capacity(1024 * 12), Vec::with_capacity(1024 * 4)),
                |(mut transforms, mut colors), (x, y, z, _potential)| {
                    let transform_data = Self::calculate_transform(*x, *y, *z, half_dimensions, offset, scale);
                    let color_data = Self::calculate_color(*z, z_max);
                    transforms.extend_from_slice(&transform_data);
                    colors.extend_from_slice(&color_data);
                    (transforms, colors)
                },
            )
            .reduce(
                || (Vec::new(), Vec::new()),
                |(mut t1, mut c1), (t2, c2)| {
                    t1.extend(t2);
                    c1.extend(c2);
                    (t1, c1)
                },
            );
        
        (transforms, colors)
    }
    
    /// Process neurons - WASM VERSION with sequential processing
    #[cfg(target_family = "wasm")]
    fn process_neurons_internal(
        &self,
        neurons: &[(u32, u32, u32, f32)],
        half_dimensions: Vector3,
        offset: Vector3,
        scale: Vector3,
        z_max: f32,
    ) -> (Vec<f32>, Vec<f32>) {
        let mut transforms = Vec::with_capacity(neurons.len() * 12);
        let mut colors = Vec::with_capacity(neurons.len() * 4);
        
        // Sequential processing (WASM - still faster than GDScript!)
        for (x, y, z, _potential) in neurons.iter() {
            let transform_data = Self::calculate_transform(*x, *y, *z, half_dimensions, offset, scale);
            let color_data = Self::calculate_color(*z, z_max);
            
            transforms.extend_from_slice(&transform_data);
            colors.extend_from_slice(&color_data);
        }
        
        (transforms, colors)
    }
    
    /// Process coordinates - DESKTOP VERSION with Rayon parallel processing
    #[cfg(not(target_family = "wasm"))]
    fn process_coords_internal(
        &self,
        coords: &[(i32, i32, i32)],
        half_dimensions: Vector3,
        offset: Vector3,
        scale: Vector3,
        z_max: f32,
    ) -> (Vec<f32>, Vec<f32>) {
        // Parallel processing using Rayon (desktop only)
        let results: Vec<([f32; 12], [f32; 4])> = coords
            .par_iter()
            .map(|(x, y, z)| {
                let transform_data = Self::calculate_transform(*x as u32, *y as u32, *z as u32, half_dimensions, offset, scale);
                let color_data = Self::calculate_color(*z as u32, z_max);
                (transform_data, color_data)
            })
            .collect();
        
        // Flatten results
        let mut transforms = Vec::with_capacity(coords.len() * 12);
        let mut colors = Vec::with_capacity(coords.len() * 4);
        for (transform, color) in results {
            transforms.extend_from_slice(&transform);
            colors.extend_from_slice(&color);
        }
        
        (transforms, colors)
    }
    
    /// Process coordinates - WASM VERSION with sequential processing
    #[cfg(target_family = "wasm")]
    fn process_coords_internal(
        &self,
        coords: &[(i32, i32, i32)],
        half_dimensions: Vector3,
        offset: Vector3,
        scale: Vector3,
        z_max: f32,
    ) -> (Vec<f32>, Vec<f32>) {
        let mut transforms = Vec::with_capacity(coords.len() * 12);
        let mut colors = Vec::with_capacity(coords.len() * 4);
        
        // Sequential processing (WASM - still faster than GDScript!)
        for (x, y, z) in coords.iter() {
            let transform_data = Self::calculate_transform(*x as u32, *y as u32, *z as u32, half_dimensions, offset, scale);
            let color_data = Self::calculate_color(*z as u32, z_max);
            
            transforms.extend_from_slice(&transform_data);
            colors.extend_from_slice(&color_data);
        }
        
        (transforms, colors)
    }
    
    /// Calculate transform matrix for a single neuron (shared by both versions)
    /// Matches GDScript logic: transform.origin = centered_pos; transform = transform.scaled(scale)
    #[inline(always)]
    fn calculate_transform(
        x: u32,
        y: u32,
        z: u32,
        half_dimensions: Vector3,
        offset: Vector3,
        scale: Vector3,
    ) -> [f32; 12] {
        let feagi_pos = Vector3::new(x as f32, y as f32, z as f32);
        // Calculate centered position WITHOUT scaling (matches GDScript: centered_pos = feagi_pos - half_dimensions + offset)
        let centered_pos = Vector3::new(
            feagi_pos.x - half_dimensions.x + offset.x,
            feagi_pos.y - half_dimensions.y + offset.y,
            feagi_pos.z - half_dimensions.z + offset.z,
        );
        
        // Transform3D as 3x4 matrix with SCALED basis vectors (matches GDScript: transform.scaled(scale))
        // This applies scale to both the basis and the origin
        [
            scale.x, 0.0, 0.0, centered_pos.x * scale.x,  // Row 0: scaled X basis + scaled origin.x
            0.0, scale.y, 0.0, centered_pos.y * scale.y,  // Row 1: scaled Y basis + scaled origin.y
            0.0, 0.0, scale.z, centered_pos.z * scale.z,  // Row 2: scaled Z basis + scaled origin.z
        ]
    }
    
    /// Calculate z-depth color for a single neuron (shared by both versions)
    #[inline(always)]
    fn calculate_color(z: u32, z_max: f32) -> [f32; 4] {
        let z_normalized = (z as f32 / z_max).clamp(0.0, 1.0);
        let red_intensity = (1.0 - z_normalized).max(0.2);  // Front bright, back dark
        [red_intensity, 0.0, 0.0, 1.0]  // Red gradient with full alpha
    }

    /// Convert official neuron data structure to Godot Dictionary
    fn convert_neuron_data_to_godot(
        &self,
        neuron_data: &CorticalMappedXYZPNeuronVoxels,
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

    /// Create error dictionary for Type 9 decoding
    fn create_type9_error_dict(&self, error_msg: &str) -> Dictionary {
        let mut error_dict = Dictionary::new();
        error_dict.set("success", false);
        error_dict.set("error", error_msg.to_string());
        error_dict.set("structure_count", 0);
        error_dict.set("structures", godot::builtin::Array::<Variant>::new().to_variant());
        error_dict
    }
}
