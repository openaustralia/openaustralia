# OpenAustralia.org

This is the master OpenAustralia.org repository. Here you'll find [issue tracking](https://github.com/openaustralia/openaustralia/issues) for the whole project and how to deploy it. This repository doesn't contain much code itself; almost everything lives in submodules.

The submodules are:

* The web application: [openaustralia/twfy](https://github.com/openaustralia/twfy)
* The parser: [openaustralia/openaustralia-parser](https://github.com/openaustralia/openaustralia-parser)
* Shared libraries: [openaustralia/phplib](https://github.com/openaustralia/phplib), [openaustralia/perllib](https://github.com/openaustralia/perllib), [openaustralia/rblib](https://github.com/openaustralia/rblib), [openaustralia/shlib](https://github.com/openaustralia/shlib)

Something broken? See the [runbooks](docs/runbooks/README.md) for how to diagnose and fix deploys, the daily parse, search, alert emails, the database and backups.

## Setup

```bash
make init-submodules   # git submodule update --init
make init-bundle       # bundle install (deploy tooling only)
```

This repository's own `Gemfile` is deployment tooling (Capistrano and friends), pinned to Ruby 3.4.9 (`.ruby-version`). It isn't the app runtime - `config/deploy.rb` reads `openaustralia-parser/.ruby-version` and uses `openaustralia-parser/Gemfile` for that.

## Development

This repository is deployment tooling and issue tracking, not a development environment. To work on the code itself:

* **The web application (`twfy`)**: the maintained Docker Compose development environment is in the `twfy` submodule. See [`twfy/README.md`](twfy/README.md) - roughly `make dependencies`, `make docker`, `make docker-db-migrate`, `make docker-db-seed`, then `make docker-run`, with the site at <http://localhost>.
* **The parser (`openaustralia-parser`)**: see that submodule's own README.

## Deployment

OpenAustralia.org is deployed using Capistrano 3 from this repository, to a single EC2 instance with separate `production` and `staging` deploy paths. Once you've made changes to the web application or the parser and pushed them to GitHub, you first need to update their submodule pointers in this repository.

Capistrano looks up the deploy target dynamically by its EC2 tags (via [capistrano-aws](https://github.com/fernandocarletti/capistrano-aws)) and proxies SSH through AWS SSM Session Manager, so deploying requires:

* the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) with the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) installed;
* an `oaf` AWS profile with an active session (`aws login` / `aws sso login --profile oaf`).

### Update submodules with Dependabot

`.github/dependabot.yml` runs a daily `gitsubmodule` check that opens a pull request for each submodule pointer
that is behind its `main` branch, the same way it does for the other dependencies in this repository. These
pull requests go through the normal review and merge process, so `main` stays protected.

To trigger a check immediately instead of waiting for the daily run, open **Insights**, then **Dependency graph**,
then the **Dependabot** tab in this repository, find the `gitsubmodule` entry under recent update jobs, and select
**Check for updates**.

Set the `DEPLOY_SSH_KEY` ENV var to the path of a key file if you are using a different ssh key for deployment than `~/.ssh/id_ed25519` (preferred) or `~/.ssh/id_rsa`. (In GitHub Actions, `DEPLOY_SSH_KEY` is instead an environment secret holding the key itself.)

By default the `main` branch is deployed to both production and staging. You can override this using:
* `STAGING_BRANCH` ENV var if you want a different staging branch;
* `PRODUCTION_BRANCH` ENV var if you want a different production branch, eg whilst setting up a new server.
You can set `SUBMODULE_BRANCH` ENV var if you want the submodules updated to a different branch than main.

Deploying does not use whatever branch you have checked out locally. Capistrano's custom `git:create_release`
task in the `Capfile` does a fresh `git clone --branch <branch> https://github.com/openaustralia/openaustralia.git`
on the deploy target itself, where `<branch>` comes from `STAGING_BRANCH`/`PRODUCTION_BRANCH` (default `main`),
set in `config/deploy/staging.rb` and `config/deploy/production.rb`. So to deploy an unmerged PR branch to
staging, run it as `STAGING_BRANCH=your-branch-name make staging-deploy`, not just `make staging-deploy` from
that branch locally.

To bump submodule pointers by hand instead of waiting for Dependabot, update the parser and the web application like this:

```bash
  cd openaustralia
  make check-submodules # to check what has changed
  #pull in the latest `main` branch of openaustralia-parser and twfy
  make update-twfy
  make update-openaustralia-parser
```
That will commit the changes for you. Have a look around with `git status`, then push to a branch and open a pull request. Don't push straight to `main`: it is protected.

Once the submodule change is in the `main` branch on GitHub, you're ready to deploy. Merging does not deploy anything by itself: today every deploy is run by a person with the Make targets below.

### Deploying from GitHub Actions (not working yet)

`.github/workflows/` holds three deploy workflows that are meant to run the same Capistrano tasks over AWS OIDC and the SSM tunnel, with no `oaf` AWS profile or local SSH key:

* `deploy-staging.yml` starts on every push to `main`, and can be started by hand from the Actions tab.
* `deploy-staging-branch.yml` is manual: choose any branch to preview on staging.
* `deploy-production.yml` is manual: choose a branch (default `main`). The `production` environment requires a listed reviewer to approve the run before it starts.

**None of them has ever succeeded.** On 2026-10-21 all 18 recorded `deploy-staging.yml` runs had failed and 2 more had failed to start, the one `deploy-production.yml` run had failed, and `deploy-staging-branch.yml` had never run.
Each failure is at the "Configure AWS credentials" step: the workflows read the variable `AWS_DEPLOY_ROLE_ARN`, and neither the repository nor the `staging` and `production` environments has any variables set.
The workflows also do not check out submodules, which `config/deploy.rb` needs (it reads `openaustralia-parser/.ruby-version` when it loads), so setting the variable alone is unlikely to be enough.

Use the Make targets below, from your own machine, until the workflows are fixed.

To deploy the staging branch (`main`, or whatever `STAGING_BRANCH` is set to) to ([Staging](https://www.test.openaustralia.org.au/)):
```bash
  make staging-deploy
```

If you've updated data about members you'll need to parse that and import it. Nothing schedules this: the production cron jobs run `dailyupdate` (which refreshes member links, not the member list), `morningupdate`, `weeklyupdate` and `alertmailer`. Run it with this Capistrano task:
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
3. This produces `release_path/twfy/vendor/` after `deploy:symlink_shared` and
   `deploy:compile_lockfile` (which run earlier, in `deploy:updating`) and before
   the `current` symlink flips and the Apache restart runs. The application's
   `twfy/www/includes/easyparliament/init.php` does a
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

Server prerequisites (one-time, managed by Ansible in the [`openaustralia/infrastructure`](https://gitlab.com/openaustralia/infrastructure) repository on GitLab, not by Capistrano):

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
