#!/bin/sh
mosquitto_pub -h localhost -t media/$1/spotify -m "$PLAYER_EVENT"
