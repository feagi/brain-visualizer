/*!
FeagiTypeValidator - Validation logic for cortical types

Provides validation using the authoritative logic from FEAGI core.
This ensures BV uses the same validation rules as FEAGI.
*/

use godot::prelude::*;
use godot::builtin::PackedStringArray;
use crate::FeagiCorticalType;

/// Validator for cortical types
/// 
/// Provides validation methods that leverage FEAGI's core validation logic.
/// Used by BV to validate templates, agent compatibility, etc.
#[derive(GodotClass)]
#[class(base=Object)]
pub struct FeagiTypeValidator {
    #[base]
    base: Base<Object>,
}

#[godot_api]
impl IObject for FeagiTypeValidator {
    fn init(base: Base<Object>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl FeagiTypeValidator {
    /// Validate agent compatibility with cortical type
    /// 
    /// Args:
    ///   - cortical_type: The FeagiCorticalType to validate
    ///   - agent_modality: String describing agent type ("camera", "servo", etc.)
    /// 
    /// Returns: Dictionary with:
    ///   - valid: bool
    ///   - warnings: Array[String]
    ///   - recommendations: Array[String]
    /// 
    /// Example (GDScript):
    ///   var result = FeagiTypeValidator.validate_agent_compatibility(camera_type, "camera")
    ///   if not result.valid:
    ///       show_warning(result.warnings[0])
    #[func]
    pub fn validate_agent_compatibility(
        cortical_type: Gd<FeagiCorticalType>,
        agent_modality: GString,
    ) -> Dictionary {
        let mut result = Dictionary::new();
        let mut warnings = PackedStringArray::new();
        let mut recommendations = PackedStringArray::new();
        
        let cortical_type_bind = cortical_type.bind();
        let modality_str = agent_modality.to_string().to_lowercase();
        
        // Check if type info is available
        if cortical_type_bind.get_internal_type().is_none() {
            warnings.push(&GString::from("No type information available"));
            result.set("valid", false);
            result.set("warnings", warnings);
            result.set("recommendations", recommendations);
            return result;
        }
        
        let mut is_valid = true;
        
        // Validate IPU types
        if cortical_type_bind.is_input() {
            if cortical_type_bind.is_cartesian_plane() {
                // CartesianPlane expects vision/camera input
                if !modality_str.contains("vision") 
                    && !modality_str.contains("camera")
                    && !modality_str.contains("webcam")
                    && !modality_str.contains("image") {
                    warnings.push(&GString::from("CartesianPlane encoding expects vision/camera input"));
                    recommendations.push(&GString::from("Use camera, webcam, or vision sensor"));
                    is_valid = false;
                }
            } else if cortical_type_bind.is_percentage_encoding() {
                // Percentage encoding expects normalized data
                recommendations.push(&GString::from("Ensure agent provides data normalized to 0-100%"));
            }
        }
        
        // Validate OPU types
        if cortical_type_bind.is_output() {
            if cortical_type_bind.is_percentage_encoding() {
                // Motor outputs with percentage encoding
                if !modality_str.contains("motor")
                    && !modality_str.contains("servo")
                    && !modality_str.contains("actuator") {
                    recommendations.push(&GString::from("Percentage encoding typically used for motors/servos"));
                }
                recommendations.push(&GString::from("Output will be percentage values (0-100%) - ensure actuators are calibrated"));
            }
        }
        
        // Build result
        result.set("valid", is_valid);
        result.set("warnings", warnings);
        result.set("recommendations", recommendations);
        result
    }
    
    /// Get recommended buffer size for a cortical area
    /// 
    /// Args:
    ///   - cortical_type: The FeagiCorticalType
    ///   - dimensions: Vector3i of area dimensions (width, height, depth)
    /// 
    /// Returns: Recommended buffer size in bytes
    #[func]
    pub fn get_recommended_buffer_size(
        cortical_type: Gd<FeagiCorticalType>,
        dimensions: Vector3i,
    ) -> i32 {
        let cortical_type_bind = cortical_type.bind();
        let volume = (dimensions.x * dimensions.y * dimensions.z) as usize;
        
        // Use heuristics based on data type
        let bytes_per_voxel = if cortical_type_bind.is_cartesian_plane() {
            // Vision typically needs more space
            4
        } else if cortical_type_bind.is_percentage_encoding() {
            // Percentage is more compact
            2
        } else {
            // Default
            2
        };
        
        (volume * bytes_per_voxel) as i32
    }
    
    /// Check if compression is recommended
    /// 
    /// Args:
    ///   - cortical_type: The FeagiCorticalType
    ///   - dimensions: Vector3i of area dimensions
    /// 
    /// Returns: true if compression is recommended
    #[func]
    pub fn should_use_compression(
        cortical_type: Gd<FeagiCorticalType>,
        dimensions: Vector3i,
    ) -> bool {
        let cortical_type_bind = cortical_type.bind();
        let volume = (dimensions.x * dimensions.y * dimensions.z) as usize;
        
        // Vision data benefits from compression
        if cortical_type_bind.is_cartesian_plane() {
            return volume > 1000;
        }
        
        // General rule: compress if large
        volume > 500
    }
    
    /// Validate template definition
    /// 
    /// Checks if a template's type configuration is valid.
    /// 
    /// Args:
    ///   - cortical_type: The FeagiCorticalType
    ///   - template_name: Name of the template (for error messages)
    /// 
    /// Returns: Dictionary with:
    ///   - valid: bool
    ///   - errors: Array[String]
    #[func]
    pub fn validate_template(
        cortical_type: Gd<FeagiCorticalType>,
        template_name: GString,
    ) -> Dictionary {
        let mut result = Dictionary::new();
        let mut errors = PackedStringArray::new();
        
        let cortical_type_bind = cortical_type.bind();
        
        // Check if type is defined
        if cortical_type_bind.get_internal_type().is_none() {
            let msg = GString::from(format!(
                "Template '{}' has no cortical type defined",
                template_name
            ).as_str());
            errors.push(&msg);
            result.set("valid", false);
            result.set("errors", errors);
            return result;
        }
        
        // Check category is valid
        let category = cortical_type_bind.get_category().to_string();
        if category == "UNKNOWN" {
            let msg = GString::from(format!(
                "Template '{}' has unknown cortical type",
                template_name
            ).as_str());
            errors.push(&msg);
        }
        
        // All checks passed
        let is_valid = errors.is_empty();
        result.set("valid", is_valid);
        result.set("errors", errors);
        result
    }
    
    /// Get human-readable validation summary
    /// 
    /// Provides a complete summary of type compatibility and recommendations.
    /// 
    /// Args:
    ///   - cortical_type: The FeagiCorticalType
    ///   - agent_modality: Agent modality string
    ///   - dimensions: Area dimensions
    /// 
    /// Returns: Dictionary with complete validation info
    #[func]
    pub fn get_validation_summary(
        cortical_type: Gd<FeagiCorticalType>,
        agent_modality: GString,
        dimensions: Vector3i,
    ) -> Dictionary {
        let mut summary = Dictionary::new();
        
        // Get compatibility
        let compat = Self::validate_agent_compatibility(cortical_type.clone(), agent_modality);
        summary.set("compatibility", compat);
        
        // Get buffer recommendation
        let buffer_size = Self::get_recommended_buffer_size(cortical_type.clone(), dimensions);
        summary.set("recommended_buffer_size", buffer_size);
        
        // Get compression recommendation
        let use_compression = Self::should_use_compression(cortical_type.clone(), dimensions);
        summary.set("use_compression", use_compression);
        
        // Get type description
        let cortical_type_bind = cortical_type.bind();
        summary.set("type_description", cortical_type_bind.get_description());
        
        summary
    }
}

