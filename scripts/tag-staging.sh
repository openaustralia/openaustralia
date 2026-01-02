#!/bin/bash

# set -e

git tag staging-$(date +%F)
git push origin staging-$(date +%F)
git tag -d STAGING && git tag STAGING && git push origin STAGING --force