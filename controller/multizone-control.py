#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (c) 2021 Mark Ferry <github@markferry.net>
#
# Derived from a paho example.
# Copyright (c) 2014 Roger Light <roger@atchoo.org>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Distribution License v1.0
# which accompanies this distribution.
#
# The Eclipse Distribution License is available at
#   http://www.eclipse.org/org/documents/edl-v10.php.
#
# Contributors:
#    Roger Light - initial implementation
# All rights reserved.

from collections import namedtuple

import json

import paho.mqtt.client as mqtt
import paho.mqtt.publish as publish

Message = namedtuple("Message", "topic payload")

MQTT_HOST = "pixie3"
TOPIC_ROOT = "media"

def parse_zone(topic):
    return topic.split('/')[1]

def on_mopidy_status(mosq, obj, msg):
    print("mopidy: " + msg.topic + " " + str(msg.qos) + " " + str(msg.payload))
    if msg.payload == b'playing':
        zone = parse_zone(msg.topic)
        msgs = [
            Message(f"{TOPIC_ROOT}/{zone}/airplay/remote", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/spotify/control", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/kodi/command/playbackstate", "pause"),
        ]
        for m in msgs:
            mosq.publish(m.topic, m.payload)


def on_spotify_status(mosq, obj, msg):
    print("spotify: " + msg.topic + " " + str(msg.qos) + " " + str(msg.payload))
    zone = parse_zone(msg.topic)
    msgs = [
        Message(f"{TOPIC_ROOT}/{zone}/mopidy/c/plb", "pause"),
        Message(f"{TOPIC_ROOT}/{zone}/airplay/remote", "pause"),
        Message(f"{TOPIC_ROOT}/{zone}/kodi/command/playbackstate", "pause"),
    ]
    for m in msgs:
        mosq.publish(m.topic, m.payload)

def on_airplay_status(mosq, obj, msg):
    print("airplay: " + msg.topic + " " + str(msg.qos) + " " + str(msg.payload))
    if msg.payload == b'playing':
        zone = parse_zone(msg.topic)
        msgs = [
            Message(f"{TOPIC_ROOT}/{zone}/mopidy/c/plb", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/spotify/control", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/kodi/command/playbackstate", "pause"),
        ]
        for m in msgs:
            mosq.publish(m.topic, m.payload)

def on_kodi_play(mosq, obj, msg):
    print("kodi: " + msg.topic + " " + str(msg.qos) + " " + str(msg.payload))
    zone = parse_zone(msg.topic)
    msgs = [
        Message(f"{TOPIC_ROOT}/{zone}/mopidy/c/plb", "pause"),
        Message(f"{TOPIC_ROOT}/{zone}/spotify/control", "pause"),
        Message(f"{TOPIC_ROOT}/{zone}/airplay/remote", "pause"),
    ]
    for m in msgs:
        mosq.publish(m.topic, m.payload)

# bluetooth will pause others but cannot itself be paused
def on_bluetooth_status(mosq, obj, msg):
    print("bluetooth: " + msg.topic + " " + str(msg.qos) + " " + str(msg.payload))
    if msg.payload == b'connected':
        zone = parse_zone(msg.topic)
        msgs = [
            Message(f"{TOPIC_ROOT}/{zone}/mopidy/c/plb", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/spotify/control", "pause"),
            Message(f"{TOPIC_ROOT}/{zone}/kodi/command/playbackstate", "pause"),
        ]
        for m in msgs:
            mosq.publish(m.topic, m.payload)

def on_message(mosq, obj, msg):
    print(msg.topic)


mqttc = mqtt.Client()

mqttc.message_callback_add(f"{TOPIC_ROOT}/+/mopidy/i/sta", on_mopidy_status)
mqttc.message_callback_add(f"{TOPIC_ROOT}/+/spotify/status", on_spotify_status)
mqttc.message_callback_add(f"{TOPIC_ROOT}/+/airplay/status", on_airplay_status)
mqttc.message_callback_add(f"{TOPIC_ROOT}/+/kodi/status/notification/Player.OnPlay", on_kodi_play)
mqttc.message_callback_add(f"{TOPIC_ROOT}/+/kodi/status/notification/Player.OnResume", on_kodi_play)
mqttc.message_callback_add(f"{TOPIC_ROOT}/+/bluetooth/status", on_bluetooth_status)
mqttc.on_message = on_message
mqttc.connect(MQTT_HOST, 1883, 60)
mqttc.subscribe(f"{TOPIC_ROOT}/#", 0)

mqttc.loop_forever()
