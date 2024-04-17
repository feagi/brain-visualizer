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

extends Resource
class_name FeagiEndpointDetails
## Describes the details of the FEAGI endpoint, used to intiiate a connection
# NOTE: DO NOT EDIT THIS FILE TO CHANGE DEFAULTS! Instead look in the Config folder

@export var header: PackedStringArray = ["Content-Type: application/json"] # this is likely constant, so define this
@export var API_tld: StringName
@export var API_port: int
@export var websocket_tld: StringName
@export var websocket_port: int
@export var is_encrypted: bool

static func create_from(address_API: StringName, port_web: int, address_websocket: StringName, port_websocket: int, is_using_encrypted: bool) -> FeagiEndpointDetails:
	var output: FeagiEndpointDetails = FeagiEndpointDetails.new()
	output.API_tld = address_API
	output.API_port = port_web
	output.websocket_tld = address_websocket
	output.websocket_port = port_websocket
	output.is_encrypted = is_using_encrypted
	return output
	

## Assemble the full API url for HTTP requests
func get_api_URL() -> StringName:
	if API_tld.contains("http"):
		return API_tld + ":" + str(API_port)
	if is_encrypted:
		return "https://" + API_tld + ":" + str(API_port)
	return "http://" + API_tld + ":" + str(API_port)

## Assemble the full Websocker URL
func get_websocket_URL() -> StringName:
	if websocket_tld.contains("ws"):
		return websocket_tld + ":" + str(websocket_port)
	if is_encrypted:
		return "wss://" + websocket_tld + ":" + str(websocket_port)
	return "ws://" + websocket_tld + ":" + str(websocket_port)

