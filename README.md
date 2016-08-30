OpenAustralia.org
=================

This is the main OpenAustralia.org repository. The code you see here isn't interesting, it's just the submodules (which are interesting!), however this repository is used for [issue tracking](https://github.com/openaustralia/openaustralia/issues) across the whole project.

If you're interesting in contributing code, check out these projects:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)

Setting Up Development Environment
====================================
* In this directory; run "vagrant up"; it will load up a Debian 7.3 host with Docker installed, pull down the twfy Docker web container + MySQL 5.5 DB and deploy
* Demo site with some data can be found via http://www.192.168.111.66.xip.io
* To update code: Go to /var/www/openaustralia/ and git pull as well as git submodule update
