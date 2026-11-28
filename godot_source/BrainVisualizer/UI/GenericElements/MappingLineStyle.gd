extends RefCounted
class_name MappingLineStyle
## Shared geometry for how a mapping line is drawn: a smooth static sine wave (associative memory)
## and dashes (plastic). Circuit Builder, the Circuit Schematic and the legend all use it so they match.
## Dashes stay a fixed size on screen and crawl toward the destination, one dash-and-gap per
## [constant DASH_CYCLE_S], so a plastic line still reads when the view is zoomed out. The crawl is
## linear. It holds still when motion is reduced, and at phase 0.

## Screen sizes. Dashed lines are thicker, and the gaps stay large on screen at any zoom.
const SOLID_WIDTH_PX: float = 2.0
const DASHED_WIDTH_PX: float = 4.0
const DASH_LENGTH_PX: float = 18.0
const DASH_GAP_PX: float = 14.0
## One on-and-off pair slides past a point in this many seconds.
const DASH_CYCLE_S: float = 0.9


## Smooth sine wave along the polyline (associative memory). The line is resampled at even arc
## length (wavelength / 12) and each sample is offset along the local normal by
## amplitude * sin(TAU * s / wavelength), tapered to zero over half a wavelength at both ends so the
## endpoints stay on the terminals. Deterministic and static (no seed, no time term).
static func wave_points(points: PackedVector2Array, amplitude: float, wavelength: float) -> PackedVector2Array:
	if points.size() < 2 or wavelength <= 0.0:
		return points.duplicate()
	var cumulative: PackedFloat32Array = [0.0]
	for i in range(1, points.size()):
		cumulative.append(cumulative[i - 1] + points[i - 1].distance_to(points[i]))
	var total: float = cumulative[cumulative.size() - 1]
	if total <= 0.0001:
		return points.duplicate()
	var step: float = wavelength / 12.0
	var samples: int = maxi(int(ceil(total / step)), 2)
	var base: PackedVector2Array = []
	var arc: PackedFloat32Array = []
	var seg: int = 0
	for k in range(samples + 1):
		var s: float = total if k == samples else float(k) * total / float(samples)
		while seg < points.size() - 2 and cumulative[seg + 1] < s:
			seg += 1
		var seg_len: float = cumulative[seg + 1] - cumulative[seg]
		var f: float = 0.0 if seg_len <= 0.0 else clampf((s - cumulative[seg]) / seg_len, 0.0, 1.0)
		base.append(points[seg].lerp(points[seg + 1], f))
		arc.append(s)
	var output: PackedVector2Array = base.duplicate()
	for k in range(1, samples):
		var tangent: Vector2 = base[k + 1] - base[k - 1]
		if tangent.length_squared() <= 0.0000001:
			continue
		var normal: Vector2 = Vector2(-tangent.y, tangent.x).normalized()
		var s2: float = arc[k]
		var envelope: float = clampf(minf(s2, total - s2) / (wavelength * 0.5), 0.0, 1.0)
		output[k] = base[k] + normal * (amplitude * sin(TAU * s2 / wavelength) * envelope)
	return output


## 0 while motion is reduced, otherwise the crawl position in 0..1. One turn is [constant DASH_CYCLE_S].
static func dash_phase() -> float:
	if not dash_motion_enabled():
		return 0.0
	return fposmod(float(Time.get_ticks_msec()) / (DASH_CYCLE_S * 1000.0), 1.0)


## Dash and gap in canvas units for a graph zoom, so both stay [constant DASH_LENGTH_PX] and
## [constant DASH_GAP_PX] on screen.
static func dash_canvas_lengths(zoom: float) -> Vector2:
	var safe_zoom: float = maxf(zoom, 0.0001)
	return Vector2(DASH_LENGTH_PX / safe_zoom, DASH_GAP_PX / safe_zoom)


## False when the platform asks for reduced motion. A missing API leaves the crawl on.
static func dash_motion_enabled() -> bool:
	if DisplayServer.has_method(&"accessibility_should_reduce_motion"):
		return not bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	return true


## Segment pairs (for draw_multiline) covering only the "on" stretches of a dashed line.
## Lengths are in the same units as the points (canvas units), measured along the line.
## [param phase] is 0..1 along one dash-and-gap. Increasing it slides the dashes toward the end of the line.
static func dash_segments(points: PackedVector2Array, dash_len: float, gap_len: float, phase: float = 0.0) -> PackedVector2Array:
	var output: PackedVector2Array = []
	if points.size() < 2 or dash_len <= 0.0:
		return output
	var period: float = dash_len + maxf(gap_len, 0.0)
	var origin: float = fposmod(phase, 1.0) * period
	var travelled: float = 0.0 # arc length at the start of the current segment
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.0:
			continue
		var seg_end: float = travelled + seg_len
		# Walk the dash periods that overlap this segment.
		var k: float = floorf((travelled - origin) / period)
		while k * period + origin < seg_end:
			var on_start: float = maxf(k * period + origin, travelled)
			var on_end: float = minf(k * period + origin + dash_len, seg_end)
			if on_end > on_start:
				output.append(a.lerp(b, (on_start - travelled) / seg_len))
				output.append(a.lerp(b, (on_end - travelled) / seg_len))
			k += 1.0
		travelled = seg_end
	return output
