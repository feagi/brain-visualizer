# Copyright 2016-2024 The FEAGI Authors. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 	http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

extends Object
class_name JSONFileInterface
## Static functions for working with JSON files


## Reads a JSON file at the specified godot path and returns it as a Dict
static func read_existing_json_file(path: StringName) -> Dictionary:
	if !FileAccess.file_exists(path):
		push_error("JSONFileInterface: No config file found at path '%s'" % path)
		return {}
	
	var file_json: String = FileAccess.get_file_as_string(path)
	var output =  JSON.parse_string(file_json) # may be null
	if output == null:
		push_error("JSONFileInterface: Unable to read the file at '' as a JSON" % path)
		return {}
	return output as Dictionary


## Read a JSON file but include required keys / values in the output, and optionally allow for writing / overwriting the json file on disk if missing data
static func read_potential_json_file(path: StringName, required_default_values: Dictionary, write_if_failed: bool = true, refresh_godot_filesystem_after_write: bool = true) -> Dictionary:
	var raw_input: Dictionary = {}
	var failed_default_test: bool = false
	
	# Read json file (if it exists and valid
	if FileAccess.file_exists(path):
		var file_json: String = FileAccess.get_file_as_string(path)
		var json_dict =  JSON.parse_string(file_json) # may be null
		if json_dict != null:
			raw_input = json_dict
	
	# fill in missing required values
	for key in required_default_values.keys():
		if !(key in raw_input.keys()):
			failed_default_test = true
			raw_input[key] = required_default_values[key]
	
	# if enabled, ovewrite / write the json files with the required values included
	if write_if_failed and failed_default_test:
		JSONFileInterface.write_json_file(path, raw_input, true, refresh_godot_filesystem_after_write)
	
	return raw_input


## Write a dictionary to a json file at a path, optionally allowing for overwrites
static func write_json_file(path: StringName, json_dict: Dictionary, allow_overwrite: bool = true, refresh_godot_filesystem_after_write: bool = true) -> void:
	var json: StringName =  JSON.stringify(json_dict)
	var json_file: FileAccess
	if FileAccess.file_exists(path):
		if !allow_overwrite:
			push_warning("JSON file already exists at path %s and overwriting is disabled. Skipping..." % path)
			return
		DirAccess.remove_absolute(path)
	json_file = FileAccess.open(path, FileAccess.WRITE_READ)
	json_file.store_string(json)
	json_file.close()
	
	if refresh_godot_filesystem_after_write:
		EditorInterface.get_resource_filesystem().scan()
