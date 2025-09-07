.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

vagrant:
	bundle exec cap -S stage=development deploy

staging:
	bundle exec cap -S stage=test deploy

production:
	bundle exec cap -S stage=production deploy

init-submodules:
	git submodule update --init

update-twfy: init-submodules
	cd twfy && git checkout master && git pull origin master
	git status
	git add --patch twfy
	git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser: init-submodules
	cd openaustralia-parser && git checkout main && git pull origin main
	git status
	git add --patch openaustralia-parser
	git commit -m "Update to latest openaustralia-parser"
