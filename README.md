# OpenAustralia.org

This is the master OpenAustralia.org repository. Here you'll find [issue tracking](https://github.com/openaustralia/openaustralia/issues) for the whole project and how to deploy it. This repository doesn't contain much code itself; almost everything lives in submodules.

The submodules are:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)
* Shared libraries: [openaustralia/phplib](https://github.com/openaustralia/phplib), [openaustralia/perllib](https://github.com/openaustralia/perllib), [openaustralia/rblib](https://github.com/openaustralia/rblib), [openaustralia/shlib](https://github.com/openaustralia/shlib)

## Setup

```bash
make init-submodules   # git submodule update --init
make init-bundle       # bundle install (deploy tooling only)
```

This repository's own `Gemfile` is deployment tooling (Capistrano and friends), pinned to Ruby 3.4.9 (`.ruby-version`). It isn't the app runtime - `config/deploy.rb` reads `openaustralia-parser/.ruby-version` and uses `openaustralia-parser/Gemfile` for that.

## Development

This repository is deployment tooling and issue tracking, not a development environment. To work on the code itself:

* **The web application (`twfy`)**: it has its own Docker Compose setup. See [`twfy/README.md`](twfy/README.md) - roughly `make dependencies`, `make docker`, `make docker-db-migrate`, `make docker-db-seed`, then `make docker-run`, with the site at <http://localhost>.
* **The parser (`openaustralia-parser`)**: see that submodule's own README.

The `Vagrantfile` and `docker.sh` in this repository are historical (Ubuntu 16.04/PHP 5.6 era) and not maintained; don't build on them.

## Deployment

OpenAustralia.org is deployed using Capistrano 3 from this repository, to a single host (`openaustralia.org.au`) with separate `production` and `staging` deploy paths. Once you've made changes to the web application or the parser and pushed them to GitHub, you first need to update their submodule pointers in this repository.

Set `DEPLOY_SSH_KEY` ENV var if you are using a different ssh key for deployment than `~/.ssh/id_ed25519` (preferred) or `~/.ssh/id_rsa`.

You do this by adding and committing, just like you would with any other change in Git. Here's what it looks like to update both the parser and the web application's submodules:

By default the `main` branch is deployed to both production and staging. You can override this using:
* `STAGING_BRANCH` ENV var if you want a different staging branch;
* `PRODUCTION_BRANCH` ENV var if you want a different production branch, eg whilst setting up a new server.
You can set `SUBMODULE_BRANCH` ENV var if you want the submodules updated to a different branch than main.

```bash
  cd openaustralia
  make check-submodules # to check what has changed
  #pull in the latest `main` branch of openaustralia-parser and twfy
  make update-twfy
  make update-openaustralia-parser
```
That will commit the changes for you. Have a look around with `git status` then push to a branch for a PR, or direct to `main`, depending on how brave you feel today.

Once the submodule change is in `main` branch on github, you're ready to deploy:

To deploy the OVERRIDE_BRANCH / staging branch to ([Staging](https://www.test.openaustralia.org.au/)):
```bash
  make staging-deploy
```

If you've updated data about members you'll need to parse that and import it. This happens automatically once a day or you can run it using this Capistrano task:
```bash
  make staging-parse-members
```


To deploy the main branch to ([Production](https://www.openaustralia.org.au/)):
```bash
  make production-deploy
  make production-parse-members
```

For other things, like attempting to parse a day's speeches after a parsing error, you'll need to log into the server to run the script(s) manually.

### PHP / Composer dependencies (twfy)

The `twfy` web application uses PHP packages declared in `twfy/composer.json`
(currently Eloquent / `illuminate/database`, plus dev tools like PHPUnit, Psalm
and Phinx). The resulting `twfy/vendor/` directory is **gitignored** in the
`twfy` submodule, so it is never committed or pushed.

Capistrano fills that gap during deploy via the [capistrano-composer][cc] gem
(loaded in [`Capfile`](Capfile) and configured in [`config/deploy.rb`](config/deploy.rb)):

[cc]: https://github.com/capistrano/composer

1. The custom `git:create_release` task clones the submodules and copies the
   working tree into `release_path`, so `release_path/twfy/composer.json` is
   present on the server.
2. `capistrano-composer` automatically registers
   `before 'deploy:updated', 'composer:install'`. We point it at the twfy
   subdirectory with `set :composer_working_dir, -> { release_path.join('twfy') }`
   and install with `--no-dev --prefer-dist --no-interaction --optimize-autoloader`.
3. This produces `release_path/twfy/vendor/` before
   `deploy:symlink_shared`, `deploy:compile_lockfile`, and the Apache restart
   run. The application's `twfy/www/includes/easyparliament/init.php` does a
   `require_once .../vendor/autoload.php`, so the dependency tree must be on
   disk before Apache serves any traffic from the new release.
4. On rollback the gem also runs `composer:install` before `deploy:reverted`,
   so older releases get a matching `vendor/` if it has been pruned.
5. `deploy:migrate` runs Phinx migrations (`vendor/bin/phinx migrate`) against
   `twfy`, hooked directly off `composer:install` so `vendor/bin/phinx` is
   guaranteed to exist by then.

Bumping a PHP dependency therefore needs **no special deploy step** — update
`composer.json` / `composer.lock` in the `twfy` repo, push, bump the submodule
pointer in this repo (`make update-twfy`), and deploy as usual.

Server prerequisites (one-time, managed by Ansible, not by Capistrano):

* `composer` on the `deploy` user's `$PATH`.
* `php-cli` with the same extensions the runtime needs (at minimum
  `mbstring`, `xml`, `curl`, `zip`, `mysql`).

If either is missing the deploy fails loudly at the `composer:install` step
rather than producing a silent 500 from a missing `vendor/autoload.php`.

## Updating images

OpenAustralia attempts to grab the official profile photo for each MP
from the APH website. However, it's common for the profile page to go
up some time before the profile photo is ready. When this happens, we
cache the photoless page. It's necessary to manually purge the cache
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
