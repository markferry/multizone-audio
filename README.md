# Objectives

 * seamless SpotifyConnect, Airplay, Mopidy/MPD/UPNP and Kodi playback in each zone
 * invisible, automatic party reconfiguration
 * no clashing audio streams
 * no snapcast controls visible to end-users(!)
 * eliminate unnecessary software volume controls

# Architecture

Almost all media services run on a central media server.

Each media player is its own zone and there are also multiple (logical) "party zones" which group the real zones together.
For more on logical zones see the [snapcast-autoconfig README](https://github.com/ahayworth/snapcast-autoconfig)

## Media Server

The media server runs:

 * one mopidy instance per zone (providing mpd + upnp + iris)
 * snapserver
 * [snapcast-autoconfig](https://github.com/ahayworth/snapcast-autoconfig)
 * [mosquitto mqtt broker](https://mosquitto.org/)

Snapserver is configured with:

 * *per-zone* mopidy, shairport-sync and librespot streams
 * per-zone master [meta streams](https://github.com/badaix/snapcast/blob/master/doc/configuration.md#meta)

The snapserver itself runs and manages the `librespot` and `shairport-sync` media services.

snapcast-autoconfig manages the snapcast groups (including, for the benefit of Iris, naming them!).

### Hardware
* USB audio device

### Software

* Debian 10+ "Buster"
* snapserver v0.25+
* Librespot
* shairport-sync
    * 3.3.8-OpenSSL-Avahi-ALSA-stdout-pipe-soxr-metadata-mqtt-sysconfdir:/etc
    * build with mqtt  `./configure --sysconfdir=/etc --with-alsa --with-soxr --with-stdout --with-mqtt-client --with-metadata --with-avahi --with-ssl=openssl --with-pipe --with-systemd`
* Mopidy
    * Mopidy         3.2.0
    * Mopidy-Iris    3.58.0
    * Mopidy-Local   3.1.1
    * Mopidy-MPD     3.1.0
    * Mopidy-MQTT-NG 1.0.0
    * Mopidy-Spotify 4.1.1
    * Mopidy-TuneIn  1.1.0
* mosquitto MQTT broker

## Media Players

Each media player runs:

 * snapclient
 * nginx, proxying `http://<hostname>/` to `http://<media-server>:668x/iris`
 * kodi, if-and-only-if they have a screen or projector attached (I think I'll disable Kodi's web interface too...)

While snapcast meta streams are neat for auto-switching between audio services it's
still confusing when, say, both a spotify and airplay stream attempt to play to
the same zone. Instead when one service starts playing we want the others (in the same zone) to pause.

To accomplish this each media service (mopidy, librespot, ...) is configured to
notify via MQTT when playback starts.

See:

 * [mopidy-mqtt-ng](https://github.com/odiroot/mopidy-mqtt)
 * [shairport-sync MQTT support](https://github.com/mikebrady/shairport-sync/blob/master/MQTT.md)
 * `librespot --onevent mosquitto_pub.sh ...`
 * [kodi2mqtt](https://github.com/void-spark/kodi2mqtt)

Each media service (except librespot) can also be *controlled* via MQTT.

The idea for this came from
[hifiberry](https://github.com/hifiberry/audiocontrol2)
which implements control of concurrent playback streams via
[MPRIS](https://www.freedesktop.org/wiki/Specifications/mpris-spec/).


### Hardware
* RPi1 / RPi2 / RPi3
* USB audio device

### Software

* snapclient v0.25+
* nginx
* Moode, Volumio
* OSMC / Kodi v19
  * v19 required for current kodi2mqtt v21
* kodi2mqtt


### ALSA configuration

USB device: card 5

## Stream Control

The actual pausing of media streams will be done by an MQTT service - which could
either be implemented as an extension to
[hifiberry's audiocontrol2](https://github.com/hifiberry/audiocontrol2),
a [standalone service](https://www.emqx.com/en/blog/how-to-use-mqtt-in-python)
or [HA automations](https://www.home-assistant.io/integrations/mqtt/).

And if I can get local control of SpotifyConnect players, (perhaps using
[librespot-java](https://github.com/librespot-org/librespot-java)) then I can
even do away the snapcast meta streams altogether and just have the last played
streams being the one that has priority.

## Volume Control

For end-users, only (per-service) soft-volume control is available.

Hardware volume levels are preset by snapcast-autoconfig.

Each snapclient is configured to [use an alsa hardware mixer](https://github.com/badaix/snapcast/commit/3ed76e20596b18baa14c04b3ec09c8f232f8e023) (if available).

### librespot and shairport-sync controlling a snapserver
While `librespot` and `shairport-sync` can both be configured to control a
hardware mixer the snapserver can't be, nor does it create a virtual mixer.


## Issues

1. snapcast-autoconfigure: [When clients are in an Idle group and one client's preferred stream starts, all clients play it](https://github.com/ahayworth/snapcast-autoconfig/issues/4)
2. it's possible to see *which* streams are playing, but not *what* they're playing. snapcast metadata is a [work-in-progress](https://github.com/badaix/snapcast/issues/803)
3. there is no good UI for both multizone stream state *and* playlist management


# Resources
## People to follow
* [@badaix](https://github.com/badaix) - snapcast maintainer
* [@kingosticks](https://github.com/kingosticks) - pimusicbox developer
* [@frafall](https://github.com/frafall/) - snapcast metadata contributor and kodi snapcast service developer
* [@ahayworth](https://github.com/ahayworth) - snapcast-autoconfig maintainer

