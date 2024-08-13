#!/bin/bash

# Input file and line number to replace
file_path="godot_source/BrainVisualizer/BVVersion.gd"
line_number="8"

# Get current UNIX timestamp
timestamp=$(date +%s)
full_line="	get: return $timestamp"

sed -i "${line_number}s/.*/$full_line/" "$file_path"

