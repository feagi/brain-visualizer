# Cortical Inspector

Live tuner for one cortical area. Open it from the Inspectors menu.

The window lists neuron firing parameters and postsynaptic potential. Moving a slider or toggle sends that property to FEAGI immediately. FEAGI applies parameter changes on the next burst. There is no Apply button.

Min and max fields beside an unbounded slider set only that slider's range. They do not write FEAGI. Leak and excitability stay on a fixed 0-100 percent scale.

The area button opens a name filter. A click on a cortical area in the 3D view, while this window is open, focuses that area and keeps the slider ranges already set.

Core areas are read-only. Memory areas hide membrane-potential accumulation, leak, and threshold increment. Leak variability is not included because FEAGI treats it as a structural change.
