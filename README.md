A **config generator** for a multizone audio system based on snapcast, Mopidy and MQTT.

# Features

- [ ] support for common audio streaming protocols
  - [x] SpotifyConnect
    - [x] track transitions (crossfade and automix)
    - [ ] player controls
  - [x] Airplay
  - [x] Mopidy/MPD
  - [x] Kodi
  - [ ] Bluetooth
- [x] seamless switching between protocols in each zone
- [x] high-priority announcement streams (alarms, doorbells)
- [ ] invisible, automatic party reconfiguration
- [x] no clashing audio streams
- [ ] no snapcast controls visible to end-users(!)
- [x] eliminate unnecessary software volume controls
- [x] replaygain support

# Architecture

![Multi Zone Architecture](multizone-audio.svg)

Almost all media services run on a central media server.

Each media player is its own zone and there are also multiple (logical) "party zones" which group the real zones together.
For more on logical zones see the [snapcast-autoconfig README](https://github.com/ahayworth/snapcast-autoconfig)

## Media Server

The media server runs:

- one mopidy instance per zone (providing mpd + iris)
- snapserver
- mosquitto mqtt broker

Snapserver is configured with:

- _per-zone_ mopidy, shairport-sync and librespot streams
- per-zone master [meta streams](https://github.com/badaix/snapcast/blob/master/doc/configuration.md#meta)

The snapserver itself runs and manages the `librespot` and `shairport-sync` media services.

snapcast-autoconfig manages the snapcast groups (including, for the benefit of Iris, naming them!).

### Hardware

- USB audio capture device with S/PDIF input - [Startech ICUSBAUDIO7D ~£28 at Amazon UK](https://www.amazon.co.uk/dp/B002LM0U2S)

### Software

See [BUILDING](BUILDING.md) for notes on building some of these from sources.

- Debian 10+ "Buster"
- [snapserver v0.27+](https://github.com/badaix/snapcast)
- [librespot-java](https://github.com/librespot-org/librespot-java)
    - java
    - librespot-api-1.6.3.jar
    - default install dir is assumed to be `/opt/librespot`
- [shairport-sync](https://github.com/mikebrady/shairport-sync)
  - 3.3.8-OpenSSL-Avahi-ALSA-stdout-pipe-soxr-metadata-mqtt-sysconfdir:/etc
  - build with mqtt
- [Mopidy](https://github.com/mopidy/mopidy)
  - Mopidy 3.2.0
  - Mopidy-Iris 3.59.1
  - Mopidy-Local 3.2.1
  - Mopidy-MPD 3.2.0
  - Mopidy-MQTT-NG 1.0.0
  - [Mopidy-Spotify 5.0.0a2](https://github.com/mopidy/mopidy-spotify)
  - Mopidy-TuneIn 1.1.0
- [mosquitto MQTT broker](https://mosquitto.org/)
- [snapcast-autoconfig](https://github.com/ahayworth/snapcast-autoconfig)

## Media Players

Each media player runs:

- snapclient
- nginx, proxying `http://<hostname>/` to `http://<media-server>:66xx/iris`
- kodi, if-and-only-if the player has a screen or projector attached

While snapcast meta streams are neat for auto-switching between audio services it's
still confusing when, say, both a spotify and airplay stream attempt to play to
the same zone. Instead, when one service starts playing we want the others (in the same zone) to pause.

To accomplish this each media service (mopidy, librespot, ...) is configured to
notify via MQTT when playback starts.

See:

- [mopidy-mqtt-ng](https://github.com/odiroot/mopidy-mqtt)
- [shairport-sync MQTT support](https://github.com/mikebrady/shairport-sync/blob/master/MQTT.md)
- `librespot --onevent librespot-event.sh...`
- [kodi2mqtt](https://github.com/void-spark/kodi2mqtt)

Each media service (except librespot) can also be _controlled_ via MQTT.

The idea for this came from
[hifiberry](https://github.com/hifiberry/audiocontrol2)
which implements control of concurrent playback streams via
[MPRIS](https://www.freedesktop.org/wiki/Specifications/mpris-spec/).

### Hardware

- RPi1 / RPi2 / RPi3
- Generic USB stereo sound card - [UGREEN USB external sound card](https://www.ugreen.com/products/usb-external-stereo-sound-card)

### Software

- snapclient v0.25+
- nginx
- dietpi
- OSMC / Kodi v19+
- [kodi2mqtt](https://github.com/void-spark/kodi2mqtt)
  - install by manually extracting the zip in `~/.kodi/addons/` on the client
  - Kodi v20 "Nexus" requires [kodi2mqtt v0.22](https://github.com/void-spark/kodi2mqtt/releases/tag/v0.22)
  - Kodi v19 "Matrix" requires kodi2mqtt v0.21 (or use the [python2.7 patch by tspspi](https://github.com/tspspi/kodi2mqtt/commit/e7df9fa70284f0e905728c33c4b243bec92073e8))

## Controller

The pausing of media streams is done by a simple MQTT service - though it could
be implemented as:

- an extension to [hifiberry's audiocontrol2](https://github.com/hifiberry/audiocontrol2),
- a [HomeAssistant automation](https://www.home-assistant.io/integrations/mqtt/).


## Volume Control

For end-users only (per-service) soft-volume control is available.

Hardware volume levels are preset by snapcast-autoconfig.

Each snapclient is configured to [use an alsa hardware mixer](https://github.com/badaix/snapcast/commit/3ed76e20596b18baa14c04b3ec09c8f232f8e023) (if available).

### librespot and shairport-sync controlling a snapserver

While `librespot` and `shairport-sync` can both be configured to control a
hardware mixer the snapserver can't be, nor does it create a virtual mixer.

# Usage

## Prerequisites

These requirements are sufficient to customize the configurations for your setup:

- GNU make
- python3
- [chevron](https://pypi.org/project/chevron/)

`chevron` is a python implementation of the [mustache templating language](http://mustache.github.io/).

On first run if `chevron` isn't found, `make` will create a python virtual environment and install it for you.

The services are configured by generating systemd service files. Many of them are
[template unit files](https://fedoramagazine.org/systemd-template-unit-files/)
so that multiple instances can be started on a single host. (e.g. `systemctl start mopidy@study`)

## Customize

Configurations for each zone (and for all zones) are generated by merging the
`config.json` data into the template files using `chevron`.

You will need to adapt my existing json config for your purposes.
See also `ALL_HOSTS` in the [`Makefile`](Makefile).

## Generate

| :warning: This will overwrite `../snapserver.conf` |
| -------------------------------------------------- |

```bash
make
```

## Test

All the services (except for `nginx`) can be run and tested locally as an unprivileged user.

To install and run mopidy in a python venv you will need:

- [libspotify-dev](https://mopidy.github.io/libspotify-archive/)

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
| ---------------------------------------------------- |

On your production system, as root:

```bash
git clone https://github.com/markferry/multizone-audio.git /etc/multizone-audio
cd /etc/multizone-audio
git checkout $your_branch   # your customizations
make live-install
```

### Clients

For all client hosts:

```bash
git clone https://github.com/markferry/multizone-audio.git /etc/multizone-audio
cd /etc/multizone-audio
git checkout $your_branch   # your customizations
```

Then run the client-specific-install `make $os-$host-install`

Where `$os` is one of: `debian`, `dietpi`.

And `$host` is a host defined in `config.json`.

e.g.:
```bash
make dietpi-library-install
```


# Resources

## People to follow

- [@badaix](https://github.com/badaix) - snapcast maintainer
- [@kingosticks](https://github.com/kingosticks) - pimusicbox developer
- [@frafall](https://github.com/frafall/) - snapcast metadata contributor and kodi snapcast service developer
- [@ahayworth](https://github.com/ahayworth) - snapcast-autoconfig maintainer

## Projects

- [skalavala multi-room audio](https://github.com/skalavala/Multi-Room-Audio-Centralized-Audio-for-Home) - multi-zone but single-stream
- [spocon](https://github.com/spocon/spocon) - librespot-java packaged for Debian
