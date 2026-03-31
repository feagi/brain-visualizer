use godot::classes::MultiMesh;
use godot::prelude::*;
// FeagiByteContainer is imported within functions where needed
use feagi_serialization::FeagiSerializable;
use feagi_structures::genomic::cortical_area::descriptors::{
    CorticalSubUnitIndex, CorticalUnitIndex,
};
use feagi_structures::genomic::cortical_area::io_cortical_area_configuration_flag::{
    FrameChangeHandling, IOCorticalAreaConfigurationFlagBitmask, PercentageNeuronPositioning,
};
use feagi_structures::genomic::cortical_area::CorticalID;
use feagi_structures::genomic::cortical_area::IOCorticalAreaConfigurationFlag;
use feagi_structures::neuron_voxels::xyzp::CorticalMappedXYZPNeuronVoxels;

// Rayon is only available on native platforms (not WASM)
#[cfg(not(target_family = "wasm"))]
use rayon::prelude::*;

/// Cortical dimensions must be positive finite voxel counts; otherwise scale uses div-by-zero or NaN (GPU risk).
fn dimensions_valid_for_neuron_multimesh(dimensions: Vector3) -> bool {
    dimensions.x.is_finite()
        && dimensions.y.is_finite()
        && dimensions.z.is_finite()
        && dimensions.x > 0.0
        && dimensions.y > 0.0
        && dimensions.z > 0.0
}

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
        let preview: String = compressed_data
            .iter()
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
                let compression_ratio =
                    (compressed_data.len() as f64 / decompressed.len() as f64) * 100.0;
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
                godot_error!(
                    "🦀 [LZ4] ❌ Decompression failed: {:?} (input size: {} bytes)",
                    e,
                    compressed_data.len()
                );
                godot_error!("🦀 [LZ4] First 20 bytes: {}", preview);
                PackedByteArray::new()
            }
        }
    }

    /// Decode Type 11 neuron data (handles both raw Type 11 and FeagiByteContainer wrappers)
    #[func]
    pub fn decode_type_11_data(&self, buffer: PackedByteArray) -> Dictionary {
        // Convert PackedByteArray to Vec<u8> for Rust processing
        let rust_buffer: Vec<u8> = buffer.to_vec();

        if rust_buffer.is_empty() {
            return self.create_error_dict("Empty buffer".to_string());
        }

        // Detect format based on first byte
        let first_byte = rust_buffer[0];

        // Log for debugging
        let _preview: String = rust_buffer
            .iter()
            .take(20)
            .map(|b| format!("{:02x}", b))
            .collect::<Vec<_>>()
            .join(" ");
        // godot_print!("🦀 [PROC] Buf: {} bytes, first byte: 0x{:02x}, preview: {}",
        //             rust_buffer.len(), first_byte, preview);

        // Canonical pipeline (transport-independent):
        // - FEAGI produces FeagiByteContainer (v2 first byte == 2, v3 first byte == 3) containing Type 11 structures
        // - SHM transports the bytes as-is (no compression required)
        // - WS may optionally compress at the transport layer, but BV should only decode the canonical bytes
        //
        // Therefore, we do NOT require LZ4 here. We decode either:
        // - FeagiByteContainer v2 or v3 (first byte == 2 or 3)
        // - Raw Type 11 struct bytes (first byte == 11) if the container was unwrapped upstream
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(move || {
            use feagi_serialization::FeagiByteContainer;
            use feagi_structures::neuron_voxels::xyzp::CorticalMappedXYZPNeuronVoxels;

            let is_container =
                first_byte == 2 || first_byte == FeagiByteContainer::CURRENT_FBS_VERSION;
            if is_container {
                // FeagiByteContainer v2 or v3
                let mut byte_container = FeagiByteContainer::new_empty();
                let mut data_vec = rust_buffer;

                if let Err(e) =
                    byte_container.try_write_data_to_container_and_verify(&mut |bytes| {
                        std::mem::swap(bytes, &mut data_vec);
                        Ok(())
                    })
                {
                    return Err(format!("{:?}", e));
                }

                let num_structures = byte_container
                    .try_get_number_contained_structures()
                    .map_err(|e| format!("{:?}", e))?;
                if num_structures == 0 {
                    return Err("Empty container".to_string());
                }

                let boxed_struct = byte_container
                    .try_create_new_struct_from_index(0)
                    .map_err(|e| format!("{:?}", e))?;

                let neuron_data = boxed_struct
                    .as_any()
                    .downcast_ref::<CorticalMappedXYZPNeuronVoxels>()
                    .ok_or_else(|| "Wrong structure type".to_string())?;

                Ok(self.convert_neuron_data_to_godot(neuron_data))
            } else if first_byte == 11 {
                // Raw Type 11 struct bytes
                let mut neuron_data = CorticalMappedXYZPNeuronVoxels::new();
                neuron_data
                    .try_deserialize_and_update_self_from_byte_slice(&rust_buffer)
                    .map_err(|e| format!("{:?}", e))?;
                Ok(self.convert_neuron_data_to_godot(&neuron_data))
            } else {
                Err(format!("Unsupported first byte: {}", first_byte))
            }
        })) {
            Ok(Ok(dict)) => dict,
            Ok(Err(e)) => {
                godot_error!("🦀 [DECODE] Type 11 decode failed: {}", e);
                self.create_error_dict(e)
            }
            Err(_) => {
                godot_error!("🦀 [DECODE] Type 11 decode PANICKED!");
                self.create_error_dict("Type 11 decode panic".to_string())
            }
        }
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
        if rust_buffer.is_empty() {
            return self.create_visualization_error_dict(
                "Empty buffer".to_string(),
                start_time.elapsed().as_micros() as i64,
            );
        }
        let first_byte = rust_buffer[0];

        // Canonical pipeline (transport-independent):
        // - FeagiByteContainer v2 or v3 (first byte == 2 or 3) containing Type 11
        // - Or raw Type 11 (first byte == 11) if upstream unwrapped the container
        // Always materialize an owned CorticalMappedXYZPNeuronVoxels so we can safely
        // use it for the duration of this function without borrowing temporary objects.
        use feagi_serialization::FeagiByteContainer;
        let is_container = first_byte == 2 || first_byte == FeagiByteContainer::CURRENT_FBS_VERSION;
        let neuron_data_owned: CorticalMappedXYZPNeuronVoxels = if is_container {
            let mut byte_container = FeagiByteContainer::new_empty();
            let mut data_vec = rust_buffer;
            if let Err(e) = byte_container.try_write_data_to_container_and_verify(&mut |bytes| {
                std::mem::swap(bytes, &mut data_vec);
                Ok(())
            }) {
                godot_error!("🦀 Failed to load FeagiByteContainer: {:?}", e);
                return self.create_visualization_error_dict(
                    format!("FeagiByteContainer error: {:?}", e),
                    start_time.elapsed().as_micros() as i64,
                );
            }
            let boxed_struct = match byte_container.try_create_new_struct_from_index(0) {
                Ok(s) => s,
                Err(e) => {
                    godot_error!("🦀 Failed to extract structure: {:?}", e);
                    return self.create_visualization_error_dict(
                        format!("Structure extract error: {:?}", e),
                        start_time.elapsed().as_micros() as i64,
                    );
                }
            };
            match boxed_struct
                .as_any()
                .downcast_ref::<CorticalMappedXYZPNeuronVoxels>()
            {
                Some(nd) => nd.clone(),
                None => {
                    godot_error!("🦀 Structure is not CorticalMappedXYZPNeuronVoxels");
                    return self.create_visualization_error_dict(
                        "Wrong structure type".to_string(),
                        start_time.elapsed().as_micros() as i64,
                    );
                }
            }
        } else if first_byte == 11 {
            let mut nd = CorticalMappedXYZPNeuronVoxels::new();
            if let Err(e) = nd.try_deserialize_and_update_self_from_byte_slice(&rust_buffer) {
                godot_error!("🦀 Type 11 deserialize failed: {:?}", e);
                return self.create_visualization_error_dict(
                    format!("Type 11 deserialize error: {:?}", e),
                    start_time.elapsed().as_micros() as i64,
                );
            }
            nd
        } else {
            godot_error!("🦀 Unsupported payload first byte: {}", first_byte);
            return self.create_visualization_error_dict(
                format!("Unsupported payload first byte: {}", first_byte),
                start_time.elapsed().as_micros() as i64,
            );
        };
        let neuron_data_ref: &CorticalMappedXYZPNeuronVoxels = &neuron_data_owned;

        // Count total neurons
        let total_neurons: usize = neuron_data_ref.mappings.values().map(|arr| arr.len()).sum();

        // Apply limit if specified
        let process_count = if max_neurons > 0 {
            std::cmp::min(total_neurons, max_neurons as usize)
        } else {
            total_neurons
        };

        // Pre-calculate constants
        let half_dimensions =
            Vector3::new(dimensions.x / 2.0, dimensions.y / 2.0, dimensions.z / 2.0);
        let offset = Vector3::ZERO;
        let scale = Vector3::new(
            1.0 / dimensions.x,
            1.0 / dimensions.y,
            1.0 / -dimensions.z, // Note: negative Z
        );

        // Collect all neurons into a flat vector
        let mut all_neurons = Vec::with_capacity(process_count);
        for (_, neuron_array) in neuron_data_ref.mappings.iter() {
            for neuron in neuron_array.iter() {
                if all_neurons.len() >= process_count {
                    break;
                }
                all_neurons.push((
                    neuron.neuron_voxel_coordinate.x,
                    neuron.neuron_voxel_coordinate.y,
                    neuron.neuron_voxel_coordinate.z,
                    neuron.potential,
                ));
            }
            if all_neurons.len() >= process_count {
                break;
            }
        }

        // Process neurons - use parallel processing on desktop, sequential on WASM
        let (transforms, colors) = self.process_neurons_internal(
            &all_neurons,
            half_dimensions,
            offset,
            scale,
            dimensions.z,
        );
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

        if !dimensions_valid_for_neuron_multimesh(dimensions) {
            godot_error!("Invalid cortical dimensions for multimesh (must be finite and > 0)");
            multi_mesh.set_instance_count(0);
            let mut result = Dictionary::new();
            result.set("success", false);
            result.set("error", "Invalid dimensions for multimesh (finite, > 0 required)");
            return result;
        }

        // Set instance count
        multi_mesh.set_instance_count(array_len as i32);

        // Pre-calculate constants.
        let half_dimensions =
            Vector3::new(dimensions.x / 2.0, dimensions.y / 2.0, dimensions.z / 2.0);
        let offset = Vector3::ZERO;
        let scale = Vector3::new(1.0 / dimensions.x, 1.0 / dimensions.y, 1.0 / -dimensions.z);
        let z_max = dimensions.z;
        let max_x = (dimensions.x as u32).saturating_sub(1);
        let max_y = (dimensions.y as u32).saturating_sub(1);
        let max_z = (dimensions.z as u32).saturating_sub(1);

        // Apply transforms and colors directly (NO GDScript LOOP!)
        for i in 0..array_len {
            let x = (x_array[i] as u32).min(max_x);
            let y = (y_array[i] as u32).min(max_y);
            let z = (z_array[i] as u32).min(max_z);

            let transform_data = Self::calculate_transform(x, y, z, half_dimensions, offset, scale);
            let color_data = Self::calculate_color(z, z_max);

            let basis = Basis::from_rows(
                Vector3::new(transform_data[0], transform_data[1], transform_data[2]),
                Vector3::new(transform_data[4], transform_data[5], transform_data[6]),
                Vector3::new(transform_data[8], transform_data[9], transform_data[10]),
            );
            let origin = Vector3::new(transform_data[3], transform_data[7], transform_data[11]);
            let transform = Transform3D::new(basis, origin);

            let color =
                Color::from_rgba(color_data[0], color_data[1], color_data[2], color_data[3]);

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

    /// Desktop WS fast-path: decode a Type 11 packet and apply directly to MultiMeshes (GPU instancing).
    /// This avoids constructing per-area Dictionaries and large PackedArray payloads in GDScript.
    ///
    /// Args:
    ///  - buffer: raw WebSocket packet (LZ4 header + compressed FeagiByteContainer)
    ///  - multimeshes_by_id: Dictionary[cortical_id -> MultiMesh]
    ///  - dimensions_by_id: Dictionary[cortical_id -> Vector3]
    ///  - clear_all_before_apply: if true, sets instance_count=0 on all registered MultiMeshes first
    ///
    /// Returns Dictionary with timing breakdown (ms) and per-area neuron counts.
    #[func]
    pub fn apply_type11_packet_to_multimeshes(
        &self,
        buffer: PackedByteArray,
        multimeshes_by_id: Dictionary,
        dimensions_by_id: Dictionary,
        clear_all_before_apply: bool,
    ) -> Dictionary {
        let total_start = std::time::Instant::now();

        let mut out = Dictionary::new();
        out.set("success", false);
        out.set("error", "");
        out.set("lz4_ms", 0.0);
        out.set("container_parse_ms", 0.0);
        out.set("clear_ms", 0.0);
        out.set("multimesh_apply_ms", 0.0);
        out.set("total_ms", 0.0);
        out.set("areas_applied", 0);
        out.set("neurons_applied", 0);
        out.set("area_counts", Dictionary::new());

        let rust_buffer: Vec<u8> = buffer.to_vec();
        if rust_buffer.is_empty() {
            out.set("error", "Empty buffer");
            out.set("total_ms", total_start.elapsed().as_secs_f64() * 1000.0);
            return out;
        }

        // Parse + apply inside one unwind boundary to avoid cloning decoded neuron data.
        let parse_and_apply_start = std::time::Instant::now();
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(move || {
            use feagi_serialization::FeagiByteContainer;

            // Canonical pipeline (transport-independent):
            // - FeagiByteContainer v2 or v3 (first byte == 2 or 3) containing Type 11 structures
            // - Or raw Type 11 struct bytes (first byte == 11) if upstream unwrapped it
            let first_byte = rust_buffer[0];
            let is_container = first_byte == 2
                || first_byte == feagi_serialization::FeagiByteContainer::CURRENT_FBS_VERSION;
            let neuron_data_owned: CorticalMappedXYZPNeuronVoxels = if is_container {
                let mut byte_container = FeagiByteContainer::new_empty();
                let mut data_vec = rust_buffer;

                if let Err(e) =
                    byte_container.try_write_data_to_container_and_verify(&mut |bytes| {
                        std::mem::swap(bytes, &mut data_vec);
                        Ok(())
                    })
                {
                    return Err(format!("{:?}", e));
                }

                let num_structures = match byte_container.try_get_number_contained_structures() {
                    Ok(n) => n,
                    Err(e) => return Err(format!("{:?}", e)),
                };
                if num_structures == 0 {
                    return Err("Empty container".to_string());
                }

                let boxed_struct = match byte_container.try_create_new_struct_from_index(0) {
                    Ok(s) => s,
                    Err(e) => return Err(format!("{:?}", e)),
                };

                let neuron_data_ref = match boxed_struct
                    .as_any()
                    .downcast_ref::<CorticalMappedXYZPNeuronVoxels>()
                {
                    Some(nd) => nd,
                    None => return Err("Wrong structure type".to_string()),
                };
                neuron_data_ref.clone()
            } else if first_byte == 11 {
                let mut nd = CorticalMappedXYZPNeuronVoxels::new();
                if let Err(e) = nd.try_deserialize_and_update_self_from_byte_slice(&rust_buffer) {
                    return Err(format!("Type 11 deserialize error: {:?}", e));
                }
                nd
            } else {
                return Err(format!("Unsupported payload first byte: {}", first_byte));
            };
            let neuron_data_ref: &CorticalMappedXYZPNeuronVoxels = &neuron_data_owned;

            let container_parse_ms = parse_and_apply_start.elapsed().as_secs_f64() * 1000.0;

            // Clear all registered MultiMeshes first (optional but deterministic: no stale points).
            let clear_start = std::time::Instant::now();
            if clear_all_before_apply {
                for (_k, v) in multimeshes_by_id.iter_shared() {
                    if let Ok(mut mm) = v.try_to::<Gd<MultiMesh>>() {
                        mm.set_instance_count(0);
                    }
                }
            }
            let clear_ms = clear_start.elapsed().as_secs_f64() * 1000.0;

            let apply_start = std::time::Instant::now();
            let mut areas_applied: i32 = 0;
            let mut neurons_applied: i32 = 0;
            let mut area_counts = Dictionary::new();

            for (cortical_id, neuron_array) in neuron_data_ref.mappings.iter() {
                let num_neurons = neuron_array.len();
                if num_neurons == 0 {
                    continue;
                }

                let cortical_id_str = cortical_id.as_base_64();

                let mm_var = multimeshes_by_id.get(cortical_id_str.as_str());
                let dims_var = dimensions_by_id.get(cortical_id_str.as_str());
                let (mm_var, dims_var) = match (mm_var, dims_var) {
                    (Some(m), Some(d)) => (m, d),
                    _ => continue,
                };

                let mut multi_mesh = match mm_var.try_to::<Gd<MultiMesh>>() {
                    Ok(m) => m,
                    Err(_) => continue,
                };
                let dimensions = match dims_var.try_to::<Vector3>() {
                    Ok(d) => d,
                    Err(_) => continue,
                };
                if !dimensions_valid_for_neuron_multimesh(dimensions) {
                    continue;
                }

                // Set instance count and apply transforms/colors directly.
                multi_mesh.set_instance_count(num_neurons as i32);

                let half_dimensions =
                    Vector3::new(dimensions.x / 2.0, dimensions.y / 2.0, dimensions.z / 2.0);
                let offset = Vector3::ZERO;
                let scale =
                    Vector3::new(1.0 / dimensions.x, 1.0 / dimensions.y, 1.0 / -dimensions.z);
                let z_max = dimensions.z;
                let max_x = (dimensions.x as u32).saturating_sub(1);
                let max_y = (dimensions.y as u32).saturating_sub(1);
                let max_z = (dimensions.z as u32).saturating_sub(1);

                for (i, neuron) in neuron_array.iter().enumerate() {
                    let x = neuron.neuron_voxel_coordinate.x.min(max_x);
                    let y = neuron.neuron_voxel_coordinate.y.min(max_y);
                    let z = neuron.neuron_voxel_coordinate.z.min(max_z);

                    let transform_data =
                        Self::calculate_transform(x, y, z, half_dimensions, offset, scale);
                    let color_data = Self::calculate_color(z, z_max);

                    let basis = Basis::from_rows(
                        Vector3::new(transform_data[0], transform_data[1], transform_data[2]),
                        Vector3::new(transform_data[4], transform_data[5], transform_data[6]),
                        Vector3::new(transform_data[8], transform_data[9], transform_data[10]),
                    );
                    let origin =
                        Vector3::new(transform_data[3], transform_data[7], transform_data[11]);
                    let transform = Transform3D::new(basis, origin);

                    let color = Color::from_rgba(
                        color_data[0],
                        color_data[1],
                        color_data[2],
                        color_data[3],
                    );

                    multi_mesh.set_instance_transform(i as i32, transform);
                    multi_mesh.set_instance_color(i as i32, color);
                }

                areas_applied += 1;
                neurons_applied += num_neurons as i32;
                area_counts.set(cortical_id_str.as_str(), num_neurons as i32);
            }

            let multimesh_apply_ms = apply_start.elapsed().as_secs_f64() * 1000.0;
            Ok((
                container_parse_ms,
                clear_ms,
                multimesh_apply_ms,
                areas_applied,
                neurons_applied,
                area_counts,
            ))
        }));

        match result {
            Ok(Ok((
                container_parse_ms,
                clear_ms,
                multimesh_apply_ms,
                areas_applied,
                neurons_applied,
                area_counts,
            ))) => {
                out.set("container_parse_ms", container_parse_ms);
                out.set("clear_ms", clear_ms);
                out.set("multimesh_apply_ms", multimesh_apply_ms);
                out.set("areas_applied", areas_applied);
                out.set("neurons_applied", neurons_applied);
                out.set("area_counts", area_counts);
                out.set("success", true);
            }
            Ok(Err(e)) => {
                out.set("error", format!("FeagiByteContainer error: {}", e));
            }
            Err(_) => {
                out.set("error", "FeagiByteContainer panic");
            }
        }

        out.set("total_ms", total_start.elapsed().as_secs_f64() * 1000.0);
        out
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
            godot_error!(
                "🦀 Array size mismatch: x={}, y={}, z={}",
                array_len,
                y_array.len(),
                z_array.len()
            );
            return self.create_visualization_error_dict(
                "Array size mismatch".to_string(),
                start_time.elapsed().as_micros() as i64,
            );
        }

        if array_len == 0 {
            return self.create_visualization_error_dict(
                "Empty arrays".to_string(),
                start_time.elapsed().as_micros() as i64,
            );
        }

        // Apply limit if specified
        let process_count = if max_neurons > 0 {
            std::cmp::min(array_len, max_neurons as usize)
        } else {
            array_len
        };

        // Pre-calculate constants
        let half_dimensions =
            Vector3::new(dimensions.x / 2.0, dimensions.y / 2.0, dimensions.z / 2.0);
        let offset = Vector3::ZERO;
        let scale = Vector3::new(1.0 / dimensions.x, 1.0 / dimensions.y, 1.0 / -dimensions.z);
        let max_x = (dimensions.x as i32).saturating_sub(1).max(0);
        let max_y = (dimensions.y as i32).saturating_sub(1).max(0);
        let max_z = (dimensions.z as i32).saturating_sub(1).max(0);

        // Collect coordinates (clamped to area bounds to prevent overflow visualization)
        let coords: Vec<(i32, i32, i32)> = (0..process_count)
            .map(|i| {
                (
                    x_array[i].clamp(0, max_x),
                    y_array[i].clamp(0, max_y),
                    z_array[i].clamp(0, max_z),
                )
            })
            .collect();

        // Process neurons - use parallel processing on desktop, sequential on WASM
        let (transforms, colors) =
            self.process_coords_internal(&coords, half_dimensions, offset, scale, dimensions.z);

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

    /// Parse cortical ID to extract encoding information using FDP's actual methods
    ///
    /// Uses CorticalID::try_from_base_64() and IOCorticalAreaDataType::try_from_data_type_configuration_flag()
    /// to parse the binary structure exactly as FDP does.
    ///
    /// Returns: Dictionary with {success: bool, encoding_type: String, encoding_format: String, error: String}
    #[func]
    pub fn parse_cortical_id_encoding(&self, cortical_id: GString) -> Dictionary {
        let mut result = Dictionary::new();
        let id_str = cortical_id.to_string();

        // Use FDP's CorticalID parser (base64 only - legacy IDs do not have binary config)
        let cortical_id_obj = match CorticalID::try_from_base_64(&id_str) {
            Ok(id) => id,
            Err(e) => {
                result.set("success", false);
                result.set("error", format!("FDP CorticalID parse error: {}", e));
                result.set("encoding_type", "");
                result.set("encoding_format", "");
                return result;
            }
        };

        let bytes = cortical_id_obj.as_bytes();

        // Verify this is an IPU or OPU cortical area
        if bytes[0] != b'i' && bytes[0] != b'o' {
            result.set("success", false);
            result.set(
                "error",
                format!(
                    "Not an IPU/OPU cortical ID (first byte: {})",
                    bytes[0] as char
                ),
            );
            result.set("encoding_type", "");
            result.set("encoding_format", "");
            return result;
        }

        // Extract data_type_configuration from bytes 4-5 (u16, little-endian) per FDP spec
        let config: IOCorticalAreaConfigurationFlagBitmask =
            u16::from_le_bytes([bytes[4], bytes[5]]);

        // Use FDP's actual parsing method to decode the configuration
        let io_data_type =
            match IOCorticalAreaConfigurationFlag::try_from_data_type_configuration_flag(config) {
                Ok(dt) => dt,
                Err(e) => {
                    result.set("success", false);
                    result.set(
                        "error",
                        format!("FDP IOCorticalAreaConfigurationFlag parse error: {}", e),
                    );
                    result.set("encoding_type", "");
                    result.set("encoding_format", "");
                    return result;
                }
            };

        // Extract encoding_type from positioning enum
        let encoding_type = match io_data_type {
            IOCorticalAreaConfigurationFlag::Percentage(_, pos)
            | IOCorticalAreaConfigurationFlag::Percentage2D(_, pos)
            | IOCorticalAreaConfigurationFlag::Percentage3D(_, pos)
            | IOCorticalAreaConfigurationFlag::Percentage4D(_, pos)
            | IOCorticalAreaConfigurationFlag::SignedPercentage(_, pos)
            | IOCorticalAreaConfigurationFlag::SignedPercentage2D(_, pos)
            | IOCorticalAreaConfigurationFlag::SignedPercentage3D(_, pos)
            | IOCorticalAreaConfigurationFlag::SignedPercentage4D(_, pos) => match pos {
                PercentageNeuronPositioning::Linear => "linear",
                PercentageNeuronPositioning::Fractional => "exponential",
            },
            _ => "linear", // CartesianPlane, Misc, Boolean, etc. default to linear
        };

        // Extract encoding_format from data type variant
        let encoding_format = match io_data_type {
            IOCorticalAreaConfigurationFlag::Percentage(_, _)
            | IOCorticalAreaConfigurationFlag::SignedPercentage(_, _)
            | IOCorticalAreaConfigurationFlag::Boolean => "1d",

            IOCorticalAreaConfigurationFlag::Percentage2D(_, _)
            | IOCorticalAreaConfigurationFlag::SignedPercentage2D(_, _)
            | IOCorticalAreaConfigurationFlag::CartesianPlane(_) => "2d",

            IOCorticalAreaConfigurationFlag::Percentage3D(_, _)
            | IOCorticalAreaConfigurationFlag::SignedPercentage3D(_, _) => "3d",

            IOCorticalAreaConfigurationFlag::Percentage4D(_, _)
            | IOCorticalAreaConfigurationFlag::SignedPercentage4D(_, _) => "4d",

            IOCorticalAreaConfigurationFlag::Misc(_) => "1d",
        };

        let is_signed = matches!(
            io_data_type,
            IOCorticalAreaConfigurationFlag::SignedPercentage(_, _)
                | IOCorticalAreaConfigurationFlag::SignedPercentage2D(_, _)
                | IOCorticalAreaConfigurationFlag::SignedPercentage3D(_, _)
                | IOCorticalAreaConfigurationFlag::SignedPercentage4D(_, _)
        );
        result.set("success", true);
        result.set("encoding_type", encoding_type);
        result.set("encoding_format", encoding_format);
        result.set("is_signed", is_signed);
        result.set("error", "");

        result
    }

    /// Decode voxel coordinates using feagi-sensorimotor's single-voxel decode API.
    ///
    /// Uses the exact same decoding logic as feagi-sensorimotor's batch decoders so that
    /// Brain Visualizer display matches what a robot/controller would process.
    ///
    /// For base64 cortical IDs, encoding is read from the ID binary. For legacy ASCII IDs
    /// (e.g. "o_mctl"), the caller must provide encoding_type, encoding_format, is_signed
    /// from the cortical area (genome).
    ///
    /// Args:
    ///   - cortical_id: The cortical area ID (base64 or legacy ASCII)
    ///   - voxel_x, voxel_y, voxel_z: The voxel coordinates
    ///   - encoding_type, encoding_format, is_signed: From cortical area when ID has no binary config
    ///   - channel_dimensions_x, channel_dimensions_y, channel_dimensions_z: Dimensions per channel
    ///   - num_channels: Total number of channels (0 = treat as 1)
    ///
    /// Returns: Dictionary with {success: bool, channel: i32, value: f32, data_type: String, error: String}
    #[allow(clippy::too_many_arguments)]
    #[func]
    pub fn decode_fdp_value(
        &self,
        cortical_id: GString,
        voxel_x: i32,
        voxel_y: i32,
        voxel_z: i32,
        encoding_type: GString,
        encoding_format: GString,
        is_signed: bool,
        channel_dimensions_x: i32,
        channel_dimensions_y: i32,
        channel_dimensions_z: i32,
        num_channels: i32,
    ) -> Dictionary {
        use feagi_sensorimotor::single_voxel_decode::{
            decode_single_voxel, decode_single_voxel_from_encoding, ChannelDimensions,
        };

        let mut result = Dictionary::new();

        if voxel_x < 0 || voxel_y < 0 || voxel_z < 0 {
            result.set("success", false);
            result.set("error", "Invalid voxel coordinates (negative values)");
            result.set("channel", -1);
            result.set("value", 0.0);
            result.set("data_type", "");
            return result;
        }

        let cortical_id_obj = match CorticalID::try_from_base_64(&cortical_id.to_string()) {
            Ok(id) => id,
            Err(_) => {
                if let Ok(id) = CorticalID::try_from_legacy_ascii(&cortical_id.to_string()) {
                    id
                } else {
                    result.set("success", false);
                    result.set("error", "Invalid cortical ID");
                    result.set("channel", -1);
                    result.set("value", 0.0);
                    result.set("data_type", "");
                    return result;
                }
            }
        };

        let channel_dims = ChannelDimensions::new(
            channel_dimensions_x.max(1) as u32,
            channel_dimensions_y.max(1) as u32,
            channel_dimensions_z.max(1) as u32,
        );
        let device_count = if num_channels > 0 {
            num_channels as u32
        } else {
            1
        };

        let mut decode_result = decode_single_voxel(
            &cortical_id_obj,
            voxel_x as u32,
            voxel_y as u32,
            voxel_z as u32,
            channel_dims,
            device_count,
        );

        // When cortical ID has no binary config (legacy ASCII), use encoding from cortical area
        if !decode_result.success {
            let enc_type = encoding_type.to_string();
            let enc_fmt = encoding_format.to_string();
            if !enc_type.is_empty() && !enc_fmt.is_empty() {
                decode_result = decode_single_voxel_from_encoding(
                    &enc_type,
                    &enc_fmt,
                    is_signed,
                    voxel_x as u32,
                    voxel_y as u32,
                    voxel_z as u32,
                    channel_dims,
                    device_count,
                );
            }
        }

        result.set("success", decode_result.success);
        result.set("channel", decode_result.channel);
        result.set("value", decode_result.value_percent);
        result.set("data_type", decode_result.data_type);
        result.set("error", decode_result.error);

        result
    }

    /// Compute a new IO cortical ID using FDP's canonical encoding rules.
    ///
    /// This preserves unit identifiers and updates the encoding configuration
    /// based on the selected signage/behavior/type options.
    ///
    /// Returns: Dictionary {success: bool, cortical_id: String, error: String}
    #[func]
    pub fn compute_io_cortical_id(
        &self,
        cortical_id: GString,
        coding_signage: GString,
        coding_behavior: GString,
        coding_type: GString,
    ) -> Dictionary {
        let mut result = Dictionary::new();
        let id_str = cortical_id.to_string();

        let cortical_id_obj = match CorticalID::try_from_base_64(&id_str) {
            Ok(id) => id,
            Err(e) => {
                result.set("success", false);
                result.set("error", format!("Invalid cortical ID: {}", e));
                result.set("cortical_id", "");
                return result;
            }
        };

        let bytes = cortical_id_obj.as_bytes();
        let is_input = bytes[0] == b'i';
        let is_output = bytes[0] == b'o';
        if !is_input && !is_output {
            result.set("success", false);
            result.set("error", "Not an IPU/OPU cortical ID");
            result.set("cortical_id", "");
            return result;
        }

        let current_flag = match cortical_id_obj.extract_io_data_flag() {
            Ok(flag) => flag,
            Err(e) => {
                result.set("success", false);
                result.set("error", format!("Unable to decode IO configuration: {}", e));
                result.set("cortical_id", "");
                return result;
            }
        };

        let signage_raw = coding_signage.to_string().to_lowercase();
        let behavior_raw = coding_behavior.to_string().to_lowercase();
        let coding_type_raw = coding_type.to_string().to_lowercase();

        let parse_frame = |raw: &str| -> Option<FrameChangeHandling> {
            match raw.trim() {
                "absolute" => Some(FrameChangeHandling::Absolute),
                "incremental" => Some(FrameChangeHandling::Incremental),
                _ => None,
            }
        };
        let parse_positioning = |raw: &str| -> Option<PercentageNeuronPositioning> {
            match raw.trim() {
                "linear" => Some(PercentageNeuronPositioning::Linear),
                "fractional" => Some(PercentageNeuronPositioning::Fractional),
                _ => None,
            }
        };
        let parse_signage = |raw: &str| -> Option<bool> {
            if raw.contains("unsigned") {
                Some(false)
            } else if raw.contains("signed") {
                Some(true)
            } else {
                None
            }
        };

        let frame_override = parse_frame(&behavior_raw);
        let positioning_override = parse_positioning(&coding_type_raw);
        let signage_override = parse_signage(&signage_raw);

        let new_flag = match current_flag {
            IOCorticalAreaConfigurationFlag::Percentage(frame, positioning) => {
                let signed = signage_override.unwrap_or(false);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::Percentage2D(frame, positioning) => {
                let signed = signage_override.unwrap_or(false);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage2D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage2D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::Percentage3D(frame, positioning) => {
                let signed = signage_override.unwrap_or(false);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage3D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage3D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::Percentage4D(frame, positioning) => {
                let signed = signage_override.unwrap_or(false);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage4D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage4D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::SignedPercentage(frame, positioning) => {
                let signed = signage_override.unwrap_or(true);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::SignedPercentage2D(frame, positioning) => {
                let signed = signage_override.unwrap_or(true);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage2D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage2D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::SignedPercentage3D(frame, positioning) => {
                let signed = signage_override.unwrap_or(true);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage3D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage3D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::SignedPercentage4D(frame, positioning) => {
                let signed = signage_override.unwrap_or(true);
                let next_frame = frame_override.unwrap_or(frame);
                let next_pos = positioning_override.unwrap_or(positioning);
                if signed {
                    IOCorticalAreaConfigurationFlag::SignedPercentage4D(next_frame, next_pos)
                } else {
                    IOCorticalAreaConfigurationFlag::Percentage4D(next_frame, next_pos)
                }
            }
            IOCorticalAreaConfigurationFlag::CartesianPlane(frame) => {
                if signage_raw != "cartesian plane" && signage_raw != "not applicable" {
                    result.set("success", false);
                    result.set("error", "coding_signage not supported for Cartesian Plane");
                    result.set("cortical_id", "");
                    return result;
                }
                let next_frame = frame_override.unwrap_or(frame);
                IOCorticalAreaConfigurationFlag::CartesianPlane(next_frame)
            }
            IOCorticalAreaConfigurationFlag::Misc(frame) => {
                if signage_raw != "misc" && signage_raw != "not applicable" {
                    result.set("success", false);
                    result.set("error", "coding_signage not supported for Misc");
                    result.set("cortical_id", "");
                    return result;
                }
                let next_frame = frame_override.unwrap_or(frame);
                IOCorticalAreaConfigurationFlag::Misc(next_frame)
            }
            IOCorticalAreaConfigurationFlag::Boolean => {
                if signage_raw != "boolean" && signage_raw != "not applicable" {
                    result.set("success", false);
                    result.set("error", "coding_signage not supported for Boolean");
                    result.set("cortical_id", "");
                    return result;
                }
                IOCorticalAreaConfigurationFlag::Boolean
            }
        };

        let unit_identifier = [bytes[1], bytes[2], bytes[3]];
        let subunit_idx = bytes[6];
        let unit_idx = bytes[7];

        let new_id = new_flag.as_io_cortical_id(
            is_input,
            unit_identifier,
            CorticalUnitIndex::from(unit_idx),
            CorticalSubUnitIndex::from(subunit_idx),
        );

        result.set("success", true);
        result.set("cortical_id", new_id.as_base_64());
        result.set("error", "");
        result
    }

    /// Compute a new IO cortical ID by changing the unit index only.
    ///
    /// Returns: Dictionary {success: bool, cortical_id: String, error: String}
    #[func]
    pub fn compute_io_cortical_id_with_unit_index(
        &self,
        cortical_id: GString,
        unit_index: i64,
    ) -> Dictionary {
        let mut result = Dictionary::new();
        let id_str = cortical_id.to_string();

        let cortical_id_obj = match CorticalID::try_from_base_64(&id_str) {
            Ok(id) => id,
            Err(e) => {
                result.set("success", false);
                result.set("error", format!("Invalid cortical ID: {}", e));
                result.set("cortical_id", "");
                return result;
            }
        };

        if unit_index < 0 || unit_index > u8::MAX as i64 {
            result.set("success", false);
            result.set("error", "unit_index out of range");
            result.set("cortical_id", "");
            return result;
        }

        let bytes = cortical_id_obj.as_bytes();
        let is_input = bytes[0] == b'i';
        let is_output = bytes[0] == b'o';
        if !is_input && !is_output {
            result.set("success", false);
            result.set("error", "Not an IPU/OPU cortical ID");
            result.set("cortical_id", "");
            return result;
        }

        let current_flag = match cortical_id_obj.extract_io_data_flag() {
            Ok(flag) => flag,
            Err(e) => {
                result.set("success", false);
                result.set("error", format!("Unable to decode IO configuration: {}", e));
                result.set("cortical_id", "");
                return result;
            }
        };

        let unit_identifier = [bytes[1], bytes[2], bytes[3]];
        let subunit_idx = bytes[6];
        let new_id = current_flag.as_io_cortical_id(
            is_input,
            unit_identifier,
            CorticalUnitIndex::from(unit_index as u8),
            CorticalSubUnitIndex::from(subunit_idx),
        );

        result.set("success", true);
        result.set("cortical_id", new_id.as_base_64());
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
                    let transform_data =
                        Self::calculate_transform(*x, *y, *z, half_dimensions, offset, scale);
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
            let transform_data =
                Self::calculate_transform(*x, *y, *z, half_dimensions, offset, scale);
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
                let transform_data = Self::calculate_transform(
                    *x as u32,
                    *y as u32,
                    *z as u32,
                    half_dimensions,
                    offset,
                    scale,
                );
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
            let transform_data = Self::calculate_transform(
                *x as u32,
                *y as u32,
                *z as u32,
                half_dimensions,
                offset,
                scale,
            );
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
        // Centered position: feagi_pos - half_dimensions + offset (offset ZERO per NEURON_POSITION_SCALING_FIX.md)
        let centered_pos = Vector3::new(
            feagi_pos.x - half_dimensions.x + offset.x,
            feagi_pos.y - half_dimensions.y + offset.y,
            feagi_pos.z - half_dimensions.z + offset.z,
        );

        // Transform3D as 3x4 matrix with SCALED basis vectors (matches GDScript: transform.scaled(scale))
        // This applies scale to both the basis and the origin
        [
            scale.x,
            0.0,
            0.0,
            centered_pos.x * scale.x, // Row 0: scaled X basis + scaled origin.x
            0.0,
            scale.y,
            0.0,
            centered_pos.y * scale.y, // Row 1: scaled Y basis + scaled origin.y
            0.0,
            0.0,
            scale.z,
            centered_pos.z * scale.z, // Row 2: scaled Z basis + scaled origin.z
        ]
    }

    /// Calculate z-depth color for a single neuron (shared by both versions)
    #[inline(always)]
    fn calculate_color(z: u32, z_max: f32) -> [f32; 4] {
        let z_normalized = (z as f32 / z_max).clamp(0.0, 1.0);
        let red_intensity = (1.0 - z_normalized).max(0.2); // Front bright, back dark
        [red_intensity, 0.0, 0.0, 1.0] // Red gradient with full alpha
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

            // Convert cortical_id to base64 String to match API format
            // CRITICAL: API responses use base64 format, so BV's cache expects base64 keys
            // Visualization binary uses raw 8-byte ASCII, so we must convert here
            let cortical_id_str = cortical_id.as_base_64();

            // Create area data dictionary
            let mut area_dict = Dictionary::new();

            // Convert arrays to Godot PackedArrays
            let mut x_array = PackedInt32Array::new();
            let mut y_array = PackedInt32Array::new();
            let mut z_array = PackedInt32Array::new();
            let mut p_array = PackedFloat32Array::new();

            // Use the iterator to access neurons
            for neuron in neuron_array.iter() {
                x_array.push(neuron.neuron_voxel_coordinate.x as i32);
                y_array.push(neuron.neuron_voxel_coordinate.y as i32);
                z_array.push(neuron.neuron_voxel_coordinate.z as i32);
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
    fn create_visualization_error_dict(
        &self,
        error_msg: String,
        processing_time_us: i64,
    ) -> Dictionary {
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
