/*!
FeagiCorticalTypeFactory - Factory methods for creating cortical types

Provides convenient constructors for all supported cortical area types.
This is the primary way GDScript creates type instances.
*/

use godot::prelude::*;
use feagi_data_structures::genomic::cortical_area::{
    CorticalAreaType, IOCorticalAreaDataType, CoreCorticalType, 
    CustomCorticalType, MemoryCorticalType,
};
use feagi_data_structures::genomic::cortical_area::io_cortical_area_data_type::{
    FrameChangeHandling, PercentageNeuronPositioning,
};
use crate::FeagiCorticalType;

/// Factory for creating cortical types
/// 
/// Provides static methods to construct all supported types.
/// Used by GDScript to create type instances for templates.
#[derive(GodotClass)]
#[class(base=Object)]
pub struct FeagiCorticalTypeFactory {
    #[base]
    base: Base<Object>,
}

#[godot_api]
impl IObject for FeagiCorticalTypeFactory {
    fn init(base: Base<Object>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl FeagiCorticalTypeFactory {
    // ========================================================================
    // IPU FACTORIES
    // ========================================================================
    
    /// Create IPU with CartesianPlane (vision)
    /// 
    /// Args:
    ///   - frame_handling: 0 = Absolute, 1 = Incremental
    /// 
    /// Example (GDScript):
    ///   var camera_type = FeagiCorticalTypeFactory.create_ipu_cartesian_plane(0)
    #[func]
    pub fn create_ipu_cartesian_plane(frame_handling: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        Self::create_with_type(CorticalAreaType::BrainInput(
            IOCorticalAreaDataType::CartesianPlane(handling)
        ))
    }
    
    /// Create IPU with Percentage encoding
    /// 
    /// Args:
    ///   - frame_handling: 0 = Absolute, 1 = Incremental
    ///   - positioning: 0 = Linear, 1 = Fractional
    #[func]
    pub fn create_ipu_percentage(frame_handling: i32, positioning: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        let pos = Self::i32_to_positioning(positioning);
        Self::create_with_type(CorticalAreaType::BrainInput(
            IOCorticalAreaDataType::Percentage(handling, pos)
        ))
    }
    
    /// Create IPU with SignedPercentage encoding
    #[func]
    pub fn create_ipu_signed_percentage(frame_handling: i32, positioning: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        let pos = Self::i32_to_positioning(positioning);
        Self::create_with_type(CorticalAreaType::BrainInput(
            IOCorticalAreaDataType::SignedPercentage(handling, pos)
        ))
    }
    
    /// Create IPU with Misc encoding (generic)
    #[func]
    pub fn create_ipu_misc(frame_handling: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        Self::create_with_type(CorticalAreaType::BrainInput(
            IOCorticalAreaDataType::Misc(handling)
        ))
    }
    
    // ========================================================================
    // OPU FACTORIES
    // ========================================================================
    
    /// Create OPU with Percentage encoding (motors)
    /// 
    /// Args:
    ///   - frame_handling: 0 = Absolute, 1 = Incremental
    ///   - positioning: 0 = Linear, 1 = Fractional
    /// 
    /// Example (GDScript):
    ///   var servo_type = FeagiCorticalTypeFactory.create_opu_percentage(0, 0)
    #[func]
    pub fn create_opu_percentage(frame_handling: i32, positioning: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        let pos = Self::i32_to_positioning(positioning);
        Self::create_with_type(CorticalAreaType::BrainOutput(
            IOCorticalAreaDataType::Percentage(handling, pos)
        ))
    }
    
    /// Create OPU with SignedPercentage encoding
    #[func]
    pub fn create_opu_signed_percentage(frame_handling: i32, positioning: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        let pos = Self::i32_to_positioning(positioning);
        Self::create_with_type(CorticalAreaType::BrainOutput(
            IOCorticalAreaDataType::SignedPercentage(handling, pos)
        ))
    }
    
    /// Create OPU with CartesianPlane (rare, but possible)
    #[func]
    pub fn create_opu_cartesian_plane(frame_handling: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        Self::create_with_type(CorticalAreaType::BrainOutput(
            IOCorticalAreaDataType::CartesianPlane(handling)
        ))
    }
    
    /// Create OPU with Misc encoding (generic)
    #[func]
    pub fn create_opu_misc(frame_handling: i32) -> Gd<FeagiCorticalType> {
        let handling = Self::i32_to_frame_handling(frame_handling);
        Self::create_with_type(CorticalAreaType::BrainOutput(
            IOCorticalAreaDataType::Misc(handling)
        ))
    }
    
    // ========================================================================
    // CORE, MEMORY, CUSTOM FACTORIES
    // ========================================================================
    
    /// Create CORE cortical area type (Power)
    #[func]
    pub fn create_core() -> Gd<FeagiCorticalType> {
        Self::create_with_type(CorticalAreaType::Core(CoreCorticalType::Power))
    }
    
    /// Create MEMORY cortical area type
    #[func]
    pub fn create_memory() -> Gd<FeagiCorticalType> {
        Self::create_with_type(CorticalAreaType::Memory(MemoryCorticalType::Memory))
    }
    
    /// Create CUSTOM cortical area type
    #[func]
    pub fn create_custom() -> Gd<FeagiCorticalType> {
        Self::create_with_type(CorticalAreaType::Custom(CustomCorticalType::LeakyIntegrateFire))
    }
    
    // ========================================================================
    // API PARSING
    // ========================================================================
    
    /// Create from API response dictionary
    /// 
    /// Parses the cortical_type_info structure from FEAGI API:
    /// {
    ///   "category": "IPU",
    ///   "data_type": "CartesianPlane",
    ///   "frame_handling": "Absolute",
    ///   "encoding_details": {...}
    /// }
    #[func]
    pub fn from_api_dict(api_dict: Dictionary) -> Gd<FeagiCorticalType> {
        // Extract fields
        let category = api_dict.get_or_nil("category").to::<String>();
        let data_type = api_dict.get_or_nil("data_type").to::<String>();
        let frame_handling_str = api_dict.get_or_nil("frame_handling").to::<String>();
        let encoding_details = api_dict.get_or_nil("encoding_details");
        
        // Parse frame handling
        let frame_handling = match frame_handling_str.as_str() {
            "Incremental" => FrameChangeHandling::Incremental,
            _ => FrameChangeHandling::Absolute,
        };
        
        // Parse positioning if available
        let positioning = if let Ok(details_dict) = encoding_details.try_to::<Dictionary>() {
            let pos_str = details_dict.get_or_nil("positioning").to::<String>();
            match pos_str.as_str() {
                "Fractional" => PercentageNeuronPositioning::Fractional,
                _ => PercentageNeuronPositioning::Linear,
            }
        } else {
            PercentageNeuronPositioning::Linear
        };
        
        // Construct the appropriate type
        let cortical_type = match (category.as_str(), data_type.as_str()) {
            // IPU types
            ("IPU", "CartesianPlane") => CorticalAreaType::BrainInput(
                IOCorticalAreaDataType::CartesianPlane(frame_handling)
            ),
            ("IPU", "Percentage") => CorticalAreaType::BrainInput(
                IOCorticalAreaDataType::Percentage(frame_handling, positioning)
            ),
            ("IPU", "SignedPercentage") => CorticalAreaType::BrainInput(
                IOCorticalAreaDataType::SignedPercentage(frame_handling, positioning)
            ),
            ("IPU", "Misc") | ("IPU", _) => CorticalAreaType::BrainInput(
                IOCorticalAreaDataType::Misc(frame_handling)
            ),
            
            // OPU types
            ("OPU", "CartesianPlane") => CorticalAreaType::BrainOutput(
                IOCorticalAreaDataType::CartesianPlane(frame_handling)
            ),
            ("OPU", "Percentage") => CorticalAreaType::BrainOutput(
                IOCorticalAreaDataType::Percentage(frame_handling, positioning)
            ),
            ("OPU", "SignedPercentage") => CorticalAreaType::BrainOutput(
                IOCorticalAreaDataType::SignedPercentage(frame_handling, positioning)
            ),
            ("OPU", "Misc") | ("OPU", _) => CorticalAreaType::BrainOutput(
                IOCorticalAreaDataType::Misc(frame_handling)
            ),
            
            // Other types
            ("CORE", _) => CorticalAreaType::Core(CoreCorticalType::Power),
            ("MEMORY", _) => CorticalAreaType::Memory(MemoryCorticalType::Memory),
            ("CUSTOM", _) => CorticalAreaType::Custom(CustomCorticalType::LeakyIntegrateFire),
            
            // Fallback
            _ => {
                godot_warn!("Unknown cortical type: {} / {}", category, data_type);
                CorticalAreaType::Custom(CustomCorticalType::LeakyIntegrateFire)
            }
        };
        
        Self::create_with_type(cortical_type)
    }
    
    // ========================================================================
    // CONSTANTS (for GDScript)
    // ========================================================================
    
    /// Frame handling: Absolute
    #[constant]
    const FRAME_ABSOLUTE: i32 = 0;
    
    /// Frame handling: Incremental
    #[constant]
    const FRAME_INCREMENTAL: i32 = 1;
    
    /// Positioning: Linear
    #[constant]
    const POSITIONING_LINEAR: i32 = 0;
    
    /// Positioning: Fractional
    #[constant]
    const POSITIONING_FRACTIONAL: i32 = 1;
    
    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================
    
    fn create_with_type(cortical_type: CorticalAreaType) -> Gd<FeagiCorticalType> {
        let mut gd = Gd::<FeagiCorticalType>::default();
        gd.bind_mut().set_internal_type(cortical_type);
        gd
    }
    
    fn i32_to_frame_handling(value: i32) -> FrameChangeHandling {
        match value {
            1 => FrameChangeHandling::Incremental,
            _ => FrameChangeHandling::Absolute,
        }
    }
    
    fn i32_to_positioning(value: i32) -> PercentageNeuronPositioning {
        match value {
            1 => PercentageNeuronPositioning::Fractional,
            _ => PercentageNeuronPositioning::Linear,
        }
    }
}

