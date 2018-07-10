# OpenAustralia.org

This is the master OpenAustralia.org repository. Here you'll find [issue tracking](https://github.com/openaustralia/openaustralia/issues) for the whole project and how to deploy it. This repository doesn't contain much code, those are stored in the submodules.

The key sub-projects are:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)

## Development

OpenAustralia.org is currently deployed on Ubuntu 12.04 and has a number of quite old dependencies. This means it can be a bit difficult to get it running on a modern machine (if you'd like to try anyway there's [an old website](https://openaustralia.github.io/openaustralia/) that has the details).

The easiest way to get a development copy running is to use Vagrant, VirtualBox, and Ansible with the Vagrantfile in this repository.

Once you've got them installed, install the following Vagrant plugin to streamline configuration of the hostname:

`vagrant plugin install vagrant-hostsupdater`

Next:

```
# Clone this repository and all its submodules
git clone --recursive https://github.com/openaustralia/openaustralia.git && cd openaustralia

# Build and boot the Vagrant machine (this will download a lot and take a long time)
vagrant up

# Copy application configuration
cp provisioning/configuration.yml.ansible openaustralia-parser/configuration.yml
cp provisioning/general.ansible twfy/conf/general

# Setup the database on the Vagrant machine
vagrant ssh --command 'mysql -u root openaustralia < /srv/www/openaustralia/twfy/db/schema.sql'

# Load MPs into the database
vagrant ssh --command '/srv/www/openaustralia/openaustralia-parser/parse-members.rb'

# Download, parse, and load speeches for an example day
vagrant ssh --command '/srv/www/openaustralia/openaustralia-parser/parse-speeches.rb 2017-08-08'
```

Yay, you've done it! Visit http://openaustralia.org.au.test and you should see your development copy of OpenAustralia.org.au

## Deployment

OpenAustralia.org is deployed using Capistrano from this repository. Once you've made changes to the web application or the parser and those have been pushed to GitHub you'll first need to update their submodules in this repository.

You do this by adding and committing, just like you would with any other change in Git. Here's what it looks like to update both the parser and the web application's submodules:

```
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

  modified:   openaustralia-parser (new commits)
  modified:   twfy (new commits)

no changes added to commit (use "git add" and/or "git commit -a")
$ git add --patch
diff --git a/openaustralia-parser b/openaustralia-parser
index 08291a1..e7aa61c 160000
--- a/openaustralia-parser
+++ b/openaustralia-parser
@@ -1 +1 @@
-Subproject commit 08291a110bd044e9b3b23deeeaff5a87489d59c3
+Subproject commit e7aa61c30fa0352fbf20247119b3a7abb6cb12e8
Stage this hunk [y,n,q,a,d,/,e,?]? y

diff --git a/twfy b/twfy
index 08dcf7a..ee01ada 160000
--- a/twfy
+++ b/twfy
@@ -1 +1 @@
-Subproject commit 08dcf7a702e483292248efeeaa8c2e439b00a85c
+Subproject commit ee01ada5fa07d3f8bc4a95620c401f238b5b1e70
Stage this hunk [y,n,q,a,d,/,e,?]? y

$ git commit --message="Update to HEAD of submodules"
[master 95051d1] Update to HEAD of submodules
 2 files changed, 2 insertions(+), 2 deletions(-)
$ git push origin master
```

Once this is pushed to GitHub you're ready to deploy:

`bundle exec cap --set-before stage=production deploy`

Due to [#75 Deploying to openaustralia.org.au in production stops website working](https://github.com/openaustralia/infrastructure/issues/75) you'll need to restart apache

`ssh root@openaustralia.org.au service apache2 restart`

If you've updated data about members you'll need to parse that and import it. This happens automatically once a day or you can run it using this Capistrano task:

`bundle exec cap --set-before stage=production parse:members`

For other things, like attempting to parse a day's speeches after a parsing error, you'll need to log into the server to run the script(s) manually.

## Copyright & License

Copyright OpenAustralia Foundation Limited. Licensed under the Affero GPL. See LICENSE file for more details.
