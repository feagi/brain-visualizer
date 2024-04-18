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
	var feagi_socket_SSL: StringName
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
	
	return output
