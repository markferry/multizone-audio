---
title: README
---

A config generator for a multizone audio system based on snapcast, Mopidy and MQTT.

# Objectives

- [ ] seamless SpotifyConnect, Airplay, Mopidy/MPD/UPNP and Kodi playback in each zone
- [ ] invisible, automatic party reconfiguration
- [x] no clashing audio streams
- [ ] no snapcast controls visible to end-users(!)
- [x] eliminate unnecessary software volume controls
- [x] replaygain support

# Architecture

Almost all media services run on a central media server.

Each media player is its own zone and there are also multiple (logical) "party zones" which group the real zones together.
For more on logical zones see the [snapcast-autoconfig README](https://github.com/ahayworth/snapcast-autoconfig)

## Media Server

The media server runs:

 * one mopidy instance per zone (providing mpd + iris)
 * snapserver
 * [snapcast-autoconfig](https://github.com/ahayworth/snapcast-autoconfig)
 * [mosquitto mqtt broker](https://mosquitto.org/)

Snapserver is configured with:

 * *per-zone* mopidy, shairport-sync and librespot streams
 * per-zone master [meta streams](https://github.com/badaix/snapcast/blob/master/doc/configuration.md#meta)

The snapserver itself runs and manages the `librespot` and `shairport-sync` media services.

snapcast-autoconfig manages the snapcast groups (including, for the benefit of Iris, naming them!).

### Hardware
* USB audio capture device with S/PDIF input - [Startech ICUSBAUDIO7D ~£28 at Amazon UK](https://www.amazon.co.uk/dp/B002LM0U2S)

### Software

* Debian 10+ "Buster"
* snapserver v0.25+
* [librespot](https://github.com/librespot-org/librespot)  (*TODO:* replace with [librespot-java](https://github.com/librespot-org/librespot-java))
* shairport-sync
    * 3.3.8-OpenSSL-Avahi-ALSA-stdout-pipe-soxr-metadata-mqtt-sysconfdir:/etc
    * built with mqtt:  `./configure --sysconfdir=/etc --with-alsa --with-soxr --with-stdout --with-mqtt-client --with-metadata --with-avahi --with-ssl=openssl --with-pipe --with-systemd`
* Mopidy
    * Mopidy             3.2.0
    * Mopidy-Iris        3.59.1
    * Mopidy-Local       3.2.1
    * Mopidy-MPD         3.2.0
    * Mopidy-MQTT-NG     1.0.0
    * Mopidy-Spotify     4.1.1
    * Mopidy-TuneIn      1.1.0
* mosquitto MQTT broker

## Media Players

Each media player runs:

 * snapclient
 * nginx, proxying `http://<hostname>/` to `http://<media-server>:66xx/iris`
 * kodi, if-and-only-if the player has a screen or projector attached

While snapcast meta streams are neat for auto-switching between audio services it's
still confusing when, say, both a spotify and airplay stream attempt to play to
the same zone. Instead, when one service starts playing we want the others (in the same zone) to pause.

To accomplish this each media service (mopidy, librespot, ...) is configured to
notify via MQTT when playback starts.

See:

 * [mopidy-mqtt-ng](https://github.com/odiroot/mopidy-mqtt)
 * [shairport-sync MQTT support](https://github.com/mikebrady/shairport-sync/blob/master/MQTT.md)
 * `librespot --onevent librespot-event.sh...`
 * [kodi2mqtt](https://github.com/void-spark/kodi2mqtt)

Each media service (except librespot) can also be *controlled* via MQTT.

The idea for this came from
[hifiberry](https://github.com/hifiberry/audiocontrol2)
which implements control of concurrent playback streams via
[MPRIS](https://www.freedesktop.org/wiki/Specifications/mpris-spec/).


### Hardware
* RPi1 / RPi2 / RPi3
* Generic USB stereo sound card - [UGREEN USB external sound card](https://www.ugreen.com/products/usb-external-stereo-sound-card)

### Software

* snapclient v0.25+
* nginx
* dietpi
* OSMC / Kodi v19
* [kodi2mqtt](https://github.com/void-spark/kodi2mqtt)
  * Kodi v19 required for current kodi2mqtt v21 (or use the [python2.7 patch by tspspi](https://github.com/tspspi/kodi2mqtt/commit/e7df9fa70284f0e905728c33c4b243bec92073e8))


## Controller

The pausing of media streams is done by a simple MQTT service - though it could
be implemented as:

 * an extension to [hifiberry's audiocontrol2](https://github.com/hifiberry/audiocontrol2),
 * a [HomeAssistant automation](https://www.home-assistant.io/integrations/mqtt/).

Using `librespot-java` instead of `librespot` the controller could control
specific SpotifyConnect players, making snapcast meta streams unnecessary.

## Volume Control

For end-users, only (per-service) soft-volume control is available.

Hardware volume levels are preset by snapcast-autoconfig.

Each snapclient is configured to [use an alsa hardware mixer](https://github.com/badaix/snapcast/commit/3ed76e20596b18baa14c04b3ec09c8f232f8e023) (if available).

### librespot and shairport-sync controlling a snapserver
While `librespot` and `shairport-sync` can both be configured to control a
hardware mixer the snapserver can't be, nor does it create a virtual mixer.


# Usage

## Prerequisites
These requirements are sufficient to customize the configurations for your setup:

* GNU make
* python3
* [chevron](https://pypi.org/project/chevron/)

`chevron` is a python implementation of the [mustache templating language](http://mustache.github.io/).

On first run if `chevron` isn't found, `make` will create a python virtual environment and install it for you.

The services are configured by generating systemd service files. Many of them are
[template unit files](https://fedoramagazine.org/systemd-template-unit-files/)
so that multiple instances can be started on a single host. (e.g. `systemctl start mopidy@study`) 

## Customize

Configurations for each zone (and for all zones) are generated by merging the
`json` data into the template files using `chevron`.

**[`players.json`](players.json)**: used to generate all-zone config files (like `snapserver.conf`).

**`$zone.json`**: used to generate per-zone config files (e.g. `mopidy.study.conf`).

You will need to adapt my existing json zone files and `players.json` for your purposes.
See also `ALL_HOSTS` in the [`Makefile`](Makefile).

## Generate

| :warning: This will overwrite `../snapserver.conf` |
|--------|

```bash
make
```



## Test

All the services (except for `nginx`) can be run and tested locally as an unprivileged user.

To install and run mopidy in a python venv you will need:
* [libspotify-dev](https://mopidy.github.io/libspotify-archive/)

```bash
sudo apt-get install libspotify-dev
.venv/bin/pip install -r requirements.txt
```

Generate configs and start all services:

```bash
make dev
make dev-install  # this will overwrite files in ~/.config/systemd/user!
# set `SYSTEMCTL_USER := --user` in the Makefile
make start
```

To start the services for just one zone:

```bash
# study only
make HOST=study start-host
```

## Deploy

### Server
Requirements: see [#software](#software).

| :warning: This will overwrite `/etc/snapserver.conf` |
|--------|

On your production system, as root:

``` bash
git clone https://github.com/markferry/multizone-audio.git /etc/multizone-audio
cd /etc/multizone-audio
git checkout $your_branch   # your customizations
make live-install
```

# Resources
## People to follow
* [@badaix](https://github.com/badaix) - snapcast maintainer
* [@kingosticks](https://github.com/kingosticks) - pimusicbox developer
* [@frafall](https://github.com/frafall/) - snapcast metadata contributor and kodi snapcast service developer
* [@ahayworth](https://github.com/ahayworth) - snapcast-autoconfig maintainer

## Projects
* [skalavala multi-room audio](https://github.com/skalavala/Multi-Room-Audio-Centralized-Audio-for-Home) - multi-zone but single-stream
* [spocon](https://github.com/spocon/spocon) - librespot-java packaged for Debian
