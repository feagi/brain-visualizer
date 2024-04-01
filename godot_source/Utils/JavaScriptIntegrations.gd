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

## Try to get the connection details from feagi to the webpage
static func grab_feagi_endpoint_details() -> FeagiEndpointDetails:
	
	#TODO: This is very messy, we may need to clean up the javascript details and this to make it more clear whats going on
	#TODO: Double check this carefully in NRS
	var websocket_port: int = 9050
	var http_port: int =  8000
	
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
	var is_using_nonstandard_port = JavaScriptBridge.eval(""" 
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
	
	if http_type_str == null or tld_result == null or is_using_nonstandard_port == null or websocket_tld == null:
		# Something didnt return correctly. Return empty FeagiEndpointDetails
		return FeagiEndpointDetails.create_from("", 0, "", 0, false)
	
	
	var is_encrypted: bool = str(http_type_str).to_lower() == "https://"
	if str(is_using_nonstandard_port).to_lower() != "true":
		# We are using a standard port
		# In the case of standard ports, NRS sets up routing
		if is_encrypted:
			http_port = 443
			websocket_port = 443
		else:
			http_port = 80
			websocket_port = 80
	
	return FeagiEndpointDetails.create_from(str(tld_result), http_port, str(websocket_tld), websocket_port, is_encrypted)
