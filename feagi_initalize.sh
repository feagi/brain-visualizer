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


python3 bridge_godot_python.py &
echo "% post-bridge launch"

cd ../html
live-server &

cd ../godot_source/

api_ip="$FEAGI_HOST"
api_port="$FEAGI_API_PORT"
websocket_ip="$GODOT_WEBSOCKET_HOST"
websocket_port="$GADOT_WEBSOCKET_PORT"

if [[ -n "$websocket_ip" ]]; then
  sed -i "s/var websocket_ip_address = \"127\.0\.0\.1\"/var websocket_ip_address = \"$websocket_ip\"/g" network_configuration.gd
fi

if [[ -n "$api_port" ]]; then
  sed -i "s/var api_port_address = \"8000\"/var api_port_address = \"$api_port\"/g" network_configuration.gd
fi

if [[ -n "$api_ip" ]]; then
  sed -i "s/var api_ip_address = \"127\.0\.0\.1\"/var api_ip_address = \"$api_ip\"/g" network_configuration.gd
fi

if [[ -n "$websocket_port" ]]; then
  sed -i "s/var websocket_port_address = \"9050\"/var websocket_port_address = \"$websocket_port\"/g" network_configuration.gd
fi


./Godot_v3.4.4-stable_linux_headless.64 --export "HTML5"

while true
  do
    :
  done