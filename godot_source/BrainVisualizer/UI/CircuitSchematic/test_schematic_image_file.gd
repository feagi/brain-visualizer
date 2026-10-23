extends SceneTree
## SchematicImageFile: image size caps, encoders, and the one-page PDF layout.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/CircuitSchematic/test_schematic_image_file.gd
## Pass a path after "--" to also keep the sample PDF for an outside check: ... -- /tmp/sample.pdf


func _initialize() -> void:
	var failures: int = 0
	failures += _test_scale_caps()
	failures += _test_encoders()
	failures += _test_pdf_layout()
	if failures == 0:
		print("Schematic image file tests: PASS")
		quit(0)
	else:
		push_error("Schematic image file tests: FAIL (%d)" % failures)
		quit(1)


func _test_scale_caps() -> int:
	var failures: int = 0
	if not is_equal_approx(SchematicImageFile.export_scale(Vector2(800, 600)), SchematicImageFile.MAX_SCALE):
		failures += _fail("small canvas should use the max scale")
	for canvas: Vector2 in [Vector2(40000, 300), Vector2(9000, 9000), Vector2(300, 60000)]:
		var scale: float = SchematicImageFile.export_scale(canvas)
		var pixels: Vector2 = canvas * scale + Vector2.ONE * SchematicImageFile.MARGIN_PX * 2
		if maxf(pixels.x, pixels.y) > SchematicImageFile.MAX_SIDE_PX + 1.0 or canvas.x * canvas.y * scale * scale > SchematicImageFile.MAX_PIXELS + 1.0:
			failures += _fail("canvas %s exceeds caps at scale %f" % [canvas, scale])
	return failures


func _test_encoders() -> int:
	var failures: int = 0
	var image: Image = _sample_image()
	var png: PackedByteArray = SchematicImageFile.encode(image, SchematicImageFile.FORMAT.PNG)
	if png.slice(0, 4) != PackedByteArray([0x89, 0x50, 0x4E, 0x47]):
		failures += _fail("PNG signature missing")
	var jpg: PackedByteArray = SchematicImageFile.encode(image, SchematicImageFile.FORMAT.JPG)
	if jpg.slice(0, 2) != PackedByteArray([0xFF, 0xD8]):
		failures += _fail("JPG signature missing")
	var decoded: Image = Image.new()
	if decoded.load_jpg_from_buffer(jpg) != OK or decoded.get_size() != image.get_size():
		failures += _fail("JPG does not decode to the same size")
	return failures


func _test_pdf_layout() -> int:
	var failures: int = 0
	var image: Image = _sample_image()
	var pdf: PackedByteArray = SchematicImageFile.encode(image, SchematicImageFile.FORMAT.PDF)
	var text: String = pdf.get_string_from_ascii()
	if not text.begins_with("%PDF-1.4"):
		failures += _fail("PDF header missing")
	if not text.contains("/MediaBox [0 0 240.00 120.00]"):
		failures += _fail("page should be the image size at 96 dpi")
	# Every xref entry must point at the start of its object.
	var tail: String = pdf.slice(pdf.size() - 64).get_string_from_ascii()
	var xref_at: int = int(tail.split("startxref\n")[1].split("\n")[0])
	var xref: PackedStringArray = pdf.slice(xref_at).get_string_from_ascii().split("\n")
	for i in 5:
		var offset: int = int(xref[3 + i].substr(0, 10))
		var header: String = pdf.slice(offset, offset + 8).get_string_from_ascii()
		if not header.begins_with("%d 0 obj" % (i + 1)):
			failures += _fail("xref entry %d points at '%s'" % [i + 1, header])
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_buffer(pdf)
		file.close()
	return failures


## 320 x 160 px with a gradient, so the JPG has real content.
func _sample_image() -> Image:
	var image: Image = Image.create(320, 160, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(x / 320.0, y / 160.0, 0.5))
	return image


func _fail(message: String) -> int:
	push_error("FAIL: " + message)
	return 1
