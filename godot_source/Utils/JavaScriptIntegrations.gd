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
class_name JavaScriptIntegrations
## Static functions for getting data from javascript on the page, if this project is web exported

## Try to get the connection details from feagi to the webpage. Start with fallback details, and overwrite with any retrieved variabled
static func overwrite_with_details_from_address_bar(fallback_details: FeagiEndpointDetails) -> FeagiEndpointDetails:

	var backup_http_full_address: StringName = fallback_details.full_http_address
	var backup_websocket_full_address: StringName = fallback_details.full_websocket_address
	
	#TODO instead of of using below constants, parse from above
	
	var websocket_port: int = 9050
	var http_port: int =  8000
	var feagi_web_port: int
	var feagi_socket_port: int
	var feagi_TLD: StringName
	var feagi_SSL: StringName
	var feagi_socket_SSL: StringName = "ws://"  # Initialize WebSocket protocol prefix
	var feagi_root_web_address: StringName
	var feagi_root_websocket_address: StringName
	var feagi_socket_address: StringName
	var DEF_FEAGI_TLD: StringName = "127.0.0.1" # Default localhost
	var DEF_FEAGI_SSL: StringName = "http://" # Default localhost
	
	
	var ip_address_to_connect = JavaScriptBridge.eval(""" 
		function getIPAddress() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("ip_address");
			return ipAddress;
		}
		getIPAddress();
		""")
	var without_port = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("port_disabled");
			return ipAddress;
		}
		get_port();
		""")
	var full_dns_of_websocket = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("websocket_url");
			return ipAddress;
		}
		get_port();
		""")
	var SSL_type = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("http_type");
			return ipAddress;
		}
		get_port();
		""")
	
	var theme_setting = JavaScriptBridge.eval(""" 
		function get_theme() {
			var url_string = window.location.href;
			var url = new URL(window.location.href);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("theme_setting");
			return ipAddress;
		}
		get_theme();
		""")
	
	var advanced_setting = JavaScriptBridge.eval(""" 
		function get_advanced_mode() {
			var url_string = window.location.href;
			var url = new URL(window.location.href);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("is_advanced_mode");
			return ipAddress;
		}
		get_advanced_mode();
		""")
	
	feagi_web_port = http_port
	feagi_socket_port = websocket_port
	if SSL_type != null:
		feagi_SSL = SSL_type
	else:
		feagi_SSL= DEF_FEAGI_SSL
	if ip_address_to_connect != null:
		feagi_TLD = ip_address_to_connect
	else:
		feagi_TLD = DEF_FEAGI_TLD
	if without_port != null:
		if without_port.to_lower() == "true":
			feagi_root_web_address = feagi_SSL + feagi_TLD
		else:
				feagi_root_web_address = feagi_SSL + feagi_TLD + ":" + str(feagi_web_port)
	else:
		feagi_root_web_address = feagi_SSL + feagi_TLD + ":" + str(feagi_web_port)
		# init WebSocket
	if full_dns_of_websocket != null:
		feagi_socket_address = full_dns_of_websocket
	else:
		feagi_socket_address = feagi_socket_SSL + feagi_TLD + ":" + str(feagi_socket_port)
		
	print("websocket: ", feagi_socket_address, " and api: ", feagi_root_web_address)
		
	var output: FeagiEndpointDetails = FeagiEndpointDetails.create_from(feagi_root_web_address, feagi_socket_address)
	if advanced_setting != null:
		output.is_advanced_mode = advanced_setting == "true"
	if theme_setting != null:
		output.theme_string = theme_setting
	
	
	return output

## Get URL parameter value (web builds only)
static func get_url_parameter(param_name: String) -> String:
	"""Get URL parameter value from current page"""
	if not OS.has_feature("web"):
		return ""
	
	var value = JavaScriptBridge.eval("""
		(function() {
			var url = new URL(window.location.href);
			return url.searchParams.get('%s') || null;
		})();
	""" % param_name)
	
	return String(value) if value != null else ""

## Load file via HTTP fetch (for auto-detection in same directory)
## Triggers async load - use poll_file_load_result() to get result
static func load_file_via_http(filename: String) -> void:
	"""Trigger async file load from same directory via HTTP fetch"""
	if not OS.has_feature("web"):
		return
	
	# Use a Promise-based approach and store result in window
	JavaScriptBridge.eval("""
		window.__feagi_file_load_ready = false;
		window.__feagi_file_load_contents = null;
		(async function() {
			try {
				var base = window.location.origin + window.location.pathname.replace(/[^/]*$/, '');
				var url = base + '%s';
				var response = await fetch(url);
				if (response.ok) {
					var text = await response.text();
					window.__feagi_file_load_contents = text;
					window.__feagi_file_load_ready = true;
				} else {
					window.__feagi_file_load_contents = '';
					window.__feagi_file_load_ready = true;
				}
			} catch (e) {
				window.__feagi_file_load_contents = '';
				window.__feagi_file_load_ready = true;
			}
		})();
	""" % filename)

## Poll for file load result (call after load_file_via_http)
static func poll_file_load_result() -> String:
	"""Check if file load has a result ready"""
	if not OS.has_feature("web"):
		return ""
	
	var ready = JavaScriptBridge.eval("window.__feagi_file_load_ready || false")
	if ready:
		var contents = JavaScriptBridge.eval("window.__feagi_file_load_contents || ''")
		JavaScriptBridge.eval("window.__feagi_file_load_ready = false; window.__feagi_file_load_contents = null;")
		return String(contents) if contents != null and contents != "" else ""
	
	return ""

## Load file via HTML5 File API (deprecated - use load_file_via_http + poll_file_load_result)
## This function is kept for compatibility but should not be used
static func load_file_via_file_api(_filename: String) -> String:
	"""Deprecated - use load_file_via_http() + poll_file_load_result() async pattern instead"""
	push_warning("load_file_via_file_api() is deprecated - use async pattern instead")
	return ""

## Show HTML5 file picker for genome loading
## Stores result in window.__feagi_picked_file_contents for polling
static func show_file_picker_for_genome(_target_object: Object, _callback_method: String) -> void:
	"""Show HTML5 file picker - result available via poll_file_picker_result()"""
	if not OS.has_feature("web"):
		push_error("File picker only available on web builds")
		return
	
	JavaScriptBridge.eval("""
		(function() {
			window.__feagi_file_picker_ready = false;
			window.__feagi_file_picker_contents = null;
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json';
			input.onchange = function(e) {
				var file = e.target.files[0];
				if (file) {
					var reader = new FileReader();
					reader.onload = function(e) {
						window.__feagi_file_picker_contents = e.target.result;
						window.__feagi_file_picker_ready = true;
					};
					reader.readAsText(file);
				} else {
					window.__feagi_file_picker_ready = true;
					window.__feagi_file_picker_contents = null;
				}
			};
			input.click();
		})();
	""")

## Poll for file picker result (call after show_file_picker_for_genome)
static func poll_file_picker_result() -> String:
	"""Check if file picker has a result ready"""
	if not OS.has_feature("web"):
		return ""
	
	var ready = JavaScriptBridge.eval("window.__feagi_file_picker_ready || false")
	if ready:
		var contents = JavaScriptBridge.eval("window.__feagi_file_picker_contents || ''")
		JavaScriptBridge.eval("window.__feagi_file_picker_ready = false; window.__feagi_file_picker_contents = null;")
		return String(contents) if contents != null else ""
	
	return ""
