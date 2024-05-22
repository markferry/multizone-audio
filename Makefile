config_in ?= config.json
output_dir ?= build
install_dir ?= /etc/multizone-audio

CONFIG := $(output_dir)/config.out.json
SHELL := /bin/bash   # for curly-brace expansion

HOME_ASSISTANT_CONFIG := ~/network/home-assistant/config
DEV_SYSTEMD_CONFIG_DIR := ~/.config/systemd/user
LIVE_SYSTEMD_CONFIG_DIR := /etc/systemd/system
LIVE_NGINX_CONFIG_DIR := /etc/nginx/sites-available
SNAPSERVER_CONF := /etc/snapserver.conf

VENV := .venv

ifneq ($(shell id -u),0)
	SYSTEMCTL_USER = --user
endif

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

ALL_MOPIDY := $(patsubst %, $(output_dir)/mopidy.%.conf, $(ALL_ZONES))
ALL_AIRPLAY := $(patsubst %, $(output_dir)/shairport-sync.%.conf, $(ALL_HOSTS))
ALL_SNAPCLIENTS := $(patsubst %, $(output_dir)/snapclient.%.conf, $(ALL_HOSTS))
ALL_SPOTIFY := $(patsubst %, $(output_dir)/librespot.%.toml, $(ALL_ZONES))
ALL_NGINX := $(patsubst %, $(output_dir)/iris.%.conf, $(ALL_HOSTS))
ALL_HOME_ASSISTANT := $(patsubst %, $(output_dir)/home-assistant.%.yaml, $(ALL_ZONES))
ALL_HOME_ASSISTANT_INSTALL := \
	$(patsubst %, $(HOME_ASSISTANT_CONFIG)/packages/%/media.yaml, $(ALL_HOSTS)) \
	$(patsubst %, $(HOME_ASSISTANT_CONFIG)/packages/multizone-audio-%.yaml, $(ALL_LOGICAL))

ALL_MZ_CONFIGS := \
	$(ALL_MOPIDY) \
	$(ALL_AIRPLAY) \
	$(ALL_NGINX) \
	$(ALL_HOME_ASSISTANT) \
	$(ALL_SPOTIFY) \
	$(ALL_SNAPCLIENTS) \

ALL_CONFIGS := \
	$(CONFIG) \
	$(output_dir)/snapserver.conf \
	$(output_dir)/snapcast-autoconfig.yaml \
	$(ALL_MZ_CONFIGS) \

DEV_CONFIGS := \
	$(output_dir)/dev/snapserver.service \
	$(output_dir)/dev/snapclient@.service \
	$(output_dir)/dev/mopidy@.service \
	$(output_dir)/dev/multizone-audio-control.service \

LIVE_CONFIGS := \
	$(output_dir)/debian/mopidy@.service \
	$(output_dir)/debian/multizone-audio-control.service \

ALL_SERVICES := \
	$(patsubst %, ${EXP_SERVICES}@%, $(ALL_HOSTS)) \
	$(patsubst %, mopidy@%, $(ALL_LOGICAL))

all: $(ALL_CONFIGS)

# Config, substituting specific envvars
$(CONFIG): $(config_in)
	-@mkdir -p $(output_dir)
	set -a; . .env 2>/dev/null; install_dir=$(install_dir) output_dir=$(output_dir) envsubst < $< > $@

config: $(CONFIG)

# Find chevron or create a venv and install it
SYS_CHEVRON := $(shell which chevron)
ifeq (, $(SYS_CHEVRON))
  CHEVRON := $(VENV)/bin/chevron
$(CHEVRON): venv
else
  CHEVRON := $(SYS_CHEVRON)
endif
RENDER := render.py

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

$(output_dir)/dietpi/%.service: templates/dietpi/%.service.template $(CONFIG) $(RENDER)
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/dev/%.service: templates/dev/%.service.template $(CONFIG) $(RENDER)
	-@mkdir -p $(output_dir)/dev
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/dev/%.service: templates/%.service.template $(CONFIG) $(RENDER)
	-@mkdir -p $(output_dir)/dev
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/debian/%.service: templates/debian/%.service.template $(CONFIG) $(RENDER)
	-@mkdir -p $(output_dir)/debian
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/debian/%.service: templates/%.service.template $(CONFIG) $(RENDER)
	-@mkdir -p $(output_dir)/debian
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/snapserver.conf: templates/snapserver.template $(CONFIG) $(RENDER)
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/snapcast-autoconfig.yaml: templates/snapcast-autoconfig.yaml.template $(CONFIG) $(RENDER)
	python $(RENDER) -d $(CONFIG) $< > $@

$(output_dir)/mopidy.%.conf: $(CONFIG) templates/mopidy.template $(RENDER)
	python $(RENDER) -z $* -d $< templates/mopidy.template > $@

$(output_dir)/snapclient.%.conf: $(CONFIG) templates/snapclient.template $(RENDER)
	python $(RENDER) -z $* -d $< templates/snapclient.template> $@

$(output_dir)/shairport-sync.%.conf: $(CONFIG) templates/shairport-sync.template $(RENDER)
	python $(RENDER) -z $* -d $< templates/shairport-sync.template | grep -v '^//\|^$$' > $@

$(output_dir)/librespot.%.toml: $(CONFIG) templates/librespot.template $(RENDER)
	python $(RENDER) -z $* -d $< templates/librespot.template > $@

$(output_dir)/iris.%.conf: $(CONFIG) templates/iris.template $(RENDER)
	python $(RENDER) -z $* -d $< templates/iris.template> $@

$(output_dir)/home-assistant.%.yaml: $(CONFIG) templates/home-assistant.yaml.template
	python $(RENDER) -z $* -d $< templates/home-assistant.yaml.template > $@


snapserver: $(output_dir)/snapserver.conf
	systemctl $(SYSTEMCTL_USER) restart snapserver

controller: controller/multizone-control.py
	systemctl $(SYSTEMCTL_USER) restart multizone-audio-control

reload:
	systemctl $(SYSTEMCTL_USER) daemon-reload

restart: $(ALL_CONFIGS) $(ALL_SNAPCLIENTS) reload
	systemctl $(SYSTEMCTL_USER) restart $(ALL_SERVICES)

restart-host: reload
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

$(DEV_SYSTEMD_CONFIG_DIR)/%.service: $(output_dir)/dev/%.service
	install -t $(DEV_SYSTEMD_CONFIG_DIR) $^

$(DEV_SYSTEMD_CONFIG_DIR)/%.service: $(output_dir)/dev/%.service
	install -t $(DEV_SYSTEMD_CONFIG_DIR) $^

$(LIVE_SYSTEMD_CONFIG_DIR)/%.service: $(output_dir)/debian/%.service
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) $^

$(LIVE_SYSTEMD_CONFIG_DIR)/%.service: controller/%.service
	install -t $(LIVE_SYSTEMD_CONFIG_DIR) $^

dev: $(ALL_CONFIGS) $(DEV_CONFIGS)

dev-install: dev $(DEV_UNITS)
	install -D -t $(install_dir) $(ALL_MZ_CONFIGS)
	install $(output_dir)/snapserver.conf $(install_dir)

debian: $(ALL_CONFIGS) $(LIVE_CONFIGS)

live-install: debian $(DEBIAN_UNITS)
	install -t $(install_dir) $(ALL_MZ_CONFIGS)
	install -T $(output_dir)/snapserver.conf $(SNAPSERVER_CONF)

# Player install
#
debian-%-install: debian iris.%.conf debian/nginx.override.conf
	install -t $(LIVE_NGINX_CONFIG_DIR) iris.$*.conf
	install -T -D debian/nginx.override.conf $(LIVE_SYSTEMD_CONFIG_DIR)/nginx.service.d/override.conf

dietpi-%-install: dietpi iris.%.conf dietpi/nginx.override.conf
	install -t $(LIVE_NGINX_CONFIG_DIR) iris.$*.conf
	install -T -D dietpi/nginx.override.conf $(LIVE_SYSTEMD_CONFIG_DIR)/nginx.service.d/override.conf

clean:
	-rm $(ALL_CONFIGS) $(LIVE_CONFIGS) $(DEV_CONFIGS)

# Documentation
%.html: %.md Makefile
	pandoc -d multizone-audio --self-contained -f gfm+attributes -t html5 -o $@ $<

doc: doc/demo-001.html

.PHONY: clean install status stop controller debian dev
