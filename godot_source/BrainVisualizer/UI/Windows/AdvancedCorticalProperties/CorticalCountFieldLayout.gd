extends RefCounted
## Width rules for the neuron and synapse count fields in Cortical Area Details.


const MIN_COUNT_FIELD_WIDTH_PX: float = 190.0
## Floor for "total (ST: … | LT: …)" so the memory readout stays visible at larger UI scales.
const MEMORY_COUNT_FIELD_WIDTH_PX: float = 420.0
## Extra pixels beyond measured text and style margins so the readout is not clipped.
const COUNT_FIELD_TEXT_PADDING_PX: float = 16.0


## Width needed to show [param text_width] inside a count field, never below [param floor_width].
static func count_field_width_px(text_width: float, style_horizontal_padding: float, floor_width: float) -> float:
	return maxf(floor_width, ceil(text_width + style_horizontal_padding + COUNT_FIELD_TEXT_PADDING_PX))


## Standard count fields stay narrow. Memory neuron readouts use the wider floor.
static func floor_width_for_display(displayed_text: String) -> float:
	if displayed_text.contains("(ST:"):
		return MEMORY_COUNT_FIELD_WIDTH_PX
	return MIN_COUNT_FIELD_WIDTH_PX
