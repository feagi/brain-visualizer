extends SceneTree
## Guide sidebar outline: one file is a topic, each H2 is a section.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/GuideWindow/test_guide_outline.gd

const MarkdownView = preload("res://BrainVisualizer/UI/Guide/GuideMarkdownView.gd")
const _COLLAPSIBLE_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures := 0
	failures += _test_h2_sections_ignore_h3()
	failures += _test_preamble_becomes_overview()
	failures += _test_no_preamble_skips_overview()
	failures += _test_classifier_heading_stays_addressable()
	failures += _test_sidebar_labels_stay_short()
	failures += _test_heading_marker_is_not_body_text()
	failures += _test_heading_sits_against_following_paragraph()
	failures += _test_web_links_are_browser_urls()
	failures += _test_section_button_fits_collapsible()
	if failures == 0:
		print("Guide outline tests: PASS")
		quit(0)
	else:
		push_error("Guide outline tests: FAIL (%d)" % failures)
		quit(1)


func _test_h2_sections_ignore_h3() -> int:
	var outline: Dictionary = MarkdownView.extract_outline("# Page\n\n## Alpha\n\n### Detail\n\nbody\n\n## Beta\n")
	if str(outline["title"]) != "Page":
		push_error("page title must come from the H1")
		return 1
	var sections: Array = outline["sections"]
	if sections.size() != 2:
		push_error("only H2 headings are sidebar sections")
		return 1
	if str(sections[0]["title"]) != "Alpha" or str(sections[0]["heading"]) != "Alpha":
		push_error("first section must be Alpha")
		return 1
	if str(sections[0]["body"]).find("Detail") < 0 or str(sections[0]["body"]).find("body") < 0:
		push_error("H3 and following text stay in the H2 body")
		return 1
	if str(sections[1]["title"]) != "Beta":
		push_error("second section must be Beta")
		return 1
	return 0


func _test_preamble_becomes_overview() -> int:
	var outline: Dictionary = MarkdownView.extract_outline("# Page\n\nIntro paragraph.\n\n## Later\n")
	var sections: Array = outline["sections"]
	if sections.size() != 2:
		push_error("intro text before the first H2 needs an Overview entry")
		return 1
	if str(sections[0]["title"]) != "Overview" or str(sections[0]["heading"]) != "":
		push_error("Overview scrolls to the top of the page")
		return 1
	if str(sections[0]["body"]).find("Intro paragraph.") < 0:
		push_error("Overview body must include the introduction")
		return 1
	return 0


func _test_no_preamble_skips_overview() -> int:
	var outline: Dictionary = MarkdownView.extract_outline("# Page\n\n## First\n")
	var sections: Array = outline["sections"]
	if sections.size() != 1 or str(sections[0]["title"]) != "First":
		push_error("a page that starts at its first H2 has no Overview entry")
		return 1
	return 0


func _test_classifier_heading_stays_addressable() -> int:
	var text := FileAccess.get_file_as_string("res://BrainVisualizer/Guides/integrated_circuits.md")
	var outline: Dictionary = MarkdownView.extract_outline(text)
	var found := false
	for section in outline["sections"]:
		if str(section["heading"]) == "Edit a Classifier":
			found = true
	if not found:
		push_error("classifier help must still open the Edit a Classifier section")
		return 1
	return 0


func _test_sidebar_labels_stay_short() -> int:
	var paths: PackedStringArray = [
		"res://BrainVisualizer/Guides/navigation_actions_reference.md",
		"res://BrainVisualizer/Guides/cortical_area_details.md",
		"res://BrainVisualizer/Guides/navigation.md",
	]
	for path in paths:
		var outline: Dictionary = MarkdownView.extract_outline(FileAccess.get_file_as_string(path))
		for section in outline["sections"]:
			var title := str(section["title"])
			if title.length() > 40:
				push_error("sidebar label is too long (%d): %s" % [title.length(), title])
				return 1
	return 0


func _test_heading_marker_is_not_body_text() -> int:
	if MarkdownView.HEADING_MARKER != "\u200b":
		push_error("heading scroll marker must stay invisible")
		return 1
	return 0


## http and https links are browser targets. Guide files are not.
func _test_web_links_are_browser_urls() -> int:
	var studio := "https://brainsforrobots.com/nrs"
	if not MarkdownView.is_web_url(studio) or not MarkdownView.is_web_url("http://brainsforrobots.com/nrs"):
		push_error("web guide links must open in a browser")
		return 1
	if MarkdownView.is_web_url("res://BrainVisualizer/Guides/glossary.md"):
		push_error("guide file links must stay inside the window")
		return 1
	return 0


## A heading and the paragraph under it must not be split by a blank line.
func _test_heading_sits_against_following_paragraph() -> int:
	var view: GuideMarkdownView = MarkdownView.new()
	var source := "## What is Brain Visualizer?\n\nBrain Visualizer is a tool.\n"
	var bbcode: String = view._convert_markdown_to_bbcode(source, "")
	view.free()
	var marker := "[/font_size]\nBrain Visualizer is a tool."
	if bbcode.find(marker) < 0:
		push_error("heading must be followed immediately by its paragraph, got: %s" % bbcode)
		return 1
	return 0


func _test_section_button_fits_collapsible() -> int:
	var section: VerticalCollapsibleHiding = _COLLAPSIBLE_PREFAB.instantiate()
	section.section_text = StringName("Camera")
	section.start_open = false
	var title_label: Label = section.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
	title_label.text = "Camera"
	root.add_child(section)
	if section.is_open:
		push_error("guide topics must start collapsed")
		section.queue_free()
		return 1
	var holder := VBoxContainer.new()
	section.get_control().add_child(holder)
	var button := GuideTopicButton.new()
	button.setup("3D Camera Controls", "res://BrainVisualizer/Guides/navigation_actions_reference.md", "3D Camera Controls", true)
	holder.add_child(button)
	section.is_open = true
	var body: CanvasItem = section.get_node("VerticalCollapsible/PanelContainer")
	if not body.visible or button.text != "3D Camera Controls":
		push_error("section button must sit inside the expanded topic")
		section.queue_free()
		return 1
	section.queue_free()
	return 0
