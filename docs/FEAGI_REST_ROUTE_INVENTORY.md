# FEAGI REST routes used by Brain Visualizer

Every FEAGI REST route BV declares or calls, sorted by when BV needs it. Written as input for the
zenoh FEAGI (feagi-interop) work: it shows which routes a new FEAGI must serve for BV to connect and
show a brain, and which only matter once the user edits.

Snapshot of `circuit-schematic-phase0` on 2026-10-22. Paths are relative to `godot_source/`.
Routes are declared in `addons/FeagiCoreIntegration/FeagiCore/Networking/API/FEAGIHTTPAddressList.gd`
(96 vars) plus one inline route in `Autoload/FeagiProcessManager.gd`.

Abbreviations: FR = `FeagiCore/FEAGIRequests.gd`, FC = `FeagiCore/FeagiCore.gd`,
FN = `FeagiCore/Networking/FEAGINetworking.gd`, LC = `FeagiCore/LocalCache/FEAGILocalCache.gd`.

## Summary

| Phase | Routes | Meaning |
|---|---|---|
| CONNECT | 4 | Connect, detect the protocol, register, stay healthy |
| GENOME_LOAD | 11 | Called automatically to load or reload a genome |
| RUNTIME_AUTO | 2 | Called automatically during a session, without user action |
| EDIT | 29 | Only when the user edits the genome |
| USER_FEATURE | 16 | Other user-triggered features (inspectors, stimulation, settings) |
| UNUSED | 34 | Declared, never called |

**To connect and show a loaded genome with live activity, BV needs 9 routes, and the feagi-interop
fixture server already serves all 9.** On the zenoh path, what stops BV is registration, not REST:
BV detects zenoh and refuses to register, because no zenoh agent or stream exists yet (see
[Coverage](#coverage-by-the-feagi-interop-fixtures)).

Live neuron activity arrives over the data stream (WebSocket or shared memory today), not REST.

## How BV connects and loads a genome

**Connect** (`FC.attempt_connection_to_FEAGI` → `FN.attempt_connection`):
1. `GET /v1/system/health_check` through `confirm_connectivity`.
2. Protocol probe (`FN._detect_feagi_protocol`): the `protocol` field in `health_check` if present,
   otherwise `GET /v1/agent/capabilities/all` (200 means legacy, 404 means zenoh). Skipped when
   `FEAGI_PROTOCOL` or the `feagi_protocol` setting fixes it.
3. Registration (`FN._register_agent_via_transport`):
   - `GET /v1/burst_engine/simulation_timestep`. Must be a float > 0, or registration aborts.
   - `GET /v1/network/connection_info`. Must contain a WebSocket registration endpoint (legacy only).
4. `GET /v1/system/health_check` again. The response must contain `genome_availability` and
   `brain_readiness`, or BV disconnects (FC:160).
5. A 3-second timer re-polls `health_check` (FC:284). Three failures mark HTTP as down.

**Genome load** (`FC.reload_genome_await` → `FR.reload_genome`):
- Awaited; any failure aborts the load: geometry, morphologies, `cortical_map_detailed`,
  `regions_members`, `ipu/types`, `opu/types`.
- Fire-and-forget: simulation timestep, suppression threshold, skip rate, plasticity queue depth.
- `refresh_agent_capabilities_cache` is awaited but its result is ignored. It is gated off on zenoh
  and tolerates a 404.
- `LC.replace_whole_genome` fetches classifiers without waiting.
- `health_check` runs every 5 s while the reload is in progress.

**During a session:** when a `*_hash` field in `health_check` changes, BV re-fetches only the matching
data (geometry, regions, morphologies, mappings, classifiers, agents; LC:1010-1097). This uses routes
already listed under GENOME_LOAD, and only happens if FEAGI reports those hash fields.

## Minimal set for connect + display

| # | Route | Blocking | Fixture |
|---|---|---|---|
| 1 | GET /v1/system/health_check (needs `genome_availability`, `brain_readiness`) | yes | yes |
| 2 | GET /v1/burst_engine/simulation_timestep | yes | yes |
| 3 | GET /v1/network/connection_info (legacy registration only) | yes | yes |
| 4 | GET /v1/cortical_area/cortical_area/geometry | yes | yes |
| 5 | GET /v1/morphology/morphologies | yes | yes |
| 6 | GET /v1/cortical_area/cortical_map_detailed | yes | yes |
| 7 | GET /v1/region/regions_members | yes | yes |
| 8 | GET /v1/cortical_area/ipu/types | yes | yes |
| 9 | GET /v1/cortical_area/opu/types | yes | yes |
| 10 | GET /v1/system/cortical_area_visualization_skip_rate | no (error log only) | yes |
| 11 | GET /v1/system/cortical_area_visualization_suppression_threshold | no | yes |
| 12 | GET /v1/neuroplasticity/plasticity_queue_depth | no | yes |
| 13 | GET /v1/cortical_area/classifiers | no | yes |
| 14 | GET /v1/agent/capabilities/all | no; it is the protocol probe | no (by design) |
| 15 | GET /v1/genome/changes | only if `health_check` has `genome_change_sequence` | no |
| 16 | POST /v1/cortical_area/cortical_area_properties | only if the stream names an area BV has not cached | no |

## Coverage by the feagi-interop fixtures

The zenoh-test REST server (`crates/feagi-interop/src/transport/rest/server/server_std.rs`) serves
fixed JSON for 13 routes: items 1-13 above. Every blocking route is covered.

Gaps against that server:
- **Registration.** `/v1/agent/capabilities/all` returns 404 there, so BV picks the zenoh protocol
  and stops before the genome load, by design: there is no zenoh agent or stream to register with.
  To exercise the REST path against it today, force `FEAGI_PROTOCOL=legacy`. Registration over the
  legacy WebSocket then has to succeed, and it will not, because that server has no registration
  endpoint behind `connection_info`.
- **An explicit protocol field.** A `"protocol": "zenoh"` field in `health_check` would let BV
  identify the server without relying on a 404.
- **Editing.** None of the 29 EDIT or 16 USER_FEATURE routes are served. Whether the zenoh FEAGI
  serves them over REST or BV moves them to zenoh queries is the main open decision.

## Full table

**[AGENT]** marks `/v1/agent/...` routes. "Fixture" means the feagi-interop server serves it.

| # | Method | Route | Address-list var | BV caller(s) | Phase | Fixture |
|---|---|---|---|---|---|---|
| 1 | GET | /v1/system/health_check | GET_system_healthCheck | FR.single_health_check_call, FR.fast_initial_health_check (confirm_connectivity), FC.attempt_connection_to_FEAGI:152, FC._fetch_simulation_timestep:284 (3 s poll), FC.reload_genome_await:431, FN._detect_feagi_protocol; inline in FeagiProcessManager.gd:234 and BrainVisualizer.gd:344 (embedded FEAGI readiness) | CONNECT (+ poll) | yes |
| 2 | GET | /v1/burst_engine/simulation_timestep | GET_burstEngine_simulationTimestep | FN._get_feagi_burst_frequency (blocks registration); FR.get_burst_delay (reload, not awaited) | CONNECT | yes |
| 3 | GET | /v1/network/connection_info | GET_network_connection_info | FN._resolve_ws_endpoints ← FN._register_agent_via_transport | CONNECT | yes |
| 4 | GET | /v1/agent/capabilities/all **[AGENT]** | GET_agent_capabilities_all | FN._detect_feagi_protocol (probe); FR.refresh_agent_capabilities_cache ← reload_genome FR:285, LC:1321, WindowIPUOPUConfig.gd:154, delete guard | CONNECT (probe) | no |
| 5 | GET | /v1/cortical_area/cortical_area/geometry | GET_corticalArea_corticalArea_geometry | FR.reload_genome (blocking); FR.get_cortical_area_geometry ← LC hash refresh; FR.request_import_amalgamation | GENOME_LOAD | yes |
| 6 | GET | /v1/morphology/morphologies | GET_morphology_morphologies | FR.reload_genome (blocking); FR.get_morphologies_summary ← LC hash refresh | GENOME_LOAD | yes |
| 7 | GET | /v1/cortical_area/cortical_map_detailed | GET_corticalArea_corticalMapDetailed | FR.reload_genome (blocking); FR.get_mapping_summary ← LC hash refresh, mapping edits | GENOME_LOAD | yes |
| 8 | GET | /v1/region/regions_members | GET_region_regionsMembers | FR.reload_genome (blocking); FR.get_regions_summary ← LC hash refresh, region edits | GENOME_LOAD | yes |
| 9 | GET | /v1/cortical_area/ipu/types | GET_corticalAreas_ipu_types | FR.reload_genome (blocking); WindowSelectCorticalTemplate.gd:104 | GENOME_LOAD | yes |
| 10 | GET | /v1/cortical_area/opu/types | GET_corticalAreas_opu_types | FR.reload_genome (blocking); WindowSelectCorticalTemplate.gd:106 | GENOME_LOAD | yes |
| 11 | GET | /v1/system/cortical_area_visualization_skip_rate | GET_system_corticalAreaVisualizationSkipRate | FR.get_skip_rate ← reload (not awaited) | GENOME_LOAD | yes |
| 12 | GET | /v1/system/cortical_area_visualization_suppression_threshold | GET_system_corticalAreaVisualizationSupressionThreshold | FR.get_supression_threshold ← reload (not awaited) | GENOME_LOAD | yes |
| 13 | GET | /v1/neuroplasticity/plasticity_queue_depth | GET_neuroplasticity_plasticityQueueDepth | FR.get_plasticity_queue_depth ← reload (not awaited) | GENOME_LOAD | yes |
| 14 | GET | /v1/cortical_area/classifiers | GET_genome_classifiers | FR.get_classifiers ← LC.replace_whole_genome (not awaited), classifiers hash refresh, classifier edits | GENOME_LOAD | yes |
| 15 | POST | /v1/genome/upload/file (inline) | — | FeagiProcessManager.gd:298 `_load_default_genome` (managed/embedded FEAGI launcher only) | GENOME_LOAD | no |
| 16 | GET | /v1/genome/changes | GET_genome_changes | FR.get_genome_changes ← FC._fetch_change_history (only with `genome_change_sequence` and DesktopTeamEvents) | RUNTIME_AUTO | no |
| 17 | POST | /v1/cortical_area/cortical_area_properties | POST_corticalArea_corticalAreaProperties | FR.get_cortical_area ← FEAGIVisualizationSink missing-area fetch; post-create refreshes | RUNTIME_AUTO (+EDIT) | no |
| 18 | POST | /v1/cortical_mapping/mapping_properties | POST_corticalMappings_mappingProperties | FR.get_mappings_between_2_cortical_areas ← WindowQuickConnect.gd | EDIT | no |
| 19 | GET | /v1/genome/cortical_template | GET_genome_corticalTemplate | FR.get_cortical_template_metadata ← PartSpawnCorticalAreaIOPU.gd | EDIT | no |
| 20 | GET | /v1/agent/list **[AGENT]** | GET_agent_list | FR.supplement_agent_capabilities_device_registrations_from_http ← delete guard (WindowManager.gd:299) | EDIT | no |
| 21 | GET | /v1/agent/{agent_id}/device_registrations **[AGENT]** | GET_agent_device_registrations | same path as #20 | EDIT | no |
| 22 | POST | /v1/modulator/modulator | POST_modulator_modulator | FR.create_modulator ← WindowCreateModulator.gd, AdvancedCorticalProperties.gd | EDIT | no |
| 23 | POST | /v1/cortical_area/cortical_area | PUT_genome_corticalArea (sent as POST) | FR.add_IOPU_cortical_area ← WindowCreateCorticalArea.gd, DeleteAreaApplier.gd | EDIT | no |
| 24 | POST | /v1/cortical_area/custom_cortical_area | POST_genome_customCorticalArea | FR.add_custom_cortical_area, FR.add_custom_memory_cortical_area | EDIT | no |
| 25 | POST | /v1/cortical_area/classifier | POST_genome_classifier | FR.add_classifier_assembly ← WindowCreateClassifier.gd | EDIT | no |
| 26 | PUT | /v1/cortical_area/classifier/{classifier_id} | PUT_genome_classifier | FR.edit_classifier, FR.edit_classifier_reward ← WindowEditClassifier.gd | EDIT | no |
| 27 | DELETE | /v1/cortical_area/classifier/{classifier_id} | DELETE_genome_classifier | FR.delete_classifier ← WindowConfirmDeletion.gd | EDIT | no |
| 28 | POST | /v1/cortical_area/clone | POST_corticalArea_clone | FR.clone_cortical_area ← WindowCloneCorticalArea.gd | EDIT | no |
| 29 | POST | /v1/morphology/morphology | POST_genome_morphology | FR.add_vector/pattern/composite_morphology ← WindowCreateMorphology.gd, WindowQuickConnectNeuron.gd | EDIT | no |
| 30 | POST | /v1/genome/save | POST_genome_save | FR.save_genome ← UI_BrainMonitor_3DScene.gd (after 3D move/resize) | EDIT | no |
| 31 | POST | /v1/genome/amalgamation_destination | POST_genome_amalgamationDestination | FR.request_import_amalgamation ← WindowAmalgamationRequest.gd | EDIT | no |
| 32 | POST | /v1/genome/amalgamation_by_upload | POST_genome_amalgamationByUpload | FR.request_amalgamation_by_upload ← WindowSelectRegionTemplate.gd | EDIT | no |
| 33 | POST | /v1/region/clone | POST_region_clone | FR.clone_brain_region_pending ← WindowAmalgamationRequest.gd | EDIT | no |
| 34 | POST | /v1/region/region | POST_region_region | FR.create_region ← WindowCreateRegion.gd | EDIT | no |
| 35 | PUT | /v1/cortical_area/cortical_area | PUT_genome_corticalArea | FR.update_cortical_area ← UI_BrainMonitor_3DScene.gd | EDIT | no |
| 36 | PUT | /v1/cortical_mapping/mapping_properties | PUT_genome_mappingProperties | FR.restore_mapping_rules, FR.set_mappings_between_corticals ← WindowMappingEditor.gd, WindowEditClassifier.gd | EDIT | no |
| 37 | PUT | /v1/morphology/morphology | PUT_genome_morphology | FR.update_vector/pattern/composite_morphology | EDIT | no |
| 38 | PUT | /v1/morphology/rename | PUT_morphology_rename | FR.rename_morphology ← UIMorpologyOverviews.gd | EDIT | no |
| 39 | PUT | /v1/region/relocate_members | PUT_genome_relocate_members, PUT_region_relocateMembers (declared twice) | FR.mass_move_genome_objects_2D ← CircuitBuilder.gd, GenomePositionApplier.gd; FR.move_objects_to_region ← WindowAddToRegion.gd | EDIT | no |
| 40 | PUT | /v1/region/region | PUT_region_region | FR.edit_region_object, FR.update_region_designated_io | EDIT | no |
| 41 | PUT | /v1/cortical_area/multi/cortical_area | PUT_corticalArea_multi_corticalArea | FR.mass_move_genome_objects_2D, FR.update_cortical_areas ← AdvancedCorticalProperties.gd | EDIT | no |
| 42 | DELETE | /v1/cortical_area/cortical_area | DELETE_GE_corticalArea | FR.delete_cortical_area ← WindowConfirmDeletion.gd, DeleteAreaApplier.gd | EDIT | no |
| 43 | DELETE | /v1/cortical_area/multi/cortical_area | DELETE_corticalArea_multi_corticalArea | FR.mass_delete_cortical_areas | EDIT | no |
| 44 | DELETE | /v1/morphology/morphology | DELETE_GE_morphology | FR.delete_morphology ← UIMorpologyOverviews.gd | EDIT | no |
| 45 | DELETE | /v1/genome/amalgamation_cancellation | DELETE_GE_amalgamationCancellation | FR.clone_brain_region_pending, FR.cancel_pending_amalgamation | EDIT | no |
| 46 | DELETE | /v1/region/region | DELETE_region_region | FR.delete_regions_and_raise_internals ← WindowConfirmDeletion.gd | EDIT | no |
| 47 | POST | /v1/morphology/morphology_properties | POST_morphology_morphologyProperties | FR.get_morphology ← MorphologyScroll.gd | USER_FEATURE | no |
| 48 | POST | /v1/morphology/morphology_usage | POST_morphology_morphologyUsage | FR.get_morphology_usage ← UIMorpologyOverviews.gd, MorphologyGenericDetails.gd | USER_FEATURE | no |
| 49 | GET | /v1/cortical_area/voxel_neurons | GET_corticalArea_voxelNeurons | FR.get_voxel_neurons ← UIManager.gd (voxel inspector) | USER_FEATURE | no |
| 50 | GET | /v1/cortical_area/memory | GET_corticalArea_memory | FR.get_memory_cortical_area ← UIManager.gd, AdvancedCorticalProperties.gd, WindowEditClassifier.gd | USER_FEATURE | no |
| 51 | GET | /v1/connectome/memory_neuron | GET_connectome_memoryNeuron | FR.get_memory_neuron ← UIManager.gd | USER_FEATURE | no |
| 52 | POST | /v1/cortical_area/multi/cortical_area_properties | POST_corticalArea_multi_corticalAreaProperties | FR.get_cortical_areas ← AdvancedCorticalProperties.gd | USER_FEATURE | no |
| 53 | GET | /v1/modulator/modulators | GET_modulator_modulators | FR.list_modulators ← AdvancedCorticalProperties.gd | USER_FEATURE | no |
| 54 | POST | /v1/burst_engine/simulation_timestep | POST_feagi_burstEngine | FR.update_burst_delay ← TopBar.gd | USER_FEATURE | no |
| 55 | GET | /v1/input/vision | GET_input_vision | FR.retrieve_vision_tuning_parameters ← WindowOptionsMenu.gd | USER_FEATURE | no |
| 56 | POST | /v1/input/vision | POST_input_vision | FR.send_vision_tuning_parameters ← WindowOptionsMenu.gd | USER_FEATURE | no |
| 57 | POST | /v1/insight/neurons/membrane_potential_set | POST_monitoring_neuron_membranePotential_set | FR.toggle_membrane_monitoring ← AdvancedCorticalProperties.gd | USER_FEATURE | no |
| 58 | PUT | /v1/cortical_area/suppress_cortical_visibility | PUT_corticalArea_suppressCorticalVisibility | FR.set_cortical_areas_that_are_invisible ← WindowViewCorticalArea.gd | USER_FEATURE | no |
| 59 | PUT | /v1/cortical_area/reset | PUT_corticalArea_reset | FR.mass_reset_cortical_areas ← WindowQuickMenu.gd, AdvancedCorticalProperties.gd | USER_FEATURE | no |
| 60 | GET | /v1/agent/shared_mem **[AGENT]** | GET_agent_shared_mem | WindowViewPreviews.gd `_try_fetch_video_shm_from_api` | USER_FEATURE | no |
| 61 | POST | /v1/agent/manual_stimulation **[AGENT]** | POST_agent_manualStimulation | UIManager.gd `_send_activations_to_FEAGI`; WindowViewPreviews.gd `_send_segmentation_to_feagi` | USER_FEATURE | no |
| 62 | POST | /v1/agent/{agent_id}/device_registrations **[AGENT]** | POST_agent_device_registrations | FR.import_device_registrations ← WindowIPUOPUConfig.gd | USER_FEATURE | no |
| 63 | GET | /v1/cortical_area/ipu | GET_corticalAreas_ipu | — | UNUSED | no |
| 64 | GET | /v1/cortical_area/opu | GET_corticalAreas_opu | — | UNUSED | no |
| 65 | GET | /v1/cortical_area/cortical_area_id_list | GET_corticalAreas_corticalAreaIDList | — | UNUSED | no |
| 66 | GET | /v1/morphology/morphology_list | GET_neuronMorphologies_morphologyList | — | UNUSED | no |
| 67 | GET | /v1/genome/file_name | GET_genome_fileName | — | UNUSED | no |
| 68 | GET | /v1/cortical_area/cortical_area_name_list | GET_corticalAreas_corticalAreaNameList | — | UNUSED | no |
| 69 | POST | /v1/cortical_area/cortical_name_location | POST_corticalAreas_corticalNameLocation | — | UNUSED | no |
| 70 | POST | /v1/cortical_mapping/afferents | POST_corticalMappings_afferents | — | UNUSED | no |
| 71 | POST | /v1/cortical_mapping/efferents | POST_corticalMappings_efferents | — | UNUSED | no |
| 72 | GET | /v1/genome/circuits | GET_genome_circuits | — | UNUSED | no |
| 73 | GET | /v1/morphology/morphology_types | GET_morphology_morphology_types | — | UNUSED | no |
| 74 | GET | /v1/cortical_area/cortical_id_name_mapping | GET_corticalArea_corticalIDNameMapping | — | UNUSED | no |
| 75 | GET | /v1/cortical_area/cortical_locations_2d | GET_corticalArea_corticalLocations2D | — | UNUSED | no |
| 76 | GET | /v1/cortical_area/cortical_types | GET_corticalArea_corticalTypes | — (replaced by ipu/opu types) | UNUSED | no |
| 77 | GET | /v1/connectome/properties/dimensions | GET_connectome_properties_dimensions | — | UNUSED | no |
| 78 | GET | /v1/connectome/properties/mappings | GET_connectome_properties_mappings | — | UNUSED | no |
| 79 | GET | /v1/connectome/cortical_areas/list/detailed | GET_connectome_corticalAreas_list_detailed | — | UNUSED | no |
| 80 | POST | /v1/insight/neurons/membrane_potential_status | POST_insight_neurons_membranePotentialStatus | — | UNUSED | no |
| 81 | POST | /v1/insight/neuron/synaptic_potential_status | POST_insight_neuron_synapticPotentialStatus | — | UNUSED | no |
| 82 | GET | /v1/morphology/list/types | GET_morphology_list_types | — | UNUSED | no |
| 83 | GET | /v1/cortical_area/cortical_visibility | GET_corticalArea_corticalVisibility | — | UNUSED | no |
| 84 | GET | /v1/agent/properties **[AGENT]** | GET_agent_properties | — | UNUSED | no |
| 85 | GET | /v1/cortical_area/classifier/{classifier_id} | GET_genome_classifier | — | UNUSED | no |
| 86 | POST | /v1/cortical_area/classifier/{classifier_id}/field | POST_genome_classifier_field | — | UNUSED | no |
| 87 | DELETE | /v1/cortical_area/classifier/{classifier_id}/field | DELETE_genome_classifier_field | — | UNUSED | no |
| 88 | POST | /v1/feagi/genome/append | POST_genome_append | — | UNUSED | no |
| 89 | POST | /v1/insight/neuron/synaptic_potential_set | POST_monitoring_neuron_synapticPotential_set | — (see known issue 1) | UNUSED | no |
| 90 | POST | /v1/agent/register **[AGENT]** | POST_agent_register | — (REST registration deprecated) | UNUSED | no |
| 91 | POST | /v1/agent/heartbeat **[AGENT]** | POST_agent_heartbeat | — (BV sends no heartbeats) | UNUSED | no |
| 92 | PUT | /v1/cortical_area/coord_2d | PUT_genome_coord2d | — | UNUSED | no |
| 93 | PUT | /v1/system/cortical_area_visualization_skip_rate | PUT_system_corticalAreaVisualizationSkipRate | FR.change_skip_rate exists, no callers | UNUSED | no |
| 94 | PUT | v1/system/cortical_area_visualization_suppression_threshold | PUT_system_corticalAreaVisualizationSupressionThreshold | FR.change_supression_threshold exists, no callers (see known issue 2) | UNUSED | no |
| 95 | PUT | /v1/neuroplasticity/plasticity_queue_depth | PUT_neuroplasticity_plasticityQueueDepth | FR.update_plasticity_queue_depth exists, no callers | UNUSED | no |
| 96 | DELETE | /v1/region/region_and_members | DELETE_region_regionAndMembers | — | UNUSED | no |

Agent routes: 9. One is used automatically (#4); two are EDIT (#20, #21); three are USER_FEATURE
(#60-62); three are unused (#84, #90, #91). `supports_feature()` gates #4, #20, #21, #61 and #62 off
on a zenoh FEAGI; #60 (`shared_mem`, video previews) is not gated yet.

## Known issues found while compiling this

1. `FR.toggle_synaptic_monitoring` (FR:2582) uses `address_list.POST_MON_neuron_membranePotential`,
   which the address list does not declare, so the call fails when triggered from
   AdvancedCorticalProperties.gd. It most likely should use `POST_monitoring_neuron_synapticPotential_set` (#89).
2. `PUT_system_corticalAreaVisualizationSupressionThreshold` has no leading `/`, so its URL is built
   wrong. Nothing calls it today.
3. `POST_genome_corticalArea` is declared but unused; `add_IOPU_cortical_area` POSTs to the same path
   through the `PUT_genome_corticalArea` var.
4. `/v1/region/relocate_members` is declared twice (`PUT_genome_relocate_members`, `PUT_region_relocateMembers`).
