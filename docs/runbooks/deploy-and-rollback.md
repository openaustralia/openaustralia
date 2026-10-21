# Deploy and rollback

Deploys use Capistrano 3 (`Capfile`, `config/deploy.rb`, `config/deploy/*.rb`) and are **run by a person from their own machine** with `make staging-deploy` and `make production-deploy`. See the [README](../../README.md).
Nothing deploys automatically. The GitHub Actions workflows exist but have never succeeded (see "GitHub Actions deploys" below), so merging to `main` deploys nothing.
Deploying needs the `oaf` AWS profile with an active session, the AWS Session Manager plugin, and an SSH key the `deploy` user accepts.

What a deploy does, in order:

1. Finds the server by its EC2 tags (`Application=openaustralia.org`, and a `Roles` tag with `app` and `web`) and connects through AWS Session Manager. `rbenv:validate` checks the Ruby named in `openaustralia-parser/.ruby-version` is installed on the server.
2. `git:create_release` first runs Capistrano's stock steps (`git:check`, which runs `git ls-remote` on the server, and an update of a mirror in `shared/repo`), then our own: update `shared/cached-copy` from GitHub with submodules, copy it into a new `releases/<timestamp>` directory, and write `twfy/REVISION`.
3. `deploy:symlink_shared` links config, data and feeds from `shared` into the release, then `deploy:compile_lockfile` builds `twfy/scripts/run-with-lockfile` with `gcc`.
4. `bundler:install` (parser gems, deployment mode), `composer:install`, then `deploy:migrate` (Phinx) and `deploy:npm_build_css` (`npm ci`, `npm run build:css`).
5. The `current` symlink flips to the new release, then `deploy:restart` runs `sudo /usr/sbin/apache2ctl restart`.
6. Tagging, release cleanup (keeps 5 releases) and `sentry:release`.

Note the order: **migrations run before the `current` symlink flips**. A failure in a later step leaves the database ahead of the live code.

**Do not deploy or roll back between about 09:00 and 10:30 on weekdays.** The parser runs from `/srv/www/<stage>/current`, so a flip during `morningupdate` changes the code under a running parse. The `run-with-lockfile` lock files live inside the release directory, so a run started before a flip and one started after it do not exclude each other.

## Symptom: the deploy fails before doing anything

**Diagnose (READ-ONLY)**

| Error or behaviour | Cause | Check |
|---|---|---|
| `Errno::ENOENT` for `openaustralia-parser/.ruby-version` on every `cap` command, even `cap -T` | The `openaustralia-parser` submodule is not initialised. `config/deploy.rb` reads its `.ruby-version` when it loads | `make init-submodules` (changes only your checkout) |
| `rbenv: <version> is not installed or not found in $HOME/.rbenv/versions/<version>` | The Ruby in the parser's `.ruby-version` is not installed on the server. A parser change that bumps Ruby needs the new version installed first, by the infrastructure repository | Ask whoever manages it, and deploy afterwards |
| A deploy that passes `rbenv:validate` but fails at `bundler:install` with a Ruby version mismatch | Your local submodule checkout is stale. `config/deploy.rb` reads `.ruby-version` from your checkout, not from the branch being deployed | `make init-submodules`, then `git submodule update` |
| A credentials error such as `unable to sign request without credentials`, though `aws sso login --profile oaf` worked | The EC2 lookup uses the AWS SDK's default credentials. Only the Session Manager proxy gets `--profile oaf`. UNVERIFIED | Export `AWS_PROFILE=oaf` and retry |
| `Unable to locate credentials`, an expired SSO session, or an SSM error | No active AWS session | `aws sts get-caller-identity --profile oaf` |
| No servers matched, or a deploy that does nothing | No running instance has `Application=openaustralia.org`. If the `Roles` tag has lost `app` or `web`, the bundler, composer, migrate, npm and restart steps are **skipped silently** and `current` flips to a release with no `vendor/`, so the site fails on `vendor/autoload.php` | EC2 console, or ask whoever manages the infrastructure repository |
| The same release lands twice | Two running instances carry the tag (for example during a server swap). Capistrano deploys to all of them | As above |
| `fatal: not a valid object name: <branch>` | `STAGING_BRANCH` or `PRODUCTION_BRANCH` is misspelt. The stock `git archive` step runs first | Use a real branch name. A tag or commit also fails, at `reset --hard origin/<name>` on an existing `cached-copy` |
| Ref-lock error during `git submodule update` | A submodule branch was deleted and reused upstream. The task prunes stale refs for the submodules, but not for the `shared/repo` mirror | Read the error, then the first block of `git:create_release` in `Capfile` |
| `Fetched in submodule path ..., but it did not contain <sha>` | A library's commit was force-pushed away. Typically when reverting a pointer bump. UNVERIFIED | Point the submodule at a commit that still exists |
| `No space left on device` during `cp -a` | Each release is a full copy with `.git`, `vendor/` and `node_modules/`, plus `cached-copy` and `repo`. `/` was 61% used on 2026-10-21 | `df -h /` on the server. Remove old releases only with the on-call engineer |

**Escalate**: if you cannot get a session or find the server, tell the on-call engineer.

## Symptom: the deploy fails part-way through

**Diagnose (READ-ONLY)** Find the failing step in the output, then use the table.
Each deploy that finishes adds a line to `/srv/www/<stage>/revisions.log` (`Branch main (at <sha>) deployed as release <timestamp> by <user>`), so the last lines show which releases completed.

| Failing step | Cause | Effect on the live site |
|---|---|---|
| `deploy:compile_lockfile` | `gcc` is missing or broken on the server. The server has `gcc` 11.4 from `build-essential` | None. The release is not live yet |
| `bundler:install` | `You are trying to install in deployment mode after changing your Gemfile ...`: the parser's `Gemfile` and `Gemfile.lock` disagree. Or a Ruby mismatch | None |
| `composer:install` | `composer` or the PHP extensions are missing, or Packagist is unreachable | None |
| `deploy:migrate` | A migration failed, or the database is unreachable | None yet. A migration that partly ran may have changed the schema. See [Database and migrations](database-and-migrations.md) |
| `deploy:npm_build_css` | Node or npm is missing, or the registry is unreachable | The migration has already run, but the old code is still live. Fix and re-deploy |
| `deploy:restart` | `deploy` cannot run `sudo /usr/sbin/apache2ctl restart` without a password (it is the only sudo rule) | **The new release is live on disk but Apache was not restarted.** Re-run the restart or the deploy |
| `sentry:release` | Sentry CLI not signed in. All its steps warn and continue, except reading `twfy/REVISION` | None |

**Fix (CHANGES PRODUCTION)** Fix the cause, then run the same deploy again. It is safe to repeat.
Check: the new release directory exists under `releases/`, `current` points at it, and the home page loads.
Undo: see "Rollback" below.

`make staging-deploy` and `make production-deploy` end with an `ls` of the releases over SSH. It can exit non-zero after Capistrano **succeeded** (it uses its own SSH key and looks the instance up by `PublicHostname`), so judge a deploy by `revisions.log`, not by `make`'s exit status.

**Escalate**: if a migration partly ran, or the site shows errors after a restart, tell the on-call engineer, then the CEO if people see the site down for more than a few minutes.

## Rollback

**CHANGES PRODUCTION.** `bundle exec cap <stage> deploy:rollback` points `current` at the previous release.
`ROLLBACK_RELEASE=<timestamp>` picks a different one. Capistrano 3.20.1 runs `reverting`, `reverted`, `publishing` and `published`, so the Apache restart still fires.

Rollback **re-runs parts of a deploy**, against the release you are rolling back to:

- `capistrano-composer` hooks `composer:install` before `deploy:reverted`, and our `Capfile` hangs `deploy:migrate` and `deploy:npm_build_css` off `composer:install`. So all three run, **before** `current` flips.
  A rollback therefore needs Packagist and the npm registry reachable, and if one fails, `current` is not flipped. Phinx runs from the old release, and should find nothing to do.
- It does **not** reverse migrations. If a new migration changed the schema, the older code runs against the newer schema. Check that the old code tolerates it before rolling back, or write and ship a corrective migration instead. See [Database and migrations](database-and-migrations.md).
- `finishing_rollback` packs the rolled-back release into `rolled-back-release-<timestamp>.tar.gz` in the deploy directory, then deletes its directory. Keep the archive until you are sure you will not need it.
- `sentry:release` also runs, and reads `twfy/REVISION` without a rescue. UNVERIFIED: rolling back to a release made before `twfy/REVISION` was introduced (early September 2026) could make `cap` exit non-zero after the rollback finished.

UNVERIFIED: this repository has never recorded a rehearsed rollback. Check Apache is serving the old release (`ls -l current` and load a page) before telling anyone it worked.

## Tags

`capistrano-tagging3` tags each deploy as `production_<timestamp>` or `staging_<timestamp>` and pushes the tag. It tags `fetch(:revision)`, which Capistrano 3.20.1 never sets, so the tag names **your local `HEAD`**, not the deployed branch. It uses backticks, so a failed tag or push is silent.
The tags on the repository so far came from deploys run on a laptop, and match the deployed commit only because `main` was deployed from an up-to-date checkout.
Before each cleanup it also deletes the remote tags of the releases about to be pruned, so about the last five tags per stage survive.

`scripts/tag-prod.sh` and `scripts/tag-staging.sh` move the `PRODUCTION` and `STAGING` tags with `git push --force`, tagging your local `HEAD`. If the local tag does not exist the move silently does nothing. Nothing runs them, and both tags are stale (`PRODUCTION` dates from March 2026, `STAGING` from January). Treat them as a production action.

## Pointer bumps (Dependabot)

Dependabot opens a daily pull request for each submodule that is behind its default branch (`main`). The pull request changes only the pinned commit. It needs one review from a code owner, and no test runs before merge (the only checks are Socket Security and CodeQL). A newer commit closes the older Dependabot pull request.
Some people instead run `make update-<name>` (interactive, and it commits for you) and push. Either way, a merged bump deploys nothing: someone has to run the deploy.

**Staging does not exercise every library.** Staging has no cron, so a staging deploy and page load tests only `phplib` and `twfy`. `perllib`, `rblib` and `shlib` run only from cron or the command line. After bumping one, run the matching smoke test on staging (READ-ONLY, as the `deploy` user; on 2026-10-21 the `perllib` and `shlib` tests passed, a `php -l` syntax check of the `phplib` files passed, and the `rblib` test passed up to writing its output):

| Library | Smoke test |
|---|---|
| `perllib` | `cd /srv/www/staging/current/twfy/scripts && perl -I../../perllib -e 'use mySociety::Config; mySociety::Config::set_file("../conf/general"); print mySociety::Config::get("DB_NAME"),"\n"'` |
| `shlib` | `cd /srv/www/staging/current/twfy/scripts && bash -c 'set -eu; source consts; source ../../shlib/deployfns; read_conf ../conf/general; echo "$XAPIANDB"'` |
| `phplib` | Load `/api/` and `/alert/` on staging, and look in Apache's `error.log` for `PHP Parse error` or `Failed opening required` |
| `rblib` | `cd /srv/www/staging/current/openaustralia-parser && ./bin/run parse-members.rb --no-load --output-dir=<scratch directory>`. It writes only to the scratch directory, which must be **writable by `deploy`** (a directory made by `mktemp` as root is not), and exercises `rblib` only if `configuration.yml` lacks the four database fields. On staging it does lack them, and the config loads and the consistency checks run |

A bad `perllib` bump breaks `xml2db.pl`, `mpinfoin.pl`, `index.pl` and `make_rss.pl` at compile time. The parser ignores the `xml2db.pl` exit status, so `morningupdate` carries on and then stops at the index step. See [Library errors](#library-errors) below.

**Revert a bad bump (CHANGES PRODUCTION).** Dependabot merges are merge commits, so use `git revert -m 1 <merge-sha>`. For a `make update-*` commit use plain `git revert <sha>`. Ship the revert by pull request, then deploy.
Rolling back production alone does not fix `main`: the next deploy of `main` ships the bad pointer again until the revert lands. Dependabot will probably propose the same commit again, since the submodule is behind again. UNVERIFIED.

## GitHub Actions deploys

`.github/workflows/deploy-staging.yml` (on every push to `main`, or by hand), `deploy-staging-branch.yml` (by hand, any branch) and `deploy-production.yml` (by hand, needs one named reviewer to approve) exist, but **have never succeeded**. On 2026-10-21 all 18 recorded staging runs had failed and 2 more had failed to start, the one production run had failed, and the branch workflow had never run.
Every failure is at "Configure AWS credentials": the workflows read the variable `AWS_DEPLOY_ROLE_ARN`, and neither the repository nor the `staging` and `production` environments has any variable set.

Even with that set, expect these to fail next (code read, not yet seen):

- The workflows do not check out submodules, so `config/deploy.rb` fails on `openaustralia-parser/.ruby-version`.
- `contents: read` permission and no git identity mean the tagging step would fail silently.
- Both environments only allow runs from `main`, so the branch workflow cannot preview another branch. The "Use workflow from" ref is checked, not the `branch` input.
- Only one named person can approve a production run, and self-approval is not blocked.
- The runner has no Sentry CLI, so `sentry:release` warns and skips.

## Library errors

What each library prints when it fails, so a bad bump can be recognised:

| Library | Error text | Cause |
|---|---|---|
| `rblib` (parser) | `unable to locate PHP binary, needed to read config file`; `<php>: <file>: failed to read options`; `end of file reached`; `bad option output from subprocess`; `No value for '<KEY>' in '<file>', and no default specified` | PHP missing or failing; any PHP output before the options (run `php -r "require '<file>';"` to see it); a PHP fatal with errors hidden; or a last `define` in `conf/general` with an empty value (Ruby drops the trailing field). The last message is the likeliest after a `twfy` bump that adds a key, because `shared/general` is not in git |
| `perllib` (twfy scripts) | `<php>: <file>: no option output from subprocess`; `No value for '<KEY>' in '../conf/general', and no default specified` | A missing or invalid config file, or a PHP fatal. PHP's own message is on stderr just above. `make_rss.pl` and `delete-alerts` do not change directory, so run them from `twfy/scripts` |
| `shlib` (twfy scripts) | `.../deployfns: line N: SCRIPT_COMMAND: unbound variable`; or `shlib/deployfns read_conf: error calling PHP to load config file` | `read_conf` failed. A config value containing `"`, `$`, a backtick or a backslash breaks it, and a password with `$` is silently wrong. It leaves `/tmp/ms-deploy-configsource.*` temp files behind after a failure, so remove them |
| `phplib` (twfy pages) | `PHP Parse error` or `Failed opening required` in Apache's `error.log`; `Undefined constant "OPTION_AUTH_SHARED_SECRET"` on `/alert/` | A broken file, or the setting is missing from `conf/general`. A parse error in `rabx.php` breaks the whole API |

## Known gaps

- The Capfile links `current/searchdb` to `shared/shared/search/searchdb`, which does not exist on either stage, so the link dangles. Nothing uses it: `XAPIANDB` is `shared/search/searchdb`. Checked on the server. See [Search index](search-index.md).
- The Capfile links both `debates/debates.rss` and `senate/senate.rss` to `shared/rss/senate.rss`, and `shared/rss` holds only that file and `mp/`.
  `make_rss.pl` writes the House feed and then the Senate feed through those links, so **the House of Representatives feed is overwritten by the Senate feed**. Checked on the server and in `twfy/scripts/make_rss.pl`.
- The Capfile comment says `repo_path` is never populated. It is: the stock `git:update` still maintains a mirror at `shared/repo`.
- `deploy:setup_db` loads `db/schema.sql` into the `:db` role. No server has that role, so it does nothing. Do not use it.
- The `sentry:release` comment says twfy's `init.php` reads `twfy/REVISION`. At the pinned `twfy`, it does not, so PHP errors carry no release in Sentry. The parser reads the release-root `REVISION` (the umbrella commit), while `sentry:release` names the release by the `twfy` commit, so the two do not match.
