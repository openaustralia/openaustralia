.PHONY: production vagrant

ALL: vagrant
SHELL := /usr/bin/env bash

vagrant:
	bundle exec cap -S stage=development deploy

staging:
	bundle exec cap -S stage=test deploy

production:
	bundle exec cap -S stage=production deploy
