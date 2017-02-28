# OpenAustralia.org

This is the master OpenAustralia.org repository. Here you'll find [issue tracking](https://github.com/openaustralia/openaustralia/issues) for the whole project and how to deploy it. This repository doesn't contain much code, those are stored in the submodules.

If you're interesting in contributing code, check out these projects:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)

## Setting Up Development Environment

* In this directory; run "vagrant up"; it will load up a Debian 7.3 host with Docker installed, pull down the twfy Docker web container + MySQL 5.5 DB and deploy
* Demo site with some data can be found via http://www.192.168.111.66.xip.io
* To update code: Go to /var/www/openaustralia/ and git pull as well as git submodule update

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

If you've updated data about members you'll need to parse that and import it. This happens automatically once a day or you can run it using this Capistrano task:

`bundle exec cap --set-before stage=production parse:members`

For other things, like attempting to parse a day's speeches after a parsing error, you'll need to log into the server to run the script(s) manually.

## Copyright & License

Copyright OpenAustralia Foundation Limited. Licensed under the Affero GPL. See LICENSE file for more details.
