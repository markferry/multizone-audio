#!/bin/sh
mosquitto_pub -h localhost -t media/$1/spotify/status -m "$PLAYER_EVENT"
