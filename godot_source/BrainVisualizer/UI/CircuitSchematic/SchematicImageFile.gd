extends RefCounted
class_name SchematicImageFile
## Formats, size caps and encoders for exporting the Circuit Schematic: PNG, JPG, or a one-page PDF
## holding that JPG. No scene or app state, so it can be tested on its own.

enum FORMAT { PNG, JPG, PDF }

const EXTENSIONS: Array[String] = ["png", "jpg", "pdf"]
const LABELS: Array[String] = ["PNG image", "JPG image", "PDF document"]
const MIME_TYPES: Array[String] = ["image/png", "image/jpeg", "application/pdf"]
const MAX_SCALE: float = 2.0
const MAX_SIDE_PX: float = 8192.0
const MAX_PIXELS: float = 40_000_000.0
const MARGIN_PX: int = 32 ## around the canvas, in output pixels
const JPG_QUALITY: float = 0.92
const PDF_POINTS_PER_PX: float = 0.75 ## 96 dpi


static func default_file_name(format: FORMAT) -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	return "circuit_schematic_%s.%s" % [stamp, EXTENSIONS[format]]


## Canvas with the legend under it, separated by [constant MARGIN_PX].
## [param brand] is the FEAGI logo, pinned to the bottom-right corner of the page.
## When growing the page would pass a size cap, both are drawn over the bottom of the canvas instead.
static func composite_legend(canvas: Image, legend: Image, brand: Image = null) -> Image:
	var gap := MARGIN_PX
	var key := _matched(legend, canvas.get_format())
	var mark := _matched(brand, canvas.get_format()) if brand != null else null
	var footer_h := key.get_height()
	if mark != null:
		footer_h = maxi(footer_h, mark.get_height())
	var width := maxi(canvas.get_width(), key.get_width() + gap * 2)
	if mark != null:
		width = maxi(width, key.get_width() + mark.get_width() + gap * 3)
	var height := canvas.get_height() + gap + footer_h
	var over_cap := height > int(MAX_SIDE_PX) or width > int(MAX_SIDE_PX) or float(width * height) > MAX_PIXELS
	if over_cap:
		var over := canvas.duplicate() as Image
		var key_dest := Vector2i(mini(gap, over.get_width() - 1), maxi(0, over.get_height() - key.get_height() - gap))
		var key_copy := Vector2i(mini(key.get_width(), over.get_width() - key_dest.x), mini(key.get_height(), over.get_height() - key_dest.y))
		over.blit_rect(key, Rect2i(Vector2i.ZERO, key_copy), key_dest)
		if mark != null:
			var mark_dest := Vector2i(maxi(0, over.get_width() - mark.get_width() - gap), maxi(0, over.get_height() - mark.get_height() - gap))
			var mark_copy := Vector2i(mini(mark.get_width(), over.get_width() - mark_dest.x), mini(mark.get_height(), over.get_height() - mark_dest.y))
			over.blend_rect(mark, Rect2i(Vector2i.ZERO, mark_copy), mark_dest)
		return over
	var combined := Image.create(width, height, false, canvas.get_format())
	combined.fill(canvas.get_pixel(0, 0))
	combined.blit_rect(canvas, Rect2i(Vector2i.ZERO, canvas.get_size()), Vector2i.ZERO)
	combined.blit_rect(key, Rect2i(Vector2i.ZERO, key.get_size()), Vector2i(gap, canvas.get_height() + gap))
	if mark != null:
		var mark_y := height - gap - mark.get_height()
		combined.blend_rect(mark, Rect2i(Vector2i.ZERO, mark.get_size()), Vector2i(width - gap - mark.get_width(), mark_y))
	return combined


## Drops the light gray plate that was saved as opaque pixels, leaving the mark on a clear background.
static func clear_logo_plate(image: Image) -> void:
	var plate := Color8(230, 232, 232)
	var tolerance := 18.0 / 255.0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			if absf(pixel.r - plate.r) > tolerance or absf(pixel.g - plate.g) > tolerance or absf(pixel.b - plate.b) > tolerance:
				continue
			image.set_pixel(x, y, Color(0, 0, 0, 0))


static func _matched(image: Image, format: Image.Format) -> Image:
	var copy := image.duplicate() as Image
	if copy.get_format() != format:
		copy.convert(format)
	return copy


## Pixels per canvas unit: up to [constant MAX_SCALE], shrunk to keep the image within the size caps.
static func export_scale(canvas_size: Vector2) -> float:
	var usable_side: float = MAX_SIDE_PX - MARGIN_PX * 2
	var scale: float = minf(MAX_SCALE, usable_side / maxf(maxf(canvas_size.x, canvas_size.y), 1.0))
	return minf(scale, sqrt(MAX_PIXELS / maxf(canvas_size.x * canvas_size.y, 1.0)))


static func encode(image: Image, format: FORMAT) -> PackedByteArray:
	if format == FORMAT.PNG:
		return image.save_png_to_buffer()
	var rgb: Image = image.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var jpg: PackedByteArray = rgb.save_jpg_to_buffer(JPG_QUALITY)
	if format == FORMAT.JPG:
		return jpg
	return pdf_from_jpg(jpg, rgb.get_width(), rgb.get_height())


## A one-page PDF whose page is exactly the image, which is embedded as-is (DCTDecode).
static func pdf_from_jpg(jpg: PackedByteArray, width_px: int, height_px: int) -> PackedByteArray:
	var width_pt: float = width_px * PDF_POINTS_PER_PX
	var height_pt: float = height_px * PDF_POINTS_PER_PX
	var image_object: PackedByteArray = ("<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n" % [width_px, height_px, jpg.size()]).to_ascii_buffer()
	image_object.append_array(jpg)
	image_object.append_array("\nendstream".to_ascii_buffer())
	var content: String = "q %.2f 0 0 %.2f 0 0 cm /Im0 Do Q" % [width_pt, height_pt]
	var objects: Array[PackedByteArray] = [
		"<< /Type /Catalog /Pages 2 0 R >>".to_ascii_buffer(),
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_ascii_buffer(),
		("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] /Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>" % [width_pt, height_pt]).to_ascii_buffer(),
		image_object,
		("<< /Length %d >>\nstream\n%s\nendstream" % [content.length(), content]).to_ascii_buffer(),
	]
	var out: PackedByteArray = "%PDF-1.4\n".to_ascii_buffer()
	out.append_array(PackedByteArray([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A])) # marks the file as binary
	var offsets: Array[int] = []
	for i in objects.size():
		offsets.append(out.size())
		out.append_array(("%d 0 obj\n" % (i + 1)).to_ascii_buffer())
		out.append_array(objects[i])
		out.append_array("\nendobj\n".to_ascii_buffer())
	var xref_offset: int = out.size()
	var xref: String = "xref\n0 %d\n0000000000 65535 f \n" % (objects.size() + 1)
	for offset in offsets:
		xref += "%010d 00000 n \n" % offset
	xref += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [objects.size() + 1, xref_offset]
	out.append_array(xref.to_ascii_buffer())
	return out
