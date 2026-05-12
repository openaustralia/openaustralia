.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash
SUBMODULE_BRANCH ?= main

twfy/.git:
	git submodule init && git submodule update

init-bundle: .bundle/bundle-installed

.bundle/bundle-installed: Gemfile Gemfile.lock .ruby-version
	bundle install
	mkdir -p .bundle
	touch .bundle/bundle-installed

deploy-local-vagrant: .bundle/bundle-installed
	bundle exec cap -S stage=development deploy

staging-deploy: .bundle/bundle-installed
	bundle exec cap staging deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/staging/releases/

production-deploy: .bundle/bundle-installed
	bundle exec cap production deploy
	ssh deploy@openaustralia.org.au ls -l /srv/www/production/releases/

staging-parse-members: .bundle/bundle-installed
	bundle exec cap staging parse:members

production-parse-members: .bundle/bundle-installed
	bundle exec cap production parse:members

init-submodules:
	git submodule update --init

# pull in latest changes from submodules
update-twfy: twfy/.git
	@echo
	@echo "============================================================================="
	@echo "Checking TWFY is in sync with main branch"
	cd twfy && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch twfy && git commit -m "Update to latest TheyWorkForYou $(SUBMODULE_BRANCH) branch"

update-openaustralia-parser:
	@echo
	@echo "============================================================================="
	@echo "Checking openaustralia-parser is in sync with $(SUBMODULE_BRANCH) branch"
	cd openaustralia-parser && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch openaustralia-parser && git commit -m "Update to latest openaustralia-parser $(SUBMODULE_BRANCH) branch"

update-rblib: rblib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking rblib is in sync with $(SUBMODULE_BRANCH) branch"
	cd rblib && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch rblib && git commit -m "Update to latest rblib $(SUBMODULE_BRANCH) branch"

update-phplib: phplib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking phplib is in sync with $(SUBMODULE_BRANCH) branch"
	cd phplib && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch phplib && git commit -m "Update to latest phplib $(SUBMODULE_BRANCH) branch"

update-perllib: perllib/.git
	@echo
	@echo "============================================================================="
	@echo "Checking perllib is in sync with $(SUBMODULE_BRANCH) branch"
	cd perllib && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch perllib && git commit -m "Update to latest perllib $(SUBMODULE_BRANCH) branch"

check-submodules:
	@git submodule foreach -q 'git fetch -q origin $(SUBMODULE_BRANCH)'
	@behind=$$(git submodule foreach -q ' \
	  current=$$(git rev-parse HEAD); \
	  remote=$$(git rev-parse origin/$(SUBMODULE_BRANCH) 2>/dev/null); \
	  if [ "$$current" != "$$remote" ]; then \
	    short=$$(echo $$remote | cut -c1-8); \
	    echo "make update-$$name \t# will update to: $$short $$name"; \
	  fi'); \
	  if [ -z "$$behind" ]; then \
	    count=$$(git submodule | wc -l); \
	    echo "All $$count submodules are up to date with their current branch"; \
	  else \
	    echo "Run the following commands to update submodules:"; \
	    printf "$$behind\n"; \
	  fi

