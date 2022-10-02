SHELL := /bin/bash   # for curly-brace expansion
HOME_ASSISTANT_CONFIG := ~/network/home-assistant/config
DEV_SYSTEMD_CONFIG_DIR := ~/.config/systemd/user
LIVE_SYSTEMD_CONFIG_DIR := /etc/systemd/system

VENV := .venv
SYSTEMCTL_USER ?=

ALL_HOSTS := \
	study \
	kitchen \
	library \
	lounge \
	ballroom \
	ballroom-patio \
	outside \
	bedroom-mark \

ALL_LOGICAL := \
	announcer \
	everywhere \

ALL_ZONES := \
	$(ALL_HOSTS) \
	$(ALL_LOGICAL) \

EXP_SERVICES := {snapclient,mopidy}

DEV_UNITS := \
	$(DEV_SYSTEMD_CONFIG_DIR)/snapserver.service \
	$(DEV_SYSTEMD_CONFIG_DIR)/snapclient@.service \
	$(DEV_SYSTEMD_CONFIG_DIR)/mopidy@.service \
	$(DEV_SYSTEMD_CONFIG_DIR)/multizone-audio-control.service \

DEBIAN_UNITS := \
	$(LIVE_SYSTEMD_CONFIG_DIR)/mopidy@.service \
	$(LIVE_SYSTEMD_CONFIG_DIR)/multizone-audio-control.service \

ALL_MOPIDY := $(patsubst %, mopidy.%.conf, $(ALL_ZONES))
ALL_AIRPLAY := $(patsubst %, shairport-sync.%.conf, $(ALL_HOSTS))
ALL_SNAPCLIENTS := $(patsubst %, snapclient.%.conf, $(ALL_HOSTS))
ALL_NGINX := $(patsubst %, iris.%.conf, $(ALL_HOSTS))
ALL_HOME_ASSISTANT := $(patsubst %, home-assistant.%.yaml, $(ALL_ZONES))
ALL_HOME_ASSISTANT_INSTALL := \
	$(patsubst %, $(HOME_ASSISTANT_CONFIG)/packages/%/media.yaml, $(ALL_HOSTS)) \
	$(patsubst %, $(HOME_ASSISTANT_CONFIG)/packages/multizone-audio-%.yaml, $(ALL_LOGICAL))

ALL_CONFIGS := \
	../snapserver.conf \
	snapcast-autoconfig.yaml \
	$(ALL_MOPIDY) \
	$(ALL_AIRPLAY) \
	$(ALL_NGINX) \
	$(ALL_HOME_ASSISTANT) \
	$(ALL_SNAPCLIENTS) \

DEV_CONFIGS := \
	dev/snapserver.service \
	dev/snapclient@.service \
	dev/mopidy@.service \
	dev/multizone-audio-control.service \

LIVE_CONFIGS := \
	debian/mopidy@.service \
	debian/multizone-audio-control.service \

ALL_SERVICES := \
	$(patsubst %, ${EXP_SERVICES}@%, $(ALL_HOSTS)) \
	$(patsubst %, mopidy@%, $(ALL_LOGICAL))

all: $(ALL_CONFIGS)

# Find chevron or create a venv and install it
SYS_CHEVRON := $(shell which chevron)
ifeq (, $(SYS_CHEVRON))
  CHEVRON := $(VENV)/bin/chevron
$(CHEVRON): venv
else
  CHEVRON := $(SYS_CHEVRON)
endif

$(VENV):
	$(info "No chevron in $(PATH). Installing in $(VENV)")
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install chevron

venv: $(VENV)

nginx: $(ALL_NGINX)

home-assistant: $(ALL_HOME_ASSISTANT)

$(HOME_ASSISTANT_CONFIG)/packages/%/media.yaml: home-assistant.%.yaml
	install -T $^ $@

$(HOME_ASSISTANT_CONFIG)/packages/multizone-audio-%.yaml: home-assistant.%.yaml
	install -T $^ $@

ha-install: $(ALL_HOME_ASSISTANT_INSTALL)

dietpi/%.service: templates/dietpi/%.service.template players.json $(CHEVRON)
	$(CHEVRON) -d players.json $<  > $@

dev/%.service: templates/dev/%.service.template players.json $(CHEVRON)
	-@mkdir -p dev
	$(CHEVRON) -d players.json $<  > $@

dev/%.service: templates/%.service.template players.json $(CHEVRON)
	-@mkdir -p dev
	$(CHEVRON) -d players.json $<  > $@

debian/%.service: templates/debian/%.service.template players.json $(CHEVRON)
	-@mkdir -p debian
	$(CHEVRON) -d players.json $<  > $@

debian/%.service: templates/%.service.template players.json $(CHEVRON)
	-@mkdir -p debian
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

home-assistant.%.yaml: %.json templates/home-assistant.yaml.template $(CHEVRON)
	$(CHEVRON) -d $< templates/home-assistant.yaml.template > $@


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

debian: $(ALL_CONFIGS) $(LIVE_CONFIGS)

live-install: debian $(DEBIAN_UNITS)
	systemctl $(SYSTEMCTL_USER) daemon-reload

# Player install
#
debian-%-install: debian iris.%.conf debian/nginx.override.conf
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) iris.$*.conf
	install -T -D debian/nginx.override.conf $(LIVE_SYSTEMD_CONFIG_DIR)/nginx.service.d/override.conf

dietpi-%-install: dietpi iris.%.conf dietpi/nginx.override.conf
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) iris.$*.conf
	install -T -D dietpi/nginx.override.conf $(LIVE_SYSTEMD_CONFIG_DIR)/nginx.service.d/override.conf

clean:
	-rm $(ALL_CONFIGS)

# Documentation
%.html: %.md Makefile
	pandoc -d multizone-audio --self-contained -f gfm+attributes -t html5 -o $@ $<

doc: doc/demo-001.html


.PHONY: clean install status stop controller debian dev
