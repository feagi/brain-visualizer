#!/bin/bash
#
# Copyright 2025 Neuraville Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Input file and line number to replace
file_path="godot_source/BrainVisualizer/BVVersion.gd"
line_number="8"

# Get current UNIX timestamp
timestamp=$(date +%s)
full_line="	get: return $timestamp"

sed -i "${line_number}s/.*/$full_line/" "$file_path"

