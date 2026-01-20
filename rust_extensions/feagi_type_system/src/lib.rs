/*!
FEAGI Type System GDExtension

Exposes the authoritative cortical type system from feagi-data-processing to Godot.
This provides:
- Type-safe cortical area classification
- Validation logic from FEAGI core
- Single source of truth for all type information
- No string-based type handling in GDScript

Copyright 2025 Neuraville Inc.
Licensed under the Apache License, Version 2.0
*/

use godot::prelude::*;

mod cortical_type;
mod type_factory;
mod validation;

pub use cortical_type::FeagiCorticalType;
pub use type_factory::FeagiCorticalTypeFactory;
pub use validation::FeagiTypeValidator;

struct FeagiTypeSystemExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiTypeSystemExtension {}

