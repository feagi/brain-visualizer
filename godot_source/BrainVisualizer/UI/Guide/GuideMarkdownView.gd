extends RichTextLabel
class_name GuideMarkdownView

signal markdown_link_clicked(target_path: String)

var _current_markdown_path: String = ""
var _base_font_size: int = 0
var _font_scale: float = 1.0  # User-adjustable scale multiplier

## Configure the label defaults for guide rendering.
func _ready() -> void:
	bbcode_enabled = true
	scroll_active = false  # Parent ScrollContainer handles scrolling
	fit_content = false  # Let the container handle sizing
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_enabled = true
	meta_clicked.connect(_on_meta_clicked)
	# Cache the base font size once at initialization to prevent compounding
	_base_font_size = _resolve_initial_font_size()
	add_theme_color_override("default_color", Color(0.92, 0.94, 0.98))
	# Add better line spacing for readability
	add_theme_constant_override("line_separation", int(_base_font_size * 0.3))

## Load and render a markdown file.
func load_markdown(markdown_path: String) -> void:
	_current_markdown_path = markdown_path
	# Apply cached base font size with user scale multiplier
	var scaled_font_size := int(_base_font_size * _font_scale)
	add_theme_font_size_override("normal_font_size", scaled_font_size)
	
	var file := FileAccess.open(markdown_path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("GuideMarkdownView: Unable to read markdown at %s. Error: %d" % [markdown_path, error])
		text = "[color=red]Error: Could not load guide file[/color]"
		return
	
	var markdown_text := file.get_as_text()
	file.close()
	
	var bbcode := _convert_markdown_to_bbcode(markdown_text, markdown_path)
	
	text = bbcode
	# Wait for text rendering to complete
	await get_tree().process_frame
	await get_tree().process_frame
	# Set minimum height based on actual content
	var content_height := get_content_height()
	custom_minimum_size = Vector2(0, content_height)
	size.y = content_height

## Set the user-adjustable font scale multiplier and reload current content.
func set_font_scale(scale: float) -> void:
	_font_scale = scale
	# Reload current markdown with new scale
	if _current_markdown_path != "":
		load_markdown(_current_markdown_path)

## Display a short message when no guide content is available.
func show_message(message: String) -> void:
	_current_markdown_path = ""
	# Use cached base font size with scale
	var scaled_font_size := int(_base_font_size * _font_scale)
	add_theme_font_size_override("normal_font_size", scaled_font_size)
	text = "[i]%s[/i]" % message
	await get_tree().process_frame
	var content_height := get_content_height()
	custom_minimum_size = Vector2(0, content_height)
	size.y = content_height

## Handle link clicks inside the rendered markdown.
func _on_meta_clicked(meta: Variant) -> void:
	if typeof(meta) != TYPE_STRING:
		return
	var target_path: String = meta
	if target_path == "":
		return
	markdown_link_clicked.emit(target_path)

## Convert markdown text into BBCode for RichTextLabel rendering.
func _convert_markdown_to_bbcode(markdown_text: String, markdown_path: String) -> String:
	var lines := markdown_text.split("\n", true)
	var output_lines: Array[String] = []
	var in_list := false
	
	for raw_line in lines:
		var line := raw_line
		var trimmed := line.strip_edges()
		
		# Handle headings
		if trimmed.begins_with("#"):
			if in_list:
				in_list = false
			var heading_level := _count_heading_level(line)
			var title := line.substr(heading_level).strip_edges()
			output_lines.append("")
			output_lines.append(_format_heading(title, heading_level))
			output_lines.append("")
			continue
		
		# Handle empty lines
		if trimmed == "":
			if in_list:
				in_list = false
			output_lines.append("")
			continue
		
		# Handle bullets with proper indentation
		if trimmed.begins_with("- "):
			if not in_list:
				in_list = true
			# Extract bullet content and process inline formatting
			var bullet_text := trimmed.substr(2).strip_edges()
			bullet_text = _replace_images(bullet_text, markdown_path)
			bullet_text = _replace_links(bullet_text, markdown_path)
			bullet_text = _replace_inline_code(bullet_text)
			bullet_text = _replace_bold(bullet_text)
			bullet_text = _replace_italics(bullet_text)
			output_lines.append("  • " + bullet_text)
		else:
			if in_list:
				in_list = false
			# Process inline formatting for regular paragraphs
			line = _replace_images(line, markdown_path)
			line = _replace_links(line, markdown_path)
			line = _replace_inline_code(line)
			line = _replace_bold(line)
			line = _replace_italics(line)
			output_lines.append(line)
	
	var result := "\n".join(output_lines)
	return result

## Count heading markers for a markdown heading line.
func _count_heading_level(line: String) -> int:
	var count := 0
	for i in range(line.length()):
		if line[i] != "#":
			break
		count += 1
	return maxi(1, count)

## Format a markdown heading into BBCode with size scaling.
func _format_heading(title: String, level: int) -> String:
	var base_size := int(_base_font_size * _font_scale)
	if base_size <= 0:
		base_size = 20
	
	# Scale heading sizes based on level
	var size: int
	match level:
		1:
			size = int(base_size * 1.8)  # H1: 80% larger
		2:
			size = int(base_size * 1.5)  # H2: 50% larger
		3:
			size = int(base_size * 1.3)  # H3: 30% larger
		_:
			size = int(base_size * 1.15) # H4+: 15% larger
	
	# Add color for headings to make them stand out
	var color := "8ab4f8"  # Light blue color
	return "[font_size=%d][b][color=#%s]%s[/color][/b][/font_size]" % [size, color, title]

## Convert markdown bold markers to BBCode.
func _replace_bold(line: String) -> String:
	var result := ""
	var i := 0
	
	while i < line.length():
		# Check for ** marker
		if i < line.length() - 1 and line[i] == "*" and line[i + 1] == "*":
			# Found opening **, now find closing **
			var end := i + 2
			var found_end := false
			
			while end < line.length() - 1:
				if line[end] == "*" and line[end + 1] == "*":
					found_end = true
					break
				end += 1
			
			if found_end:
				# Extract content between ** markers
				var content := line.substr(i + 2, end - i - 2)
				result += "[b]%s[/b]" % content
				i = end + 2  # Skip past closing **
				continue
		
		# No markdown found, just add the character
		result += line[i]
		i += 1
	
	return result

## Convert markdown italics markers to BBCode.
func _replace_italics(line: String) -> String:
	var result := ""
	var i := 0
	
	while i < line.length():
		# Check for single * marker (not part of **)
		if line[i] == "*":
			# Make sure it's not part of ** or [b] tag
			var is_double_before := i > 0 and line[i - 1] == "*"
			var is_double_after := i < line.length() - 1 and line[i + 1] == "*"
			var is_bbcode := i > 0 and line[i - 1] == "["  # Skip if already converted to BBCode
			
			if not is_double_before and not is_double_after and not is_bbcode:
				# Found opening *, now find closing *
				var end := i + 1
				var found_end := false
				
				while end < line.length():
					if line[end] == "*":
						# Make sure closing * is also not part of **
						var end_is_double := end < line.length() - 1 and line[end + 1] == "*"
						if not end_is_double:
							found_end = true
							break
					end += 1
				
				if found_end:
					# Extract content between * markers
					var content := line.substr(i + 1, end - i - 1)
					result += "[i]%s[/i]" % content
					i = end + 1  # Skip past closing *
					continue
		
		# No markdown found, just add the character
		result += line[i]
		i += 1
	
	return result

## Convert markdown inline code markers to BBCode with background.
func _replace_inline_code(line: String) -> String:
	var result := ""
	var i := 0
	
	while i < line.length():
		# Check for ` marker
		if line[i] == "`":
			# Found opening `, now find closing `
			var end := i + 1
			var found_end := false
			
			while end < line.length():
				if line[end] == "`":
					found_end = true
					break
				end += 1
			
			if found_end:
				# Extract content between ` markers
				var content := line.substr(i + 1, end - i - 1)
				result += "[code]%s[/code]" % content
				i = end + 1  # Skip past closing `
				continue
		
		# No markdown found, just add the character
		result += line[i]
		i += 1
	
	return result

## Resolve the initial theme font size once at startup.
## This is only called in _ready() to cache the base font size.
func _resolve_initial_font_size() -> int:
	# Get the base theme size from the theme (not from any override)
	var size := get_theme_font_size("normal_font_size", "RichTextLabel")
	if size > 0:
		return int(size * 2.0)
	# Fallback to default if no theme size found
	return 32

## Convert markdown image syntax to BBCode image tags.
func _replace_images(line: String, markdown_path: String) -> String:
	return _replace_regex_callback(line, "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)", func(match: RegExMatch) -> String:
		var raw_path := match.get_string(2)
		var resolved := _resolve_relative_path(markdown_path, raw_path)
		return "[img]%s[/img]" % resolved
	)

## Convert markdown link syntax to BBCode URL tags.
func _replace_links(line: String, markdown_path: String) -> String:
	return _replace_regex_callback(line, "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", func(match: RegExMatch) -> String:
		var label := match.get_string(1)
		var raw_path := match.get_string(2)
		var resolved := _resolve_relative_path(markdown_path, raw_path)
		# Make links blue and underlined
		return "[url=%s][color=#4a9eff][u]%s[/u][/color][/url]" % [resolved, label]
	)

## Resolve a markdown relative path against the current markdown file.
func _resolve_relative_path(markdown_path: String, raw_path: String) -> String:
	if raw_path.begins_with("res://") or raw_path.begins_with("http://") or raw_path.begins_with("https://"):
		return raw_path
	if markdown_path == "":
		return raw_path
	var base_dir := markdown_path.get_base_dir()
	var joined := base_dir.path_join(raw_path)
	return joined.simplify_path()

## Replace regex matches with a fixed replacement string.
func _replace_regex(line: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		push_error("GuideMarkdownView: Regex compile failed for pattern: %s" % pattern)
		return line
	return regex.sub(line, replacement, true)

## Replace regex matches using a callback for dynamic replacements.
func _replace_regex_callback(line: String, pattern: String, replacer: Callable) -> String:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		push_error("GuideMarkdownView: Regex compile failed for pattern: %s" % pattern)
		return line
	var result := ""
	var last_index := 0
	for match in regex.search_all(line):
		result += line.substr(last_index, match.get_start() - last_index)
		result += replacer.call(match)
		last_index = match.get_end()
	result += line.substr(last_index)
	return result
