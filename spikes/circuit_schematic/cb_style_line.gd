extends GraphElement
## Mimics today's Circuit Builder cost per connection (CBLineInterTerminal): one GraphElement holding a
## 20-point Line2D with its own ShaderMaterial copy and a Button. Terminals are added by the runner.

const NUM_POINTS: int = 20

static var _shader: Shader


func setup(start: Vector2, finish: Vector2, color: Color) -> void:
	selectable = false
	draggable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bounds: Rect2 = Rect2(start, Vector2.ZERO).expand(finish).grow(100.0)
	position_offset = bounds.position
	size = bounds.size
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type canvas_item;\nuniform vec4 baseColor = vec4(1.0);\nuniform bool isDashed = false;\nvoid fragment() { COLOR = baseColor; }"
	var material_copy: ShaderMaterial = ShaderMaterial.new()
	material_copy.shader = _shader
	material_copy.set_shader_parameter(&"baseColor", Vector4(color.r, color.g, color.b, color.a))
	var line: Line2D = Line2D.new()
	line.width = 2.0
	line.material = material_copy
	var a: Vector2 = start - bounds.position
	var b: Vector2 = finish - bounds.position
	var reach: float = maxf(80.0, absf(b.x - a.x) * 0.5)
	for i in NUM_POINTS:
		var t: float = float(i) / (NUM_POINTS - 1)
		line.add_point(a.bezier_interpolate(a + Vector2(reach, 0), b - Vector2(reach, 0), b, t))
	add_child(line)
	var button: Button = Button.new()
	button.flat = true
	button.size = Vector2(16, 16)
	button.position = a.lerp(b, 0.5) - Vector2(8, 8)
	add_child(button)
