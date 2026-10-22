//! Type 11 frames that include a modulator driver must decode.
//!
//! `feagi-structures` 0.0.35 rejects cortical IDs whose first byte is `g`.
//! A single rejected ID fails the whole visualization packet.

use feagi_serialization::FeagiByteContainer;
use feagi_structures::genomic::cortical_area::CorticalID;
use feagi_structures::neuron_voxels::xyzp::{
    CorticalMappedXYZPNeuronVoxels, NeuronVoxelXYZPArrays,
};

#[test]
fn type11_round_trip_accepts_modulator_driver_cortical_id() {
    let cortical_id = CorticalID::modulator_driver(1);
    assert!(cortical_id.is_modulator_driver());
    assert_eq!(cortical_id.as_bytes()[0], b'g');

    let neurons = NeuronVoxelXYZPArrays::new_from_vectors(vec![1], vec![2], vec![3], vec![0.5])
        .expect("neuron arrays");

    let mut frame = CorticalMappedXYZPNeuronVoxels::new();
    frame.mappings.insert(cortical_id, neurons);

    let mut container = FeagiByteContainer::new_empty();
    container
        .overwrite_byte_data_with_single_struct_data(&frame, 0)
        .expect("serialize type 11");

    let mut encoded = container.get_byte_ref().to_vec();
    let mut loaded = FeagiByteContainer::new_empty();
    loaded
        .try_write_data_to_container_and_verify(&mut |bytes| {
            std::mem::swap(bytes, &mut encoded);
            Ok(())
        })
        .expect("load container");

    let boxed = loaded
        .try_create_new_struct_from_index(0)
        .expect("decode structure");
    let decoded = boxed
        .as_any()
        .downcast_ref::<CorticalMappedXYZPNeuronVoxels>()
        .expect("type 11 structure");

    let decoded_neurons = decoded
        .mappings
        .get(&cortical_id)
        .expect("modulator cortical id present");
    assert_eq!(decoded_neurons.len(), 1);
}
