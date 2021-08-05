DEV_SYSTEMD_CONFIG_DIR := ~/.config/systemd/user/
LIVE_SYSTEMD_CONFIG_DIR := /etc/systemd/system/

VENV := ~/.venvs/chevron
CHEVRON := $(VENV)/bin/chevron
SYSTEMCTL_USER := --user

EXP_HOSTS := {kitchen,library,outside,bedroom-mark}

ALL_HOSTS := \
	study \
	kitchen \
	library \
	outside \
	bedroom-mark \

EXP_SERVICES := {snapclient,mopidy}

DEV_UNITS := \
	$(DEV_SYSTEMD_CONFIG_DIR)/snapclient@.service \
	$(DEV_SYSTEMD_CONFIG_DIR)/mopidy@.service \
	$(DEV_SYSTEMD_CONFIG_DIR)/multizone-audio-control.service \

DEBIAN_UNITS := \
	$(LIVE_SYSTEMD_CONFIG_DIR)/mopidy@.service \
	$(LIVE_SYSTEMD_CONFIG_DIR)/multizone-audio-control.service \

ALL_MOPIDY := $(patsubst %, mopidy.%.conf, $(ALL_HOSTS))
ALL_AIRPLAY := $(patsubst %, shairport-sync.%.conf, $(ALL_HOSTS))
ALL_SNAPCLIENTS := $(patsubst %, snapclient.%.conf, $(ALL_HOSTS))
ALL_NGINX := $(patsubst %, iris.%.conf, $(ALL_HOSTS))

ALL_CONFIGS := \
	../snapserver.conf \
	snapcast-autoconfig.yaml \
	$(ALL_MOPIDY) \
	$(ALL_AIRPLAY) \
	$(ALL_NGINX) \
	$(ALL_SNAPCLIENTS) \

DEV_CONFIGS := \
	dev/snapclient@.service \
	dev/mopidy@.service \

LIVE_CONFIGS := \
	debian/snapclient@.service \
	debian/mopidy@.service \

ALL_SERVICES := $(patsubst %, ${EXP_SERVICES}@%, $(ALL_HOSTS))

all: $(ALL_CONFIGS)

nginx: $(ALL_NGINX)

dev/%.service: templates/dev/%.service.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

dev/%.service: templates/%.service.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

debian/%.service: templates/debian/%.service.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

debian/%.service: templates/%.service.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

../snapserver.conf: templates/snapserver.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

snapcast-autoconfig.yaml: templates/snapcast-autoconfig.yaml.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

mopidy.%.conf: %.json templates/mopidy.template $(CHEVRON)
	$(CHEVRON) -d $< templates/mopidy.template > $@

snapclient.%.conf: %.json templates/snapclient.template $(CHEVRON)
	$(CHEVRON) -d $< templates/snapclient.template > $@

shairport-sync.%.conf: %.json templates/shairport-sync.template $(CHEVRON)
	$(CHEVRON) -d $< templates/shairport-sync.template | grep -v '^//\|^$$' > $@ 

iris.%.conf: %.json templates/iris.template $(CHEVRON)
	$(CHEVRON) -d $< templates/iris.template > $@


snapserver: ../snapserver.conf
	systemctl $(SYSTEMCTL_USER) restart snapserver

controller: controller/multizone-control.py
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

$(DEV_SYSTEMD_CONFIG_DIR)/%.service: dev/%.service
	install -t $(DEV_SYSTEMD_CONFIG_DIR) $^

$(DEV_SYSTEMD_CONFIG_DIR)/%.service: controller/%.service
	install -t $(DEV_SYSTEMD_CONFIG_DIR) $^

$(LIVE_SYSTEMD_CONFIG_DIR)/%.service: debian/%.service
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) $^

$(LIVE_SYSTEMD_CONFIG_DIR)/%.service: controller/%.service
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) $^

dev: $(ALL_CONFIGS) $(DEV_CONFIGS)

dev-install: dev $(DEV_UNITS)
	systemctl $(SYSTEMCTL_USER) daemon-reload

debian: $(ALL_CONFIGS) $(DEBIAN_CONFIGS)

live-install: debian $(DEBIAN_UNITS)
	systemctl $(SYSTEMCTL_USER) daemon-reload

clean:
	-rm $(ALL_CONFIGS)

.PHONY: clean install status stop controller
