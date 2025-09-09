# OpenAustralia.org

This is the master OpenAustralia.org repository. Here you'll find [issue tracking](https://github.com/openaustralia/openaustralia/issues) for the whole project and how to deploy it. This repository doesn't contain much code, those are stored in the submodules.

The key sub-projects are:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)

## Development

OpenAustralia.org is currently deployed on Ubuntu 12.04 and has a number of quite old dependencies. This means it can be a bit difficult to get it running on a modern machine (if you'd like to try anyway there's [an old website](https://openaustralia.github.io/openaustralia/) that has the details).

The easiest way to get a development copy running is to use Vagrant, VirtualBox, and Ansible with the Vagrantfile in the **infrastructure repository** NOT THIS REPOSITORY.

Ansible doesn't currently create a `~vagrant/.my.cnf` so you'll have
to create one by hand, pinching DB details from
/srv/www/production/shared/config/general`.

Then:

```
# Setup the database on the Vagrant machine
bundle exec cap -S stage=development deploy:setup_db

# Load MPs into the database
bundle exec cap -S stage=development parse:members

# Download, parse, and load speeches for an example day
vagrant ssh --command '/srv/www/production/current/openaustralia-parser/parse-speeches.rb 2017-08-08'
```

Yay, you've done it! Visit http://openaustralia.org.au.test and you should see your development copy of OpenAustralia.org.au

## Deployment

OpenAustralia.org is deployed using Capistrano from this repository. Once you've made changes to the web application or the parser and those have been pushed to GitHub you'll first need to update their submodules in this repository.

You do this by adding and committing, just like you would with any other change in Git. Here's what it looks like to update both the parser and the web application's submodules:

```bash
  cd openaustralia
  #pull in the latest `main` branch of openaustralia-parser and twfy
  make update-twfy
  make update-openaustralia-parser
```
That will commit the changes for you. Have a look around with `git status` then push to a branch for a PR, or direct to `main`, depending on how brave you feel today.

Once the submodule change is in `main` branch on github, you're ready to deploy:

To deploy to ([Staging](https://www.test.openaustralia.org.au/)):
```bash
  make staging-deploy
  ```

If you've updated data about members you'll need to parse that and import it. This happens automatically once a day or you can run it using this Capistrano task:
```bash
  make staging-parse-members
  ```


To deploy to ([Production](https://www.openaustralia.org.au/)):
```bash
  make production-deploy
  make production-parse-members
```

For other things, like attempting to parse a day's speeches after a parsing error, you'll need to log into the server to run the script(s) manually.

## Updating images

OpenAustralia attempts to grab the official profile photo for each MP
from the APH website. However, it's common for the profile page to go
up some time before the profile photo is ready. When this happens, we
cache the photoless page. It's neccessary to manually purge the cache
in order to detect that a photo has been added.

The cached html files live in
`/srv/www/production/shared/html_cache/member_images`. To clear out
the cache for everyone with the surname `Abbot`, cd to that directory
and `ls *Abbot*`. If you're sure you've got the right list of files,
you can use `rm` to really get rid of them.

You'll then need to:
```bash
$ cd /srv/www/production/current/openaustralia-parser/
$ ./member-images.rb
```

to load the new images.

The new images should be picked up by TVFY the next day.

## Copyright & License

Copyright OpenAustralia Foundation Limited. Licensed under the Affero GPL. See LICENSE file for more details.
