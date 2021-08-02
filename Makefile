SYSTEMD_CONFIG_DIR := ~/.config/systemd/user/
VENV := ~/.venvs/chevron
CHEVRON := $(VENV)/bin/chevron
SYSTEMCTL_USER := --user

EXP_HOSTS := {canard,kitchen,bedroom-mark}
EXP_SERVICES := {snapclient,mopidy}

ALL_UNITS := \
	systemd/snapclient@.service \
	systemd/mopidy@.service \
	systemd/shairport-sync@.service \
	systemd/librespot@.service \
	controller/multizone-audio-control.service \

ALL_SNAPCLIENTS := \
	snapclient-canard \
	snapclient-kitchen \
	snapclient-bedroom-mark \

ALL_CONFIGS := \
	../snapserver.conf \
	\
	mopidy.canard.conf \
	mopidy.kitchen.conf \
	mopidy.bedroom-mark.conf \
	\
	shairport-sync.canard.conf \
	shairport-sync.kitchen.conf \
	shairport-sync.bedroom-mark.conf \

ALL_NGINX := \
	iris.canard.conf \
	iris.kitchen.conf \
	iris.bedroom-mark.conf \

ALL_SERVICES := ${EXP_SERVICES}@$(EXP_HOSTS)

all: $(ALL_CONFIGS)

nginx: $(ALL_NGINX)

iris.%.conf: %.json iris.template $(CHEVRON)
	$(CHEVRON) -d $< iris.template > $@

../snapserver.conf: players.json snapserver.template $(CHEVRON)
	$(CHEVRON) -d $< snapserver.template > $@

mopidy.%.conf: %.json mopidy.template $(CHEVRON)
	$(CHEVRON) -d $< mopidy.template > $@

snapclient-%: %.json snapclient.template $(CHEVRON)
	$(CHEVRON) -d $< snapclient.template > $@

shairport-sync.%.conf: %.json shairport-sync.template $(CHEVRON)
	$(CHEVRON) -d $< shairport-sync.template | grep -v '^//\|^$$' > $@ 

snapserver: ../snapserver.conf
	systemctl $(SYSTEMCTL_USER) restart snapserver

controller: install controller/multizone-control.py
	systemctl $(SYSTEMCTL_USER) restart multizone-audio-control

restart: $(ALL_CONFIGS) $(ALL_SNAPCLIENTS)
	systemctl $(SYSTEMCTL_USER) restart $(ALL_SERVICES)

restart-host:
	systemctl $(SYSTEMCTL_USER) restart $(EXP_SERVICES)@$(HOST)

start: restart snapserver controller

start-host: restart-host

status:
	systemctl $(SYSTEMCTL_USER) status $(ALL_SERVICES)

status-host:
	systemctl $(SYSTEMCTL_USER) status $(EXP_SERVICES)@$(HOST)

stop: $(ALL_CONFIGS) $(ALL_SNAPCLIENTS)
	systemctl $(SYSTEMCTL_USER) stop $(ALL_SERVICES)

stop-host: $(ALL_CONFIGS) $(ALL_SNAPCLIENTS)
	systemctl $(SYSTEMCTL_USER) stop $(EXP_SERVICES)@$(HOST)

# install the systemd unit files in the appropriate place
install: $(ALL_UNITS)
	install -t $(SYSTEMD_CONFIG_DIR) $^
	systemctl $(SYSTEMCTL_USER) daemon-reload

