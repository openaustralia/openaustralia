.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

twfy/.git:
	git submodule init && git submodule update

deploy-local-vagrant:
	bundle exec cap -S stage=development deploy

staging-deploy:
	bundle exec cap staging deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/staging/releases/

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
	@echo "Checking TWFY is in sync with main branch"
	cd twfy && git fetch origin && git checkout main && git pull origin main
	git add --patch twfy && git commit -m "Update to latest TheyWorkForYou"

update-openaustralia-parser:
	@echo
	@echo "============================================================================="
	@echo "Checking openaustralia-parser is in sync with main branch"
	cd openaustralia-parser && git fetch origin && git checkout main && git pull origin main
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
	@echo "Checking phplib is in sync with main branch"
	cd phplib && git fetch origin && git checkout main && git pull origin main
	git add --patch phplib && git commit -m "Update to latest phplib"

update-perllib: perllib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking perllib is in sync with main branch"
	cd perllib && git fetch origin && git checkout main && git pull origin main
	git add --patch perllib && git commit -m "Update to latest perllib"

check-submodules:
	@git submodule foreach -q 'git fetch -q origin main'
	@behind=$$(git submodule | sed -n 's/^\([^ ]\{8\}\)[^ ]*  *\([^ ][^ ]*\) *\(.*\)/make update-\2 \t# will update to: \1 \2 \t\3/p'); \
	  if [ -z "$$behind" ]; then \
		count=$$(git submodule | wc -l); \
	    echo "All $$count submodules up to date"; \
	  else \
	    echo "Run the following commands to update submodules:"; \
	    echo "$$behind"; \
	  fi