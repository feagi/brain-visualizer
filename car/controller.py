#!/usr/bin/env python
"""
Copyright 2016-2023 The FEAGI Authors. All Rights Reserved.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================
"""

import asyncio
import threading
from collections import deque
from datetime import datetime
from time import sleep
import requests
import websockets
from configuration import *
from feagi_agent import feagi_interface as feagi

ws = deque()
old_data = 0


async def echo(websocket):
    """
    The function echoes the data it receives from other connected websockets
    and sends the data from FEAGI to the connected websockets.
    """
    async for message in websocket:
        global old_data
        try:
            if old_data != message:
                print("message: ", message)
                old_data = message
            if len(ws) > 2:  # This will eliminate any stack up queue
                stored_value = ws[len(ws) - 1]
                ws.clear()
                ws[0] = stored_value
            await websocket.send(str(ws[0]))
            ws.pop()
        except Exception as error:
            pass
            # print("error: ", error)


async def main():
    """
    The main function handles the websocket and spins the asyncio to run the echo function
    infinitely until it exits. Once it exits, the function will resume to the next new websocket.
    """
    async with websockets.serve(echo, agent_settings["godot_websocket_ip"],
                                agent_settings['godot_websocket_port']):
        await asyncio.Future()  # run forever


def websocket_operation():
    """
    WebSocket initialized to call the echo function using asyncio.
    """
    asyncio.run(main())


if __name__ == "__main__":
    previous_data_frame = {}
    runtime_data = {"cortical_data": {}, "current_burst_id": None,
                    "stimulation_period": None, "feagi_state": None,
                    "feagi_network": None}

    # FEAGI section start
    print("Connecting to FEAGI resources...")

    feagi_host, api_port, app_data_port = \
        feagi.feagi_setting_for_registration(feagi_settings, agent_settings)

    print(feagi_host, api_port, app_data_port)

    # address = 'tcp://' + network_settings['feagi_host'] + ':' + network_settings['feagi_opu_port']

    api_address = 'http://' + feagi_host + ':' + api_port

    stimulation_period_endpoint = feagi.feagi_api_burst_engine()
    burst_counter_endpoint = feagi.feagi_api_burst_counter()
    print("^ ^ ^")
    runtime_data["feagi_state"] = feagi.feagi_registration(feagi_host=feagi_host,
                                                           api_port=api_port,
                                                           agent_settings=agent_settings,
                                                           capabilities=capabilities)

    print("** **", runtime_data["feagi_state"])
    feagi_settings['feagi_burst_speed'] = float(runtime_data["feagi_state"]['burst_duration'])

    # ipu_channel_address = feagi.feagi_inbound(agent_settings["agent_data_port"])
    ipu_channel_address = feagi.feagi_outbound(feagi_settings['feagi_host'],
                                               agent_settings["agent_data_port"])
    print("IPU_channel_address=", ipu_channel_address)
    opu_channel_address = feagi.feagi_outbound(feagi_settings['feagi_host'],
                                               runtime_data["feagi_state"]['feagi_opu_port'])
    feagi_ipu_channel = feagi.pub_initializer(ipu_channel_address, bind=False)
    feagi_opu_channel = feagi.sub_initializer(opu_address=opu_channel_address)

    msg_counter = runtime_data["feagi_state"]['burst_counter']
    CHECKPOINT_TOTAL = 5
    FLAG_COUNTER = 0

    BGSK = threading.Thread(target=websocket_operation, daemon=True).start()
    FLAG = True
    while True:
        WS_STRING = {}
        message_from_feagi = feagi_opu_channel.receive()  # Get data from FEAGI
        # OPU section STARTS
        if message_from_feagi is not None:
            opu_data = feagi.opu_processor(message_from_feagi)
            if 'motor' in opu_data:
                WS_STRING['motor'] = {}
                for data_point in opu_data['motor']:
                    WS_STRING['motor'][str(data_point)] = opu_data['motor'][data_point] - 5
            if 'misc' in opu_data:
                WS_STRING['misc'] = {}
                for data_point in opu_data['misc']:
                    WS_STRING['misc'][str(data_point)] = opu_data['misc'][data_point] - 1
            if WS_STRING:
                ws.append(WS_STRING)

        # OPU section ENDS

        message_to_feagi['timestamp'] = datetime.now()
        message_to_feagi['counter'] = msg_counter
        msg_counter += 1
        FLAG_COUNTER += 1
        if FLAG_COUNTER == int(CHECKPOINT_TOTAL):
            feagi_burst_speed = requests.get(api_address + stimulation_period_endpoint,
                                             timeout=5).json()
            feagi_burst_counter = requests.get(api_address + burst_counter_endpoint,
                                               timeout=5).json()
            FLAG_COUNTER = 0
            if feagi_burst_speed > 1:
                CHECKPOINT_TOTAL = 5
            if feagi_burst_speed < 1:
                CHECKPOINT_TOTAL = 5 / feagi_burst_speed
            if msg_counter < feagi_burst_counter:
                feagi_opu_channel = feagi.sub_initializer(opu_address=opu_channel_address)
                if feagi_burst_speed != feagi_settings['feagi_burst_speed']:
                    feagi_settings['feagi_burst_speed'] = feagi_burst_speed
            if feagi_burst_speed != feagi_settings['feagi_burst_speed']:
                feagi_settings['feagi_burst_speed'] = feagi_burst_speed
                msg_counter = feagi_burst_counter
        sleep(feagi_settings['feagi_burst_speed'])
        try:
            pass
            # print(len(message_to_feagi['data']['sensory_data']['camera']['C']))
        except Exception as ERROR:
            pass
        feagi_ipu_channel.send(message_to_feagi)
        message_to_feagi.clear()
