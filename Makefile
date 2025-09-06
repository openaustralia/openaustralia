.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

vagrant:
	bundle exec cap -S stage=development deploy

staging:
	bundle exec cap -S stage=test deploy

production:
	bundle exec cap -S stage=production deploy

update-twfy:
	cd twfy && git checkout master && git pull origin master
	git status
	git add --patch twfy
	git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser:
	cd openaustralia-parser && git checkout master && git pull origin master
	git status
	git add --patch openaustralia-parser
	git commit -m "Update to latest openaustralia-parser"
