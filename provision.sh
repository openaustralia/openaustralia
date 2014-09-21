#!/bin/bash

# Inspired by --> https://github.com/hnakamur/vagrant-ubuntu-docker-shell-provision-example/

# Installing docker for Debian7 by --> https://coderwall.com/p/wlhavw
echo deb http://get.docker.io/ubuntu docker main | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
sudo apt-get update -y
sudo apt-get install -y lxc-docker

# Below refactored out to docker.sh
# Pull the latest docker images (should be tagged?)
# sudo docker pull leowmjw/oa-ubuntu-trusty-db

# Turn on the MySQL DB (MySQL 5.5 on Ubuntu 14.04)
# sudo docker run -d -i -t -p 3306:3306 leowmjw/oa-ubuntu-trusty-db /run.sh

# Pull the latest docker images (should be tagged?)
# sudo docker pull leowmjw/oa-ubuntu-10.04-web

# Turn on the Apache server (Ubuntu 10.04)
# docker run -d -i -t -p 80:80 leowmjw/oa-ubuntu-10.04-web /run.sh

# Future: Turn on the parser container

# Future: Turn on the Xapian container

