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
	
	#TODO: Double check this carefully in NRS WHOOPS
	var websocket_port: int = fallback_details.websocket_port
	var websocket_address: StringName = fallback_details.websocket_tld
	var http_port: int =  fallback_details.API_port
	var address_API: StringName = fallback_details.API_tld
	var is_encrypted: bool = fallback_details.is_encrypted
	
	
	var tld_result = JavaScriptBridge.eval(""" 
		function getIPAddress() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("ip_address");
			return ipAddress;
		}
		getIPAddress();
		""")
	var is_using_standard_port = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("port_disabled");
			return ipAddress;
		}
		get_port();
		""")
	var websocket_tld = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("websocket_url");
			return ipAddress;
		}
		get_port();
		""")
	var http_type_str = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("http_type");
			return ipAddress;
		}
		get_port();
		""")
	
	if websocket_tld != null:
		websocket_address = websocket_tld
	if http_type_str != null:
		is_encrypted = str(http_type_str).to_lower() == "https://"
	if tld_result != null:
		address_API = tld_result
	if is_using_standard_port != null:
		if str(is_using_standard_port).to_lower() == "true":
			if is_encrypted:
				http_port = 443
				websocket_port = 443
			else:
				http_port = 80
				websocket_port = 80
	
	address_API = "127.0.0.1:8000"
	websocket_address = "ws://127.0.0.1:9050"
	
	var address_arr: PackedStringArray = address_API.rsplit(":", true, 1)
	var websocket_arr: PackedStringArray = websocket_address.rsplit(":", true, 1)
	
	if address_API.contains(":"):
		http_port = (address_arr[1]).to_int()
		address_API = address_arr[0]
	if websocket_address.contains(":"):
		websocket_port = websocket_arr[1].to_int()
		websocket_address = websocket_arr[0]
		
	var output: FeagiEndpointDetails = FeagiEndpointDetails.create_from(address_API, http_port, websocket_address, websocket_port, is_encrypted)
	print("The retrieved connection details following javascript data gathering:\nhttp_address: %s\nhttp_port: %d\nwebsocket_address: %s\nwebsocket_port: %d\nis_encrypted: %s\n" % [address_API, http_port, websocket_address, websocket_port, is_encrypted])
	return output
