.PHONY: production check-submodules init-bundle init-submodules production-deploy \
		production-parse-members staging-deploy staging-parse-members update-openaustralia-parser update-perllib \
		update-phplib update-rblib update-shlib update-submodules update-twfy

ALL: init-submodules init-bundle
SHELL := /usr/bin/env bash
SUBMODULE_BRANCH ?= main

twfy/.git:
	git submodule init && git submodule update

init-bundle: .bundle/bundle-installed

.bundle/bundle-installed: Gemfile Gemfile.lock .ruby-version
	bundle install
	mkdir -p .bundle
	touch .bundle/bundle-installed

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

update-submodules: init-submodules
	@git submodule foreach --quiet ' \
	  current=$$(git rev-parse HEAD); \
	  git fetch --quiet origin $(SUBMODULE_BRANCH); \
	  latest=$$(git rev-parse origin/$(SUBMODULE_BRANCH)); \
	  if [ "$$current" = "$$latest" ]; then \
	    echo "$$name is already up to date"; \
	  elif git merge-base --is-ancestor "$$current" "$$latest"; then \
	    git checkout --quiet --detach "$$latest"; \
	    current_short=$$(printf "%s" "$$current" | cut -c1-8); \
	    latest_short=$$(printf "%s" "$$latest" | cut -c1-8); \
	    echo "Updated $$name from $$current_short to $$latest_short"; \
	  else \
	    current_short=$$(printf "%s" "$$current" | cut -c1-8); \
	    latest_short=$$(printf "%s" "$$latest" | cut -c1-8); \
	    echo "Error: $$name is not behind origin/$(SUBMODULE_BRANCH); refusing to replace $$current_short with $$latest_short"; \
	    exit 1; \
	  fi'

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

update-shlib: init-submodules
	@echo
	@echo "============================================================================="
	@echo "Checking shlib is in sync with $(SUBMODULE_BRANCH) branch"
	cd shlib && git fetch origin && git checkout $(SUBMODULE_BRANCH) && git pull origin $(SUBMODULE_BRANCH)
	git add --patch shlib && git commit -m "Update to latest shlib $(SUBMODULE_BRANCH) branch"

check-submodules:
	@behind=$$(git submodule foreach -q ' \
	  if git ls-remote --exit-code --heads origin $(SUBMODULE_BRANCH) > /dev/null 2>&1; then \
	    branch=$(SUBMODULE_BRANCH); \
	  else \
	    branch=main; \
	  fi; \
	  git fetch -q origin $$branch; \
	  current=$$(git rev-parse HEAD); \
	  remote=$$(git rev-parse origin/$$branch 2>/dev/null); \
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
