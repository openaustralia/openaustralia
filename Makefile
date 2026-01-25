.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

deploy-local-vagrant:
	bundle exec cap -S stage=development deploy

new-staging-deploy:
	bundle exec cap -S stage=staging deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/staging/releases/
	./scripts/tag-staging.sh

old-staging-deploy:
	bundle exec cap -S stage=test deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/staging/releases/
	./scripts/tag-staging.sh

old-production-deploy:
	bundle exec cap -S stage=production deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/production/releases/
	./scripts/tag-prod.sh

old-staging-parse-members:
	bundle exec cap -S stage=test parse:members

old-production-parse-members:
	bundle exec cap -S stage=production parse:members

init-submodules:
	git submodule update --init


# pull in latest changes from submodules
update-twfy:
	cd twfy && git checkout main && git pull origin main
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
	cd openaustralia-parser && bundle exec parse-member-links.rb
