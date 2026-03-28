.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

twfy/.git:
	git submodule init && git submodule update

deploy-local-vagrant:
	bundle exec cap -S stage=development deploy

staging-deploy:
	bundle exec cap staging deploy
	ssh deploy@staging.openaustralia.org.au ls -l /srv/www/staging/releases/

production-deploy:
	bundle exec cap production deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/production/releases/

staging-parse-members:
	bundle exec cap staging parse:members

production-parse-members:
	bundle exec cap production parse:members

init-submodules:
	git submodule update --init

# pull in latest changes from submodules
update-twfy: twfy/.git
	@echo
	@echo "============================================================================="
	@echo "Checking TWFY is in sync with ${BRANCH} branch"
	cd twfy && git fetch origin && git checkout ${BRANCH} && git pull origin ${BRANCH}
	git add --patch twfy && git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser:
	@echo
	@echo "============================================================================="
	@echo "Checking openaustralia-parser is in sync with ${BRANCH} branch"
	cd openaustralia-parser && git fetch origin && git checkout ${BRANCH} && git pull origin ${BRANCH}
	git add --patch openaustralia-parser && git commit -m "Update to latest openaustralia-parser"

update-rblib: rblib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking rblib is in sync with main branch"
	cd rblib && git fetch origin && git checkout main && git pull origin main
	git add --patch rblib && git commit -m "Update to latest rblib"

update-phplib: phplib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking phplib is in sync with ${BRANCH} branch"
	cd phplib && git fetch origin && git checkout ${BRANCH} && git pull origin ${BRANCH}
	git add --patch phplib && git commit -m "Update to latest phplib"
