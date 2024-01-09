import traceback
from feagi_agent.version import __version__
from time import sleep
import requests
import socket
import zmq

def app_host_info():
    host_name = socket.gethostname()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0)
    try:
        s.connect(('10.254.254.254', 1))
        ip_address = s.getsockname()[0]
    except Exception:
        ip_address = '127.0.0.1'
    finally:
        s.close()
    return {"ip_address": ip_address, "host_name": host_name}


def is_FEAGI_reachable(server_host, server_port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        sock.connect((server_host, server_port))
        return True
    except Exception as e:
        return False


def feagi_registration(feagi_auth_url, feagi_settings, agent_settings, capabilities,
                       controller_version):
    host_info = app_host_info()
    runtime_data = {
        "host_network": {},
        "feagi_state": None
    }
    runtime_data["host_network"]["host_name"] = host_info["host_name"]
    runtime_data["host_network"]["ip_address"] = host_info["ip_address"]
    agent_settings['agent_ip'] = host_info["ip_address"]

    while runtime_data["feagi_state"] is None:
        print("\nAwaiting registration with FEAGI...")
        try:
            runtime_data["feagi_state"] = \
                register_with_feagi(feagi_auth_url, feagi_settings, agent_settings,
                                           capabilities, controller_version, __version__)
        except Exception as e:
            print("ERROR__: ", e, traceback.print_exc())
            pass
        sleep(1)
    print("\nversion: ", controller_version, "\n")
    print("\nagent version: ", __version__, "\n")
    return runtime_data["feagi_state"]


def feagi_setting_for_registration(feagi_settings, agent_settings):
    """
    Generate all needed information and return the full data to make it easier to connect with
    FEAGI
    """
    feagi_ip_host = feagi_settings["feagi_host"]
    api_port = feagi_settings["feagi_api_port"]
    app_data_port = agent_settings["agent_data_port"]
    return feagi_ip_host, api_port, app_data_port


def feagi_outbound(feagi_ip_host, feagi_opu_port):
    """
    Return the zmq address of outbound
    """
    return 'tcp://' + feagi_ip_host + ':' + \
           feagi_opu_port


def pub_initializer(ipu_address, bind=True):
    return Pub(address=ipu_address, bind=bind)


def sub_initializer(opu_address, flags=zmq.NOBLOCK):
    return Sub(address=opu_address, flags=flags)


class PubSub:
    def __init__(self, flags=None):
        self.context = zmq.Context()
        self.flags = flags

    def send(self, message):
        self.socket.send_pyobj(message)

    def receive(self):
        try:
            payload = self.socket.recv_pyobj(flags=self.flags)
            return payload
        except zmq.ZMQError as e:
            if e.errno == zmq.EAGAIN:
                pass
            else:
                print(e)

    def terminate(self):
        self.socket.close()

    def destroy(self):
        self.context.destroy()


class Pub(PubSub):

    def __init__(self, address, bind=True, flags=None):
        PubSub.__init__(self, flags)
        print(f"Pub -|- Add - {address}, Bind - {bind}")
        self.socket = self.context.socket(zmq.PUB)
        self.socket.setsockopt(zmq.SNDHWM, 0)
        if bind:
            self.socket.bind(address)
        else:
            self.socket.connect(address)


class Sub(PubSub):

    def __init__(self, address, bind=False, flags=None):
        PubSub.__init__(self)
        print(f"Sub -- Add - {address}, Bind - {bind}")
        self.flags = flags
        self.socket = self.context.socket(zmq.SUB)
        self.socket.setsockopt(zmq.SUBSCRIBE, ''.encode('utf-8'))
        self.socket.setsockopt(zmq.CONFLATE, 1)
        if bind:
            self.socket.bind(address)
        else:
            self.socket.connect(address)

def feagi_settings_from_composer(feagi_auth_url, feagi_settings):
    """
    Generate all needed information and return the full data to make it easier to connect with
    FEAGI
    """
    if feagi_auth_url is not None:
        print(f"Updating feagi settings using feagi_auth_url: {feagi_auth_url}")
        new_settings = requests.get(feagi_auth_url).json()
        # update feagi settings here
        feagi_settings['feagi_dns'] = new_settings['feagi_dns']
        feagi_settings['feagi_host'] = new_settings['feagi_host']
        feagi_settings['feagi_api_port'] = new_settings['feagi_api_port']
        print(f"New Settings ---- {new_settings}")
    else:
        print(f"Missing feagi_auth_url, using default feagi settings")

    if feagi_settings.get('feagi_dns') is not None:
        feagi_settings['feagi_url'] = feagi_settings['feagi_dns']
    else:
        feagi_settings[
            'feagi_url'] = f"http://{feagi_settings['feagi_host']}:{feagi_settings['feagi_api_port']}"
    return feagi_settings

def register_with_feagi(feagi_auth_url, feagi_settings, agent_settings, agent_capabilities,
                        controller_version, agent_version):
    """
    To trade information between FEAGI and Controller

    Controller                      <--     FEAGI(IPU/OPU socket info)
    Controller (Capabilities)       -->     FEAGI
    """
    network_endpoint = '/v1/feagi/feagi/network'
    stimulation_period_endpoint = '/v1/feagi/feagi/burst_engine/stimulation_period'
    burst_counter_endpoint = '/v1/feagi/feagi/burst_engine/burst_counter'
    registration_endpoint = '/v1/agent/register'

    registration_complete = False
    while not registration_complete:
        try:
            print(f"Original Feagi Settings ---- {feagi_settings}")
            feagi_settings = feagi_settings_from_composer(feagi_auth_url, feagi_settings)
            feagi_url = feagi_settings['feagi_url']

            network_output = requests.get(feagi_url + network_endpoint).json()
            # print(f"network_output ---- {network_output}")
            feagi_settings['feagi_opu_port'] = network_output['feagi_opu_port']
            if feagi_settings:
                print("Data from FEAGI::", feagi_settings)
            else:
                print("No feagi settings!")

            agent_registration_data = dict()
            agent_registration_data["agent_type"] = str(agent_settings['agent_type'])
            agent_registration_data["agent_id"] = str(agent_settings['agent_id'])
            agent_registration_data["agent_ip"] = str(agent_settings['agent_ip'])
            agent_registration_data["agent_data_port"] = int(agent_settings['agent_data_port'])
            agent_registration_data["controller_version"] = str(controller_version)
            agent_registration_data["agent_version"] = str(agent_version)

            response = requests.post(feagi_url + registration_endpoint,
                                     params=agent_registration_data)
            if response.status_code == 200:
                feagi_settings['agent_state'] = response.json()
                print("Agent successfully registered with FEAGI!")
                # Receive FEAGI settings
                feagi_settings['burst_duration'] = requests.get(
                    feagi_url + stimulation_period_endpoint).json()
                feagi_settings['burst_counter'] = requests.get(
                    feagi_url + burst_counter_endpoint).json()

                if feagi_settings and feagi_settings['burst_duration'] and feagi_settings[
                    'burst_counter']:
                    print("\n\n\n\nRegistration is complete....")
                    registration_complete = True
        except Exception as e:
            print("Registeration failed with FEAGI: ", e)
            # traceback.print_exc()
        sleep(2)

    print(f"Final Feagi Settings ---- {feagi_settings}")
    feagi_ip = feagi_settings['feagi_host']
    agent_data_port = feagi_settings['agent_state']['agent_data_port']
    print("feagi_ip:agent_data_port", feagi_ip, agent_data_port)
    # Transmit Controller Capabilities
    # address, bind = f"tcp://*:{agent_data_port}", True
    address, bind = f"tcp://{feagi_ip}:{agent_data_port}", False

    publisher = Pub(address, bind)
    publisher.send(agent_capabilities)

    return feagi_settings
