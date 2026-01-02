#!/bin/bash

# set -e

git tag production-$(date +%F)
git push origin production-$(date +%F)
git tag -d PRODUCTION && git tag PRODUCTION && git push origin PRODUCTION --force