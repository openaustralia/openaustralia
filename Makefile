.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

twfy/.git:
	git submodule init && git submodule update

deploy-local-vagrant:
	bundle exec cap -S stage=development deploy

new-staging-deploy:
	bundle exec cap staging deploy
	ssh deploy@staging.openaustralia.org.au ls -l /srv/www/staging/releases/

old-staging-deploy:
	bundle exec cap staging deploy
	ssh deploy@staging.openaustralia.org.au ls -l /srv/www/staging/releases/

old-production-deploy:
	bundle exec cap production deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/production/releases/

old-staging-parse-members:
	bundle exec cap staging parse:members

old-production-parse-members:
	bundle exec cap production parse:members

init-submodules:
	git submodule update --init

# pull in latest changes from submodules
update-twfy: twfy/.git
	cd twfy && git checkout staging && git pull origin staging
	git status
	git add --patch twfy
	git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser:
	cd openaustralia-parser && git checkout main && git pull origin main
	git status
	git add --patch openaustralia-parser
	git commit -m "Update to latest openaustralia-parser"


daily:
	cd twfy/scripts && ./dailyupdate

parse-members:
	openaustralia-parser/bin/run parse-member-links.rb
