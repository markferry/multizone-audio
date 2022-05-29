# Build Notes for Components

## Debian Buster

### snapserver

Instructions: https://github.com/badaix/snapcast/blob/master/doc/build.md#linux-native

The Debian-packaged boost headers are too old.
[Download recent boost headers](https://www.boost.org/users/download/) (~90MB) and extract them.

```bash
sudo apt-get install libasound2-dev libpulse-dev libvorbisidec-dev libvorbis-dev libopus-dev libflac-dev libsoxr-dev alsa-utils libavahi-client-dev avahi-daemon libexpat1-dev
sudo apt-get cmake ninja-build

mkdir build && cd build
# Pass the path to extracted boost headers. Don't build snapclient.
cmake -G Ninja -DBUILD_CLIENT=OFF -DBOOST_ROOT=~/src/boost_1_79_0 ../
cmake --build .

sudo cmake --build . --target install
```

### shairport-sync

Instructions: https://github.com/mikebrady/shairport-sync#building-and-installing

The Debian-packaged version does not have MQTT support so we must build from source:

```bash
sudo apt-get install build-essential git xmltoman autoconf automake libtool libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev libmosquitto-dev

autoreconf -i -f
# enable mqtt
./configure --sysconfdir=/etc --with-alsa --with-soxr --with-stdout --with-mqtt-client --with-metadata --with-avahi --with-ssl=openssl --with-pipe --with-systemd
make

sudo make install

/usr/local/bin/shairport-sync --version
```
