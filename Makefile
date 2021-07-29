SYSTEMD_CONFIG_DIR := ~/.config/systemd/user/
VENV := ~/.venvs/chevron
CHEVRON := $(VENV)/bin/chevron
SYSTEMCTL_USER := --user

EXP_HOSTS := {canard,kitchen,bedroom-mark}
EXP_SERVICES := {snapclient,mopidy,shairport-sync,librespot}

ALL_UNITS := \
	systemd/snapclient@.service \
	systemd/mopidy@.service \
	systemd/shairport-sync@.service \
	systemd/librespot@.service \

ALL_SNAPCLIENTS := \
	snapclient-canard \
	snapclient-kitchen \
	snapclient-bedroom-mark \

ALL_CONFIGS := \
	mopidy.canard.conf \
	mopidy.kitchen.conf \
	mopidy.bedroom-mark.conf \
	\
	shairport-sync.canard.conf \
	shairport-sync.kitchen.conf \
	shairport-sync.bedroom-mark.conf \

ALL_SERVICES := ${EXP_SERVICES}@$(EXP_HOSTS)

all: $(ALL_CONFIGS)

mopidy.%.conf: %.json mopidy.template $(CHEVRON)
	$(CHEVRON) -d $< mopidy.template > $@

snapclient-%: %.json snapclient.template $(CHEVRON)
	$(CHEVRON) -d $< snapclient.template > $@

shairport-sync.%.conf: %.json shairport-sync.template $(CHEVRON)
	$(CHEVRON) -d $< shairport-sync.template | grep -v '^//\|^$$' > $@ 

snapserver: snapserver.conf
	systemctl $(SYSTEMCTL_USER) restart snapserver

restart: $(ALL_CONFIGS) $(ALL_SNAPCLIENTS)
	systemctl $(SYSTEMCTL_USER) restart $(ALL_SERVICES)

restart-host:
	systemctl $(SYSTEMCTL_USER) restart $(EXP_SERVICES)@$(HOST)

start: restart

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
install: snapserver.conf $(ALL_UNITS)
	install -t ../ snapserver.conf
	install -t $(SYSTEMD_CONFIG_DIR) $^
	systemctl $(SYSTEMCTL_USER) daemon-reload

