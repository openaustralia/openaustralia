.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

deploy-local-vagrant:
	bundle exec cap -S stage=development deploy

staging-deploy:
	bundle exec cap -S stage=test deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/staging/releases/

production-deploy:
	bundle exec cap -S stage=production deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/production/releases/

staging-parse-members:
	bundle exec cap -S stage=test parse:members

production-parse-members:
	bundle exec cap -S stage=production parse:members

init-submodules:
	git submodule update --init

update-twfy:
	cd twfy && git checkout master && git pull origin master
	git status
	git add --patch twfy
	git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser:
	cd openaustralia-parser && git checkout main && git pull origin main
	git status
	git add --patch openaustralia-parser
	git commit -m "Update to latest openaustralia-parser"
