/*!
FeagiCorticalType - Godot-exposed wrapper for CorticalAreaType

This class wraps the Rust CorticalAreaType enum from feagi-data-processing
and exposes it to GDScript with a clean, type-safe API.
*/

use godot::prelude::*;
use feagi_structures::genomic::cortical_area::{CorticalAreaType, IOCorticalAreaConfigurationFlag};
use feagi_structures::genomic::cortical_area::io_cortical_area_configuration_flag::{
    FrameChangeHandling, PercentageNeuronPositioning,
};

// ============================================================================
// UTILITY FUNCTIONS (minimal adapters)
// ============================================================================

/// Convert CorticalAreaType to category string
fn to_cortical_category(cortical_type: &CorticalAreaType) -> &'static str {
    match cortical_type {
        CorticalAreaType::Core(_) => "CORE",
        CorticalAreaType::Custom(_) => "CUSTOM",
        CorticalAreaType::Memory(_) => "MEMORY",
        CorticalAreaType::BrainInput(_) => "IPU",
        CorticalAreaType::BrainOutput(_) => "OPU",
    }
}

/// Check if type is input
fn is_input(cortical_type: &CorticalAreaType) -> bool {
    matches!(cortical_type, CorticalAreaType::BrainInput(_))
}

/// Check if type is output
fn is_output(cortical_type: &CorticalAreaType) -> bool {
    matches!(cortical_type, CorticalAreaType::BrainOutput(_))
}

/// Check if type is core
fn is_core(cortical_type: &CorticalAreaType) -> bool {
    matches!(cortical_type, CorticalAreaType::Core(_))
}

/// Check if type is memory
fn is_memory(cortical_type: &CorticalAreaType) -> bool {
    matches!(cortical_type, CorticalAreaType::Memory(_))
}

/// Check if type is custom
fn is_custom(cortical_type: &CorticalAreaType) -> bool {
    matches!(cortical_type, CorticalAreaType::Custom(_))
}

/// Godot-exposed cortical type wrapper
/// 
/// Wraps the authoritative Rust CorticalAreaType from feagi-data-processing.
/// This provides type-safe cortical type handling in GDScript.
#[derive(GodotClass)]
#[class(base=Resource)]
pub struct FeagiCorticalType {
    #[base]
    base: Base<Resource>,
    
    /// Internal Rust type (not directly exposed to GDScript)
    internal_type: Option<CorticalAreaType>,
}

#[godot_api]
impl IResource for FeagiCorticalType {
    fn init(base: Base<Resource>) -> Self {
        Self {
            base,
            internal_type: None,
        }
    }
}

#[godot_api]
impl FeagiCorticalType {
    // ========================================================================
    // CATEGORY QUERIES
    // ========================================================================
    
    /// Get the high-level category: "IPU", "OPU", "CORE", "MEMORY", "CUSTOM"
    #[func]
    pub fn get_category(&self) -> GString {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            GString::from(to_cortical_category(cortical_type))
        } else {
            GString::from("UNKNOWN")
        }
    }
    
    /// Check if this is an input area (IPU)
    #[func]
    pub fn is_input(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            is_input(cortical_type)
        } else {
            false
        }
    }
    
    /// Check if this is an output area (OPU)
    #[func]
    pub fn is_output(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            is_output(cortical_type)
        } else {
            false
        }
    }
    
    /// Check if this is a core area
    #[func]
    pub fn is_core(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            is_core(cortical_type)
        } else {
            false
        }
    }
    
    /// Check if this is a memory area
    #[func]
    pub fn is_memory(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            is_memory(cortical_type)
        } else {
            false
        }
    }
    
    /// Check if this is a custom area
    #[func]
    pub fn is_custom(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            // No longer needed - using direct functions
            is_custom(cortical_type)
        } else {
            false
        }
    }
    
    // ========================================================================
    // DATA TYPE QUERIES (for IPU/OPU)
    // ========================================================================
    
    /// Get the data type: "CartesianPlane", "Percentage", "SignedPercentage", etc.
    #[func]
    pub fn get_data_type(&self) -> GString {
        if let Some(ref cortical_type) = self.internal_type {
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    Self::io_type_to_string(io_type)
                }
                _ => GString::from("N/A")
            }
        } else {
            GString::from("UNKNOWN")
        }
    }
    
    /// Get frame handling: "Absolute" or "Incremental"
    #[func]
    pub fn get_frame_handling(&self) -> GString {
        if let Some(ref cortical_type) = self.internal_type {
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    Self::get_frame_handling_from_io(io_type)
                }
                _ => GString::from("N/A")
            }
        } else {
            GString::from("UNKNOWN")
        }
    }
    
    /// Check if this uses CartesianPlane encoding
    #[func]
    pub fn is_cartesian_plane(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            matches!(
                cortical_type,
                CorticalAreaType::BrainInput(IOCorticalAreaConfigurationFlag::CartesianPlane(_)) |
                CorticalAreaType::BrainOutput(IOCorticalAreaConfigurationFlag::CartesianPlane(_))
            )
        } else {
            false
        }
    }
    
    /// Check if this uses percentage encoding
    #[func]
    pub fn is_percentage_encoding(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            matches!(
                cortical_type,
                CorticalAreaType::BrainInput(
                    IOCorticalAreaConfigurationFlag::Percentage(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage2D(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage3D(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage4D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage2D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage3D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage4D(_, _)
                ) |
                CorticalAreaType::BrainOutput(
                    IOCorticalAreaConfigurationFlag::Percentage(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage2D(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage3D(_, _) |
                    IOCorticalAreaConfigurationFlag::Percentage4D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage2D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage3D(_, _) |
                    IOCorticalAreaConfigurationFlag::SignedPercentage4D(_, _)
                )
            )
        } else {
            false
        }
    }
    
    /// Check if this uses absolute frame handling
    #[func]
    pub fn uses_absolute_frames(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    Self::check_frame_handling(io_type, FrameChangeHandling::Absolute)
                }
                _ => false
            }
        } else {
            false
        }
    }
    
    /// Check if this uses incremental frame handling
    #[func]
    pub fn uses_incremental_frames(&self) -> bool {
        if let Some(ref cortical_type) = self.internal_type {
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    Self::check_frame_handling(io_type, FrameChangeHandling::Incremental)
                }
                _ => false
            }
        } else {
            false
        }
    }
    
    // ========================================================================
    // API SERIALIZATION
    // ========================================================================
    
    /// Export to dictionary for API calls
    /// 
    /// Returns a dictionary matching the API's cortical_type_info format:
    /// {
    ///   "category": "IPU",
    ///   "data_type": "CartesianPlane",
    ///   "frame_handling": "Absolute",
    ///   "encoding_details": {...}
    /// }
    #[func]
    pub fn to_api_dict(&self) -> Dictionary {
        let mut dict = Dictionary::new();
        
        if let Some(ref cortical_type) = self.internal_type {
            dict.set("category", self.get_category());
            
            // Add data_type and frame_handling for IPU/OPU
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    dict.set("data_type", Self::io_type_to_string(io_type));
                    dict.set("frame_handling", Self::get_frame_handling_from_io(io_type));
                    
                    // Add encoding details if applicable
                    if let Some(details) = Self::get_encoding_details(io_type) {
                        dict.set("encoding_details", details);
                    }
                }
                _ => {}
            }
        }
        
        dict
    }
    
    /// Get human-readable description
    /// 
    /// Example: "IPU - CartesianPlane (Absolute)"
    #[func]
    pub fn get_description(&self) -> GString {
        if let Some(ref cortical_type) = self.internal_type {
            match cortical_type {
                CorticalAreaType::BrainInput(io_type) |
                CorticalAreaType::BrainOutput(io_type) => {
                    let desc = format!(
                        "{} - {} ({})",
                        self.get_category(),
                        Self::io_type_to_string(io_type),
                        Self::get_frame_handling_from_io(io_type)
                    );
                    GString::from(desc.as_str())
                }
                _ => self.get_category()
            }
        } else {
            GString::from("UNKNOWN")
        }
    }
    
    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================
    
    /// Set internal type (used by factory)
    pub(crate) fn set_internal_type(&mut self, cortical_type: CorticalAreaType) {
        self.internal_type = Some(cortical_type);
    }
    
    /// Get internal type (used by validator)
    pub(crate) fn get_internal_type(&self) -> Option<&CorticalAreaType> {
        self.internal_type.as_ref()
    }
    
    fn io_type_to_string(io_type: &IOCorticalAreaConfigurationFlag) -> GString {
        use IOCorticalAreaConfigurationFlag::*;
        let name = match io_type {
            CartesianPlane(_) => "CartesianPlane",
            Percentage(_, _) => "Percentage",
            Percentage2D(_, _) => "Percentage2D",
            Percentage3D(_, _) => "Percentage3D",
            Percentage4D(_, _) => "Percentage4D",
            SignedPercentage(_, _) => "SignedPercentage",
            SignedPercentage2D(_, _) => "SignedPercentage2D",
            SignedPercentage3D(_, _) => "SignedPercentage3D",
            SignedPercentage4D(_, _) => "SignedPercentage4D",
            Misc(_) => "Misc",
            Boolean => "Boolean",
        };
        GString::from(name)
    }
    
    fn get_frame_handling_from_io(io_type: &IOCorticalAreaConfigurationFlag) -> GString {
        use IOCorticalAreaConfigurationFlag::*;
        let handling = match io_type {
            CartesianPlane(h) => h,
            Percentage(h, _) => h,
            Percentage2D(h, _) => h,
            Percentage3D(h, _) => h,
            Percentage4D(h, _) => h,
            SignedPercentage(h, _) => h,
            SignedPercentage2D(h, _) => h,
            SignedPercentage3D(h, _) => h,
            SignedPercentage4D(h, _) => h,
            Misc(h) => h,
            Boolean => &FrameChangeHandling::Absolute, // Boolean uses absolute by default
        };
        
        match handling {
            FrameChangeHandling::Absolute => GString::from("Absolute"),
            FrameChangeHandling::Incremental => GString::from("Incremental"),
        }
    }
    
    fn check_frame_handling(io_type: &IOCorticalAreaConfigurationFlag, target: FrameChangeHandling) -> bool {
        use IOCorticalAreaConfigurationFlag::*;
        let handling = match io_type {
            CartesianPlane(h) => h,
            Percentage(h, _) => h,
            Percentage2D(h, _) => h,
            Percentage3D(h, _) => h,
            Percentage4D(h, _) => h,
            SignedPercentage(h, _) => h,
            SignedPercentage2D(h, _) => h,
            SignedPercentage3D(h, _) => h,
            SignedPercentage4D(h, _) => h,
            Misc(h) => h,
            Boolean => &FrameChangeHandling::Absolute, // Boolean uses absolute by default
        };
        *handling == target
    }
    
    fn get_encoding_details(io_type: &IOCorticalAreaConfigurationFlag) -> Option<Dictionary> {
        use IOCorticalAreaConfigurationFlag::*;
        
        match io_type {
            Percentage(_, pos) | Percentage2D(_, pos) | Percentage3D(_, pos) | Percentage4D(_, pos) => {
                let mut dict = Dictionary::new();
                dict.set("signed", false);
                dict.set("positioning", match pos {
                    PercentageNeuronPositioning::Linear => "Linear",
                    PercentageNeuronPositioning::Fractional => "Fractional",
                });
                Some(dict)
            }
            SignedPercentage(_, pos) | SignedPercentage2D(_, pos) | SignedPercentage3D(_, pos) | SignedPercentage4D(_, pos) => {
                let mut dict = Dictionary::new();
                dict.set("signed", true);
                dict.set("positioning", match pos {
                    PercentageNeuronPositioning::Linear => "Linear",
                    PercentageNeuronPositioning::Fractional => "Fractional",
                });
                Some(dict)
            }
            _ => None
        }
    }
}

