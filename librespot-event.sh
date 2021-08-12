#!/bin/sh
mosquitto_pub -h pixie3 -t media/$1/spotify/status -m "$PLAYER_EVENT"
